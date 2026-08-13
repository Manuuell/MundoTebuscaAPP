"""Extrae hospitales reales de OpenStreetMap en los departamentos del sismo.

Nada de lo que sale de aqui es inventado: nombre, coordenadas, direccion y
telefono vienen tal cual de OSM. Lo que NO se rellena a proposito es el estado
operativo (`saturado`/`lleno`) ni `needs_text`: eso solo lo sabe quien esta
dentro del hospital hoy, y ponerlo a ojo en una app de emergencia es mentir
con formato de dato. Todas las filas entran con verified=false.
"""
import json
import re
import time
import urllib.parse
import urllib.request

DEPTOS = {
    "CO-RIS": "Risaralda",
    "CO-VAC": "Valle del Cauca",
    "CO-CHO": "Chocó",
    "CO-QUI": "Quindío",
    "CO-CAL": "Caldas",
}

# Un centro de salud de verdad, no una optica etiquetada como hospital.
ES_HOSPITAL = re.compile(
    r"^\s*(ips\s+)?(ese\s+)?(hospital|cl[ií]nica|centro m[eé]dico)\b", re.I
)
# Especialidades que no reciben traumatismos de un terremoto.
NO_URGENCIAS = re.compile(
    r"[óo]ptica|odontol|dental|epilepsia|discapacitad|reproductiv|diabet|"
    r"est[ée]tica|veterinari|psicoan|fisioterap|[óo]ptico|laboratorio",
    re.I,
)


def overpass(iso):
    q = f"""[out:json][timeout:180];
area["ISO3166-2"="{iso}"]->.z;
(
  node["amenity"="hospital"]["name"](area.z);
  way["amenity"="hospital"]["name"](area.z);
);
out center tags;"""
    req = urllib.request.Request(
        "https://overpass-api.de/api/interpreter",
        data=urllib.parse.urlencode({"data": q}).encode(),
        headers={"User-Agent": "MundoTeBusca-mapa/1.0 (+https://elmundotebusca.com)"},
    )
    with urllib.request.urlopen(req, timeout=200) as r:
        return json.load(r)["elements"]


def direccion(t):
    partes = []
    calle = t.get("addr:street")
    if calle:
        n = t.get("addr:housenumber")
        partes.append(f"{calle} {n}" if n else calle)
    for k in ("addr:suburb", "addr:city"):
        if t.get(k):
            partes.append(t[k])
    return ", ".join(partes)


todos = []
for iso, nombre in DEPTOS.items():
    filas = overpass(iso)
    print(f"{nombre:18s} {len(filas):4d} crudos", end="")
    utiles = []
    for x in filas:
        t = x.get("tags", {})
        n = (t.get("name") or "").strip()
        urgencias = t.get("emergency") == "yes"
        if NO_URGENCIAS.search(n):
            continue
        if not (urgencias or ES_HOSPITAL.match(n)):
            continue
        lat = x.get("lat") or x.get("center", {}).get("lat")
        lng = x.get("lon") or x.get("center", {}).get("lon")
        if lat is None or lng is None:
            continue
        utiles.append({
            "name": n,
            "estado": nombre,
            "location_text": direccion(t),
            "lat": round(float(lat), 6),
            "lng": round(float(lng), 6),
            "contact_phone": t.get("phone") or t.get("contact:phone"),
            "urgencias": urgencias,
            "osm_id": f"{x['type']}/{x['id']}",
        })
    # Dedupe: mismo nombre a menos de ~300 m es la misma sede mapeada dos veces.
    limpio = []
    for h in utiles:
        gemelo = next(
            (o for o in limpio
             if o["name"].lower() == h["name"].lower()
             and abs(o["lat"] - h["lat"]) < 0.003
             and abs(o["lng"] - h["lng"]) < 0.003),
            None,
        )
        if gemelo is None:
            limpio.append(h)
    print(f" -> {len(limpio):3d} utiles ({sum(1 for h in limpio if h['urgencias'])} con urgencias)")
    todos.extend(limpio)
    time.sleep(2)

with open("hospitales_co.json", "w") as fh:
    json.dump(todos, fh, ensure_ascii=False, indent=2)

print(f"\nTOTAL {len(todos)} hospitales")
print(f"  con telefono en OSM: {sum(1 for h in todos if h['contact_phone'])}")
print(f"  con direccion:       {sum(1 for h in todos if h['location_text'])}")
