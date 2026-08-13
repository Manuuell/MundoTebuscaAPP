# Datos del mapa de Colombia

Se ejecuta **a mano en el editor SQL de Supabase**. La `anon key` solo puede
leer, así que no hay forma de cargar esto desde la app ni con un script que
use la llave pública.

Son **dos ficheros independientes**, y están separados porque no tienen la
misma consecuencia ni la decide la misma persona:

| Fichero | Qué hace | ¿Cambia la web? |
|---|---|---|
| `mapa_colombia_1_hospitales.sql` | Crea `hospitals_osm` + 167 hospitales | **No** |
| `mapa_colombia_2_acopio.sql` | Coordenadas a 6 puntos de acopio existentes | Sí |

El 1 no depende del 2. Se puede ejecutar solo el primero, y el segundo nunca.

## Fichero 1 — hospitales, solo en la app

Crea la tabla `hospitals_osm` y mete **167 hospitales** de los cinco
departamentos con desaparecidos del sismo: Risaralda, Valle del Cauca, Chocó,
Quindío y Caldas.

**Por qué una tabla nueva y no `hospitals`.** La web lista `hospitals`
filtrando solo por país, sin mirar `verified`
([`src/lib/data.ts:4004`](https://github.com/Angelsistemas7/ElMundo-Te-Busca/blob/main/src/lib/data.ts#L4004)).
Cualquier fila que entre ahí aparece publicada en elmundotebusca.com. Su
código no nombra `hospitals_osm` en ningún sitio, así que estos 167 se quedan
en la app sin tener que tocar el repo web.

Aparte de eso, son dos cosas distintas y conviene que no compartan tabla:

| `hospitals` | `hospitals_osm` |
|---|---|
| Dato **operativo**: estado, insumos que faltan, votos de la comunidad, quién lo gestiona | Dato de **referencia**: dónde está cada hospital |
| Lo mantiene gente | Se importa y se puede regenerar entero |

La tabla se crea con RLS encendida y **solo** política de lectura. Sin eso,
PostgREST dejaría a la `anon key` escribir en una tabla nueva.

Es idempotente: los `id` son `uuid5` del identificador de OpenStreetMap, con
`on conflict (id) do nothing`. Reejecutarlo no duplica nada, y cada fila se
puede rastrear hasta su objeto OSM por la columna `osm_ref`.

## Fichero 2 — coordenadas de acopio (esto **sí** se ve en la web)

Seis `update` sobre puntos de `aid_points` que ya existen y que la web ya
lista; lo único que cambia es que pasan a tener coordenada, y por tanto pueden
salir en su mapa. No es dato nuevo ni sin verificar, pero la decisión de
publicarlo no es de quien generó el fichero: por eso va aparte.

## De dónde sale cada cosa

- **Hospitales** — OpenStreetMap vía Overpass (`amenity=hospital` con nombre),
  filtrando lo que OSM etiqueta como hospital sin serlo (ópticas, laboratorios
  dentales, centros de fertilidad). Reproducible con `extraer_hospitales.py`.
- **Coordenadas de acopio** — Nominatim, y **solo** los aciertos sobre un
  lugar concreto (universidad, plaza, coliseo). De 63 puntos solo 6 llegaron a
  ese nivel: la nomenclatura colombiana (`Carrera 64D #86-75`) casi no existe
  en OSM. Reproducible con `geocodificar_acopio.py`.
- **El SQL** — `generar_sql.py`, a partir de los dos anteriores. Escribe los dos ficheros.
- **Epicentro** — no está aquí. Es un hecho fijo del evento, no un dato
  editable, y vive en `lib/core/config/sismo.dart` con la referencia de USGS.

## Lo que no se rellena, y por qué

**Estado operativo, camas libres, insumos.** `hospitals_osm` ni siquiera tiene
columna para eso. Lo único que trae la fuente es `has_emergency`, que dice si
el centro tiene servicio de urgencias — no si hoy está recibiendo. La app
muestra siempre "Estado sin confirmar", fijado con test. Tras un sismo de 7.4,
mandar a alguien con un herido a un hospital que no está recibiendo es el daño
concreto que esto evita.

**Coordenadas aproximadas.** 25 direcciones resolvieron a una calle sin número
y 5 al centroide de una ciudad entera. Una chincheta afirma "ven aquí"; a un
kilómetro eso hace daño, y el punto ya sale en la lista con su dirección en
texto. Se quedan en `null` hasta que alguien las marque a mano sobre el mapa.
