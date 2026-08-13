# Datos del mapa de Colombia

`mapa_colombia.sql` se ejecuta **a mano en el editor SQL de Supabase**. La
`anon key` no puede insertar (la política `public_insert_aid` / 
`public_insert_hospitals` está retirada en el esquema del sitio, a propósito,
después del abuso que sufrió la web), así que no hay forma de cargar esto
desde la app ni con un script que use la llave pública.

Es idempotente: los `id` de hospital son `uuid5` del identificador de
OpenStreetMap, con `on conflict (id) do nothing`. Volver a ejecutarlo no
duplica nada, y cada fila se puede rastrear hasta el objeto OSM del que salió.

## Qué carga

| | |
|---|---|
| 167 hospitales | Risaralda, Valle del Cauca, Chocó, Quindío y Caldas — los cinco departamentos con desaparecidos registrados del sismo |
| 6 coordenadas | puntos de acopio que ya estaban en `aid_points` sin `lat`/`lng` |

## De dónde sale cada cosa

- **Hospitales** — OpenStreetMap vía Overpass (`amenity=hospital` con nombre),
  filtrando el ruido que OSM etiqueta como hospital y no lo es (ópticas,
  laboratorios dentales, centros de fertilidad). Reproducible con
  `extraer_hospitales.py`.
- **Coordenadas de acopio** — Nominatim, y **solo** los aciertos sobre un
  lugar concreto (universidad, plaza, coliseo). De 63 puntos solo 6 llegaron
  a ese nivel: las direcciones colombianas con nomenclatura de nomenclatura
  (`Carrera 64D #86-75`) casi no existen en OSM. Los otros 57 se quedan sin
  coordenada a propósito — ver abajo. Reproducible con
  `geocodificar_acopio.py`.
- **Epicentro** — no está aquí. Es un hecho fijo del evento, no un dato
  editable, y vive en `lib/core/config/sismo.dart` con la referencia de USGS.

## Lo que este script NO rellena, y por qué

**Estado operativo de los hospitales.** El esquema obliga (`status not null
default 'operativo'`, con un `check` que no admite `desconocido`), así que las
filas entran con `'operativo'` porque no hay otra opción legal. **Eso no es
una afirmación**: entran todas con `verified = false`, y la app no muestra
estado mientras la fila no esté verificada — dice "Estado sin confirmar". Hay
un test que lo fija (`PuntoAyuda.desdeHospital sin verificar no afirma el
estado operativo`).

Si alguien quiere que la base pueda decir "no se sabe" en vez de apoyarse en
esa convención, la migración es una línea:

```sql
alter table hospitals drop constraint hospitals_status_check;
alter table hospitals add constraint hospitals_status_check
  check (status in ('operativo','saturado','lleno','cerrado','desconocido'));
```

Es el esquema compartido con la web, así que esa decisión es de Angel.

**Camas libres, insumos que faltan, teléfonos no publicados.** Nada de eso se
deduce desde fuera. En una app de emergencia un dato inventado es peor que un
hueco: el hueco se ve, el dato falso se cree.

**Coordenadas aproximadas.** 25 direcciones resolvieron a una calle sin
número y 5 al centroide de una ciudad entera. Una chincheta afirma "ven
aquí"; a un kilómetro de distancia eso hace daño, y el punto ya sale en la
lista con su dirección en texto. Se quedan en `null` hasta que alguien las
marque a mano sobre el mapa.
