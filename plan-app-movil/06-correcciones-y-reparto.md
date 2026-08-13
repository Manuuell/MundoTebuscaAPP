# 6. Correcciones de esquema y reparto de trabajo (3 personas)

Escrito después del commit `feat: cimientos de la app movil (Fase 0 + parte de
Fase 1)` de Manuel — cimientos sólidos (`Fresh<T>` para antigüedad de datos,
`CifraChip` que nunca muestra negativos, rutas idénticas a la web para deep
linking). Este documento tiene dos partes: (1) una corrección de esquema
urgente y rápida de aplicar, y (2) el reparto de TODO lo que falta para migrar
la app web completa, en 3 partes que no se pisan entre sí.

No repite nada de `01-05` (arquitectura, contenido/navegación, roadmap, tema
visual, fuente web) — ya están decididos, léanlos si no lo han hecho.

---

## Parte 1 — Corrección de esquema (aplicar primero, ~20-30 min, quien la vea libre la toma)

El propio código ya lo marcaba como pendiente (`TODO(schema)` en
`lib/models/persona.dart` y `lib/models/punto_ayuda.dart`): los nombres de
tabla/columna puestos son los que "sonaban lógicos", no los reales. Verificado
ahora contra `supabase/schema.sql` del repo web (que es la fuente de verdad).
Si esto no se corrige, la app conecta a Supabase real y **todo vuelve vacío o
`null` en silencio** — no hay excepción, `fromMap` simplemente no encuentra la
columna y usa el default.

### `persons` (no `personas`)

| Campo Dart hoy (`Persona`) | Columna real en `persons` | Nota |
|---|---|---|
| `nombre` | `first_name` + `last_name` | son 2 columnas, no 1 — concatenar o mostrar por separado |
| `estado` (usado como *estado de la persona*) | **`status`** | ⚠️ ojo: `persons` también tiene una columna que literalmente se llama `estado`, pero es el **estado/región geográfica** (ej. "La Guaira", "Zulia"), NO el status de búsqueda. Son dos conceptos distintos con el mismo nombre en español — la enum `EstadoPersona` (`por_localizar`/`hospitalizado`/`localizado`/`fallecido`) debe leer y filtrar por `status`, no por `estado` |
| `edad` | `age` | — |
| `documento` | `cedula` | — |
| `ubicacion` | `location_text` | — |
| `foto_url` | `photo_url` | ya coincidía |
| `descripcion` | `description` | — |
| `actualizadoEn` / `updated_at` | `updated_at` | ya coincidía |
| — (falta en el modelo) | `country` | filtro de país — el repo ya usa `paisCodigo` como parámetro, pero debe mapear a `.eq('country', paisCodigo)`, no a una columna `pais` inexistente |
| — (falta en el modelo) | `is_unidentified` | necesario para separar "Se busca" de "¿La reconoces?" (son la misma tabla, este booleano las distingue) |
| — (falta en el modelo) | `lat` / `lng` | **nullable en la base** — mucha ubicación es solo `location_text`, sin coordenadas |

Consecuencia en `lib/repositories/personas_repository.dart:31`: el filtro
`q.eq('estado', estado.wire)` está filtrando por la columna equivocada (el
nombre del estado geográfico, no el status). Debe ser `q.eq('status',
estado.wire)`.

### `aid_points` (no `puntos_ayuda`)

| Campo Dart hoy (`PuntoAyuda`) | Columna real en `aid_points` | Nota |
|---|---|---|
| `nombre` | `name` | — |
| `tipo` (singular) | `types` | ⚠️ es **array** (`aid_point_type[]`) — un punto puede ser de varios tipos a la vez (ej. comida + agua), no uno solo |
| `direccion` | `location_text` | — |
| `telefono` | `contact_phone` | — |
| `disponible` | `available` | booleano de consenso — lo fija el autor/admin según el voto de la comunidad, ver `votes_available`/`votes_depleted` si se quiere mostrar el conteo además del booleano |
| `lat` / `lon` (como `double` **requerido**) | `lat` / `lng` (**nullable**) | ⚠️ dos bugs: el nombre es `lng` no `lon`, y son **nullable** — el modelo actual truena (`as num`) en cualquier punto sin coordenadas, que es un caso real y común (`location_text` solo) |
| — (falta) | `country` | mismo patrón que `persons` |
| — (falta) | `category_status` (jsonb) | existencias por categoría (ej. `{"agua":"urgente"}`) — no es parte del MVP de lectura simple, pero que quien lo toque sepa que existe |

**Recomendación**: dado que 2-3 personas van a tocar estos modelos en paralelo,
que UNA sola persona aplique esta corrección primero (Parte 1) y la
haga commit/push antes de que las otras dos empiecen a construir pantallas
sobre ellos — evita que cada quien corrija la misma clase por su lado y
choquen al hacer merge.

---

## Parte 2 — Reparto en 3 (para migrar toda la app web)

Basado en el árbol de rutas completo de `05-fuente-web-existente.md` §3,
cruzado con lo que Manuel ya dejó construido. Cada persona trabaja en
carpetas/archivos que las otras dos no tocan — minimiza choques de merge.
Commits chicos y frecuentes, push seguido.

### 👤 Persona A — Personas y Comunidad

**Ya hay base para seguir** (`se_busca_screen.dart`, `personas_repository.dart`
— aplicar antes la corrección de esquema de la Parte 1 si nadie más lo hizo).

- Terminar **"Se busca"** (`/se-busca`): ya tiene búsqueda/filtros, falta
  paginación si no la tiene y pulir con datos reales.
- **"¿La reconoces?"** (personas con `is_unidentified = true`): la baraja tipo
  Tinder que describe `05-fuente-web-existente.md` §4 — deslizar, atajos,
  estado vacío. Misma tabla `persons`, mismo repositorio, filtro distinto.
- **Comunidad** (`comunidad_screen.dart` ya tiene los 3 tabs vacíos, hay que
  llenarlos):
  - Voluntarios → tabla `volunteers` (`type`, `name`, `availability_text`,
    `skills_text`, `estado`).
  - Caravanas → tabla `marches` (`title`, `origin_text`, `destination_text`,
    `depart_at`, `organizer_name`, `organizer_phone`, `whatsapp_url`).
  - Denuncias → tabla `complaints` (`category`, `body`, `author_name`,
    `supports`) — **requiere sesión en la web** (no es anónimo), mismo
    criterio en la app.
  - Muro principal de Comunidad (posts) → tabla `posts` (`type` con 7
    valores: necesito/ofrezco/rescate/medico/caravana/identificar/info,
    `body`, `reactions` jsonb, `pinned`). Ojo con `moderation_status`: los
    posts que llegan de Bluesky/Mastodon nacen `pending` y NO deben mostrarse
    hasta `approved` — filtrar siempre por `moderation_status = 'approved'`.
- Fase 2 (cuando la Edge Function de Persona C esté lista): registrar
  persona/reporte, publicar en comunidad, votar, comentar.

### 👤 Persona B — Ayuda, Hospitales, Mascotas y Mapa completo

- Aplicar la corrección de esquema de `PuntoAyuda` (Parte 1) si nadie más lo
  hizo todavía.
- Terminar **Ayuda** (`ayuda_screen.dart`, hoy vacía): listado de
  `aid_points` con el consenso de disponibilidad (badge "✅ Sí hay" / "❌ Se
  acabó" según `available`).
- **Hospitales** (no existe pantalla todavía, hay que crearla —
  `lib/features/hospitales/`): tabla `hospitals` (`status` con
  operativo/saturado/lleno/cerrado, `specialties[]`, `needs_text`, consenso de
  insumos vía `votes_supplies`/`votes_no_supplies`) + `hospital_patients`
  (para que una familia ubique a alguien internado — cruza con Persona A si
  hay tiempo, pero no bloquea).
- **Mascotas** (`mascotas_screen.dart`, hoy vacía): tabla `pets`, mismo patrón
  que personas (`status`: perdida/encontrada/refugio/veterinario).
- **Mapa completo** (`mapa_screen.dart` ya tiene capas conmutables, falta
  contenido real): conectar las capas a `aid_points`/`hospitals`/`marches` con
  coordenadas reales, marcadores por tipo, rescates y zona/epicentro si hay
  esos datos en la web (revisar `CrisisMap.tsx` del repo web para la lista
  completa de capas).

### 👤 Persona C — Backend compartido, deep linking, cuentas y lo que falta

Esta parte es la más "de infraestructura": lo que A y B necesitan para poder
escribir datos (Fase 2), y lo que nadie más puede tocar sin pisarse.

- **Edge Function delgada de validación de escrituras** — es lo que
  desbloquea Fase 2 para A y B (crear persona, reportar estado, crear post,
  votar, subir foto). Sin esto, A y B solo pueden avanzar en lectura. Prioridad
  máxima de esta parte. (Está en investigación profunda en paralelo — llega un
  documento técnico aparte con el diseño exacto; mientras tanto puede empezar
  por el esqueleto del proyecto Supabase Edge Functions y una función de
  prueba end-to-end).
- **App Attest (iOS) / Play Integrity (Android)** — verificación server-side,
  depende de la Edge Function de arriba.
- **Deep linking real**: `assetlinks.json` / `apple-app-site-association` —
  **estos archivos van en el REPO WEB** (`elmundotebusca.com/.well-known/`,
  repo `Angelsistemas7/ElMundo-Te-Busca`), no en este repo Flutter. Requiere
  el SHA256 del certificado de firma Android y el Team ID de Apple — si nadie
  los tiene todavía a mano, dejarlo con un placeholder documentado y avisar.
- **Validación del token de gestión** (`persona_gestion_screen.dart` ya tiene
  el TODO explícito: "el token NO se valida en el cliente"): implementar el
  endpoint/Edge Function que replica `verifyResourceOwner`
  (`src/lib/data.ts:1219` en el repo web) para que gestión de persona (y luego
  de ayuda/caravanas) funcione de verdad.
- **Cuentas** (Fase 3, si alcanza el tiempo): login/registro con Supabase
  Auth — no bloquea a A ni B, que pueden seguir publicando sin cuenta (token
  anónimo) igual que la web permite hoy.
- **Noticias** (no existe pantalla, `05-fuente-web-existente.md` la describe:
  tabs Héroes / Ayuda humanitaria / Últimas noticias / Sismos) — no depende de
  nadie más, se puede hacer en cualquier momento si sobra tiempo.
- **Guía SOS empaquetada** (`sos_screen.dart` ya tiene el TODO: la guía de
  `/emergencias` debe ir como **asset local**, no fetch de red — es contenido
  que hace falta justo cuando no hay señal).

---

## Qué NO es de nadie todavía (a propósito)

- Push notifications (Fase 4) — depende de que Fase 2 esté sólida primero.
- Cache offline con Drift/Isar/Hive (Fase 4) — mismo motivo.
- Publicación en tiendas — no hay cuenta Apple Developer todavía, no aplica.

## Una vez cada parte tenga algo andando

`flutter analyze && flutter test` antes de cada push (ya está en el README).
Si dos partes tocan sin querer el mismo archivo (más probable en
`app_router.dart` al agregar rutas nuevas como Hospitales/Noticias), avisarse
antes de mergear — es un archivo compartido por diseño, no se puede evitar del
todo.
