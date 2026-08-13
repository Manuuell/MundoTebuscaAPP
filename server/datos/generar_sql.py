"""Genera el SQL para cargar el mapa de Colombia.

Los hospitales van a su propia tabla, `hospitals_osm`, y no a `hospitals`. La
web consulta `hospitals` sin filtrar por `verified` (src/lib/data.ts:4004), asi
que cualquier fila que entre ahi sale publicada en el sitio. Una tabla aparte
que su codigo no nombra nunca es la unica forma de que esto se quede en la app
sin tocar el repo web.

Ademas separa dos cosas que no son la misma: `hospitals` es dato operativo
—estado, insumos, votos de la comunidad, quien lo gestiona— y esto es dato de
referencia: donde esta cada hospital. Ciclos de vida distintos.
"""
import json
import uuid

ESPACIO = uuid.UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8")


def txt(v):
    if v is None or v == "":
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


hosp = json.load(open("hospitales_co.json"))
geo = json.load(open("resultados_geo.json"))
precisos = [g for g in geo if g["calidad"] == "PRECISO"]

L = []
L.append("-- Mapa de Colombia: hospitales de referencia y coordenadas de acopio.")
L.append("-- Generado el 2026-08-13. Ejecutar en el editor SQL de Supabase.")
L.append("--")
L.append("-- La PARTE 1 es solo para la app: crea `hospitals_osm`, una tabla que el")
L.append("-- codigo de la web no nombra en ningun sitio. Meter esto en `hospitals`")
L.append("-- lo publicaria en elmundotebusca.com, porque su listado no filtra por")
L.append("-- `verified` (src/lib/data.ts:4004).")
L.append("--")
L.append("-- La PARTE 2 sí toca datos que la web ya muestra. Va aparte a proposito:")
L.append("-- se puede ejecutar solo la 1 y dejar la 2 para cuando se decida.")
L.append("")
L.append("")
L.append("-- ─── PARTE 1: hospitales, solo app ────────────────────────────────────")
L.append("")
L.append("begin;")
L.append("")
L.append("create table if not exists hospitals_osm (")
L.append("  id            uuid primary key,")
L.append("  name          text not null,")
L.append("  estado        text,")
L.append("  location_text text,")
L.append("  lat           double precision not null,")
L.append("  lng           double precision not null,")
L.append("  contact_phone text,")
L.append("  -- OSM marca con `emergency=yes` los centros con servicio de urgencias.")
L.append("  -- Es lo unico parecido a una capacidad que trae la fuente, y despues de")
L.append("  -- un sismo es justo lo que importa. No dice si hoy estan recibiendo.")
L.append("  has_emergency boolean not null default false,")
L.append("  country       text not null default 'co',")
L.append("  -- Identificador del objeto en OpenStreetMap, para poder volver a la")
L.append("  -- fuente de cualquier fila y corregirla alli si esta mal.")
L.append("  osm_ref       text,")
L.append("  updated_at    timestamptz not null default now()")
L.append(");")
L.append("")
L.append("create index if not exists hospitals_osm_country_idx on hospitals_osm (country);")
L.append("")
L.append("-- Sin RLS, PostgREST deja a la anon key escribir en una tabla nueva. Se")
L.append("-- enciende y solo se abre la lectura: la app lee, nadie mas escribe.")
L.append("alter table hospitals_osm enable row level security;")
L.append("drop policy if exists \"public_read_hospitals_osm\" on hospitals_osm;")
L.append("create policy \"public_read_hospitals_osm\" on hospitals_osm")
L.append("  for select using (true);")
L.append("")
L.append("-- El id es un uuid5 del identificador OSM: reejecutar no duplica nada.")
L.append("insert into hospitals_osm")
L.append("  (id, name, estado, location_text, lat, lng, contact_phone,")
L.append("   has_emergency, country, osm_ref)")
L.append("values")
filas = []
for h in hosp:
    ident = uuid.uuid5(ESPACIO, f"osm:{h['osm_id']}")
    filas.append(
        f"  ('{ident}', {txt(h['name'])}, {txt(h['estado'])}, "
        f"{txt(h['location_text'])}, {h['lat']}, {h['lng']}, "
        f"{txt(h['contact_phone'])}, {str(h['urgencias']).lower()}, 'co', "
        f"{txt(h['osm_id'])})"
    )
L.append(",\n".join(filas))
L.append("on conflict (id) do nothing;")
L.append("")
L.append("commit;")
L.append("")
L.append("-- Comprobacion:")
L.append("--   select estado, count(*) from hospitals_osm group by estado order by 2 desc;")
L.append("")
L.append("")
L.append("-- ─── PARTE 2: coordenadas de acopio (esto SI se ve en la web) ─────────")
L.append("--")
L.append("-- Son 6 puntos que ya existen y que la web ya lista; lo unico que cambia")
L.append("-- es que pasan a tener coordenada y por tanto pueden salir en su mapa.")
L.append("-- Ninguno es dato nuevo ni sin verificar. Si aun asi se prefiere que la")
L.append("-- web no cambie hoy, basta con no ejecutar este bloque.")
L.append("")
L.append("begin;")
for g in precisos:
    L.append(
        f"update aid_points set lat = {g['lat']}, lng = {g['lng']} "
        f"where id = '{g['id']}' and lat is null;  -- {g['name'][:44]}"
    )
L.append("commit;")
L.append("")
L.append("-- Comprobacion:")
L.append("--   select count(*) from aid_points where country='co' and lat is not null;")

with open("mapa_colombia.sql", "w") as fh:
    fh.write("\n".join(L) + "\n")

print("escrito mapa_colombia.sql")
print(f"  parte 1: {len(hosp)} hospitales en hospitals_osm (solo app)")
print(f"           {sum(1 for h in hosp if h['urgencias'])} con urgencias")
print(f"  parte 2: {len(precisos)} updates de aid_points (visible en web)")
