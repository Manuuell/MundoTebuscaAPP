"""Geocodifica los aid_points de Colombia y clasifica cada acierto por precision.

La clasificacion es el punto entero del script. Un chincheta en un mapa de
emergencia afirma "ven aqui": si la direccion solo daba para el centroide de
una ciudad, escribir esas coordenadas es peor que dejarlas vacias, porque el
punto sigue saliendo en la lista con su direccion en texto pero ya no manda a
nadie a un sitio que no es.
"""
import json
import time
import urllib.parse
import urllib.request

RAIZ = "/Users/manuelesteban/Library/Mobile Documents/com~apple~CloudDocs/proyectos/HACKATON"
cfg = json.load(open(f"{RAIZ}/env.local.json"))
CABECERA = {"User-Agent": "MundoTeBusca-mapa/1.0 (+https://elmundotebusca.com)"}

# Un POI concreto: la chincheta cae sobre el sitio.
PRECISO = {
    "amenity", "building", "shop", "leisure", "tourism", "office",
    "aeroway", "healthcare", "public_transport", "historic", "craft",
}
# Una calle sin numero, o un barrio. Sirve para orientar, no para llegar.
APROXIMADO = {"highway", "place"}
# Una ciudad o un departamento entero. Inutil como chincheta.
CENTROIDE = {"boundary"}


def consultar_supabase(tabla, **params):
    q = urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
    req = urllib.request.Request(
        f"{cfg['SUPABASE_URL']}/rest/v1/{tabla}?{q}",
        headers={"apikey": cfg["SUPABASE_ANON_KEY"],
                 "Authorization": f"Bearer {cfg['SUPABASE_ANON_KEY']}"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def buscar(texto):
    q = urllib.parse.urlencode(
        {"q": texto, "format": "jsonv2", "limit": 1, "countrycodes": "co",
         "addressdetails": 1}
    )
    req = urllib.request.Request(
        f"https://nominatim.openstreetmap.org/search?{q}", headers=CABECERA
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            d = json.load(r)
    except Exception as e:
        print(f"      (error de red: {e})")
        return None
    time.sleep(1.2)  # politica de uso de Nominatim: 1 peticion/segundo
    return d[0] if d else None


def clasificar(hit):
    cat = hit.get("category", "")
    if cat in PRECISO:
        return "PRECISO"
    if cat in CENTROIDE:
        return "CENTROIDE"
    if cat in APROXIMADO:
        # place/square es un sitio concreto; place/city no lo es.
        if cat == "place" and hit.get("type") in ("square", "house", "building"):
            return "PRECISO"
        return "APROXIMADO"
    return "APROXIMADO"


filas = consultar_supabase(
    "aid_points", select="id,name,estado,location_text", country="eq.co",
    order="estado",
)
print(f"{len(filas)} puntos de Colombia\n")

resultados = []
for i, f in enumerate(filas, 1):
    # Dos intentos: la direccion tal cual, y si falla el nombre del sitio con
    # su ciudad — muchos puntos son lugares conocidos ("Plazoleta Jairo
    # Varela") cuya direccion postal no esta en OSM pero el nombre si.
    intentos = [
        f"{f['location_text']}, {f['estado']}, Colombia",
        f"{f['name']}, {f['estado']}, Colombia",
    ]
    hit, usado = None, None
    for t in intentos:
        hit = buscar(t)
        if hit:
            usado = t
            break

    if not hit:
        calidad = "SIN_RESULTADO"
        print(f"  {i:2d}. [{calidad}] {f['name'][:60]}")
        resultados.append({**f, "calidad": calidad})
        continue

    calidad = clasificar(hit)
    print(f"  {i:2d}. [{calidad}] {f['name'][:55]}")
    print(f"      {hit['lat']}, {hit['lon']}  ({hit.get('category')}/{hit.get('type')})")
    resultados.append({
        **f, "calidad": calidad,
        "lat": float(hit["lat"]), "lng": float(hit["lon"]),
        "osm": f"{hit.get('category')}/{hit.get('type')}",
        "osm_nombre": hit.get("display_name", ""),
        "consulta": usado,
    })

with open("resultados_geo.json", "w") as fh:
    json.dump(resultados, fh, ensure_ascii=False, indent=2)

print("\n=== resumen ===")
for c in ("PRECISO", "APROXIMADO", "CENTROIDE", "SIN_RESULTADO"):
    print(f"  {c:14s} {sum(1 for r in resultados if r['calidad'] == c)}")
