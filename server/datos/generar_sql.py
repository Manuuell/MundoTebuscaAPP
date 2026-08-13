"""Genera los dos SQL que cargan el mapa de Colombia.

Van en ficheros separados porque tienen consecuencias distintas y no los
decide la misma persona: el 1 no cambia nada de lo que se ve en la web, el 2
si. Juntos en un fichero, quien lo ejecuta tiene que acordarse de parar a la
mitad, y eso acaba saliendo mal alguna vez.

Los hospitales van a `hospitals_osm` y no a `hospitals`. La web lista
`hospitals` filtrando solo por pais, sin mirar `verified`
(src/lib/data.ts:4004), asi que cualquier fila que entre ahi sale publicada en
el sitio. Aparte, son dos cosas distintas: `hospitals` es dato operativo que
mantiene gente —estado, insumos, votos— y esto es dato de referencia
importado, que se regenera entero cuando haga falta.

Entradas: hospitales_co.json (extraer_hospitales.py) y resultados_geo.json
(geocodificar_acopio.py).
"""
import json
import uuid

ESPACIO = uuid.UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8")


def txt(v):
    if v is None or v == "":
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


hosp = json.load(open("hospitales_co.json"))
precisos = [
    g for g in json.load(open("resultados_geo.json")) if g["calidad"] == "PRECISO"
]

# ── 1 de 2: hospitales, solo app ─────────────────────────────────────────────

filas = []
for h in hosp:
    ident = uuid.uuid5(ESPACIO, f"osm:{h['osm_id']}")
    filas.append(
        f"  ('{ident}', {txt(h['name'])}, {txt(h['estado'])}, "
        f"{txt(h['location_text'])}, {h['lat']}, {h['lng']}, "
        f"{txt(h['contact_phone'])}, {str(h['urgencias']).lower()}, 'co', "
        f"{txt(h['osm_id'])})"
    )
cuerpo = ",\n".join(filas)

uno = f"""-- Mapa de Colombia · 1 de 2: hospitales de referencia. SOLO APP.
--
-- Crea `hospitals_osm` con {len(hosp)} hospitales de los cinco departamentos con
-- desaparecidos del sismo, importados de OpenStreetMap.
--
-- NO toca `hospitals`, y no es un descuido: la web lista esa tabla filtrando
-- solo por pais, sin mirar `verified` (src/lib/data.ts:4004). Mover estas
-- filas alli las publica en elmundotebusca.com sin que nadie las haya
-- verificado. El codigo de la web no nombra `hospitals_osm` en ningun sitio.
--
-- No cambia nada de lo que hoy se ve en el sitio. Se puede ejecutar solo este
-- fichero y dejar el 2 para despues.
--
-- Deshacer:  drop table if exists hospitals_osm;

begin;

create table if not exists hospitals_osm (
  id            uuid primary key,
  name          text not null,
  estado        text,
  location_text text,
  lat           double precision not null,
  lng           double precision not null,
  contact_phone text,
  -- OSM marca con `emergency=yes` los centros con servicio de urgencias. Es lo
  -- unico parecido a una capacidad que trae la fuente, y despues de un sismo
  -- es justo lo que importa. No dice si hoy estan recibiendo.
  has_emergency boolean not null default false,
  country       text not null default 'co',
  -- Identificador del objeto en OpenStreetMap, para poder volver a la fuente
  -- de cualquier fila y corregirla alli si esta mal.
  osm_ref       text,
  updated_at    timestamptz not null default now()
);

create index if not exists hospitals_osm_country_idx on hospitals_osm (country);

-- Sin RLS, PostgREST deja a la anon key escribir en una tabla nueva. Se
-- enciende y solo se abre la lectura: la app lee, nadie mas escribe.
alter table hospitals_osm enable row level security;
drop policy if exists "public_read_hospitals_osm" on hospitals_osm;
create policy "public_read_hospitals_osm" on hospitals_osm
  for select using (true);

-- El id es un uuid5 del identificador OSM: reejecutar no duplica nada.
insert into hospitals_osm
  (id, name, estado, location_text, lat, lng, contact_phone,
   has_emergency, country, osm_ref)
values
{cuerpo}
on conflict (id) do nothing;

commit;

-- Comprobacion:
--   select estado, count(*) from hospitals_osm group by estado order by 2 desc;
"""

# ── 2 de 2: coordenadas de acopio, visible en la web ─────────────────────────

updates = "\n".join(
    f"update aid_points set lat = {g['lat']}, lng = {g['lng']} "
    f"where id = '{g['id']}' and lat is null;  -- {g['name'][:44]}"
    for g in precisos
)

dos = f"""-- Mapa de Colombia · 2 de 2: coordenadas de puntos de acopio.
--
-- ESTO SI CAMBIA LO QUE SE VE EN LA WEB. Son {len(precisos)} puntos que ya existen en
-- `aid_points` y que el sitio ya lista; lo unico que cambia es que pasan a
-- tener coordenada, y por tanto pueden salir en su mapa. No es dato nuevo ni
-- sin verificar, pero la decision de publicarlo no es de quien lo genero.
--
-- El fichero 1 no depende de este. Se puede no ejecutar nunca.
--
-- Deshacer:
--   update aid_points set lat = null, lng = null
--     where country = 'co' and lat is not null;

begin;
{updates}
commit;

-- Comprobacion:
--   select count(*) from aid_points where country='co' and lat is not null;
"""

open("mapa_colombia_1_hospitales.sql", "w").write(uno)
open("mapa_colombia_2_acopio.sql", "w").write(dos)

print(f"1 de 2: {len(hosp)} hospitales en hospitals_osm (no toca la web)")
print(f"        {sum(1 for h in hosp if h['urgencias'])} con urgencias")
print(f"2 de 2: {len(precisos)} updates de aid_points (visible en la web)")
