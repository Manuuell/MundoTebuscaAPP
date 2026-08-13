# 11. Cómo se actualizan noticias, sismos y comunidad (respuesta a Manuu)

Manuu preguntó de dónde salen y cada cuánto se refrescan: (1) las noticias y
sus APIs, (2) los mensajes que llegan a Comunidad, (3) los sismos. Los tres
funcionan distinto y **ninguno vive en este repo** — todo sale del backend del
repo web (`Angelsistemas7/ElMundo-Te-Busca`), que es la misma base de datos
Supabase a la que la app Flutter se conecta directo. Este documento explica el
mecanismo real (verificado contra el código, no supuesto) y qué falta
conectar del lado Flutter.

## 1. Noticias (`src/lib/news.ts` + `src/app/api/cron/warm-news/route.ts`)

**No hay tabla en Supabase para noticias de prensa.** Se piden en vivo a APIs
externas y se cachean en el propio proceso de Next.js (memoria + un archivo en
`/tmp` como respaldo si el proceso se reinicia). La app Flutter **no puede
leer esto de Supabase** porque no está ahí — tendría que llamar a un endpoint
del sitio web (ver §4).

Cadena de fuentes, en orden, todas gratis:

1. **GDELT 2.0** (`api.gdeltproject.org`) — sin clave, cobertura mundial,
   trae foto real (`socialimage`) y URL directa al artículo. A veces falla
   horas seguidas (medido en producción), por eso hay respaldo.
2. **GNews.io** — necesita `GNEWS_API_KEY` (capa gratis: 100 peticiones/día).
   Respaldo de GDELT, ya viene en español.
3. Si ambas fallan: se sirve la **última caché buena** guardada (memoria o
   disco). Solo si nunca hubo una caché buena se devuelve `[]`.
4. Aparte, **Google Noticias RSS** (`getWorldPress`, sin clave) alimenta un
   carrusel secundario sin depender de GDELT/GNews.

**Frescura:** caché de 6 horas (`NEWS_TTL_MS`). Las cifras de víctimas
(fallecidos/heridos/desaparecidos/afectados, extraídas por IA de titulares
reales — nunca inventadas, ver `extractCrisisFigures`) tienen caché de 3 horas
porque cambian más rápido.

**Quién dispara el refresco:** un cron en el VPS le pega cada hora al
endpoint interno `warm-news`:

```
0 * * * * curl -fsS "http://127.0.0.1:3200/api/cron/warm-news?secret=..."
```

Esto "calienta" la caché para que la primera visita real del día no espere a
GDELT/GNews (pueden tardar varios segundos). Sin este cron el sistema sigue
funcionando igual, solo que la primera visita después de que vence el TTL
paga el costo de la espera.

**Filtrado por país:** cada país tiene su propio `searchQuery`/`matchPattern`
en `countries.ts` — Venezuela y Colombia no se mezclan aunque ambos usen
"terremoto"/"sismo" como término.

## 2. Sismos (`src/lib/usgs.ts`)

**Tampoco hay tabla en Supabase.** Sale en vivo de la API pública y gratuita
del **USGS** (Servicio Geológico de EE. UU.), sin clave:

```
https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&starttime=...&minmagnitude=3.5&...
```

Filtra por la caja geográfica (`usgsBbox`) del país activo, últimos 30 días,
magnitud ≥ 3.5 por defecto. Cachea con el mecanismo nativo de Next
(`next: { revalidate: 1800 }`, 30 min) — no necesita cron aparte porque Next
ya lo revalida solo en cada request pasado ese tiempo.

**Esto es justo lo que falta en Flutter.** `CifrasRepository.sismo()`
(`lib/repositories/cifras_repository.dart:116`) hoy devuelve `null` siempre,
con el comentario correcto de por qué: "no hay tabla para esto todavía". La
corrección NO es crear una tabla — es que Flutter llame a la **misma API
USGS directo**, igual que hace `usgs.ts`, con el mismo `usgsBbox` por país
(replicar `COUNTRIES[country].usgsBbox` de `countries.ts` en
`core/config/`). Es una API pública sin clave, se puede pedir desde el
cliente sin pasar por Edge Function. Candidato para quien tenga tiempo libre
(no bloquea a nadie, mencionado ya en `06-correcciones-y-reparto.md` bajo
"Noticias" en la parte de Angel — sismos es el mismo tipo de tarea).

## 3. Mensajes de Comunidad (tabla `posts`)

Hay **dos caminos** que terminan en la misma tabla `posts`, con
`moderation_status` como el filtro que los distingue:

### a) Publicados directo por una persona (web o, cuando Angel termine la
Edge Function, la app)

Van a `moderation_status = 'approved'` **al instante** — no hay cola de
espera para posts humanos directos, aparecen apenas se insertan. La
protección contra abuso es Turnstile (anti-bot) + las reglas de negocio de la
Edge Function, no una revisión manual previa.

### b) Ingeridos automáticamente de redes sociales (`scripts/fetch-social-posts.mjs`)

Busca el hashtag de la emergencia (`#TerremotoVE`, `#TerremotoColombia`, etc.)
en las APIs **públicas y oficiales** de Bluesky, Mastodon y Reddit (nada de
scraping ni de X/Twitter — su API por hashtag es de pago). Cada resultado
nuevo se inserta con **`moderation_status = 'pending'`** y el `country` según
qué búsqueda lo trajo. Un filtro opcional de IA (`OPENAI_API_KEY`, GPT-4o-mini)
puede sugerir aprobar/rechazar/revisar, pero **nunca publica solo**: siempre
pasa por un moderador humano en `/admin`.

**Cron:** cada 15 minutos en el VPS:

```
*/15 * * * * cd /var/www/elmundotebusca/scripts && node fetch-social-posts.mjs
```

**Por qué esto le importa a la app Flutter — ya está bien resuelto:**
`ComunidadRepository.muro()` (`lib/repositories/comunidad_repository.dart:21-31`)
ya filtra `moderation_status = 'approved'` explícito, con el comentario
correcto sobre por qué es obligatorio. Nada que corregir ahí. Lo que sí falta:

- **Live/Realtime.** Hoy el muro se trae con un `Future` (`select().eq(...)`),
  o sea que solo se actualiza al reabrir la pantalla o hacer pull-to-refresh.
  `personas_repository`/`ayuda_repository` ya dejan "Realtime listo" según el
  README (`Estado actual`); `comunidad_repository` y `novedades_repository`
  todavía no se suscriben a cambios (`_db.channel(...).onPostgresChanges(...)`
  de `supabase_flutter`). No es urgente — pull-to-refresh cubre el caso hoy —
  pero es la pieza que falta para que un post nuevo aparezca solo, sin que
  alguien recargue.
- **Notificar posts nuevos vía `novedades_repository.dart`**: hoy solo mira
  personas localizadas y posts fijados (`pinned = true`); podría sumar posts
  nuevos de tipo urgente (`necesito`, `rescate`) como otra fuente de
  novedades — pendiente de decidir si se quiere ese ruido o no.

## 4. Actualización (commit `7ecdb2d`, Manuel): noticias ya resuelto en Flutter — sin backend nuevo

Cuando se escribió la primera versión de este documento, la sección 4 recomendaba
un endpoint propio en el repo web para no reimplementar GDELT+GNews+OpenAI en
Dart. Manuel llegó a la misma conclusión sobre el riesgo real (GNews exige
`GNEWS_API_KEY`, que **no puede viajar en un APK/IPA** — cualquiera lo
descomprime) y la resolvió sin backend nuevo, con `noticias_repository.dart`:

- **GDELT directo desde Flutter** (sin clave, misma consulta por país que la
  web) — igual que USGS en §2, es una API pública que sí se puede llamar
  desde el cliente.
- **GNews queda fuera a propósito.** GDELT devuelve casi todo en inglés para
  estas consultas (medido: 53 en inglés, 7 en urdu, 0 en español) — la web
  tapa eso con GNews + traducción por OpenAI, que la app no puede replicar
  sin exponer una llave. La app en cambio **marca el idioma** de cada nota
  (`Noticia.idioma`/`enEspanol`) y avisa antes de abrir una que no está en
  español, en vez de fingir que todo es igual de legible.
- **`news_items` (tabla que YA existe en `supabase/schema.sql:518`)** aporta
  las noticias curadas por el equipo — van primero en el carrusel, no
  dependen de ningún agregador externo.
- **Caché de 10 min en memoria** (`NoticiasRepository._cache`) — GDELT limita
  a 1 petición cada 5s y responde 429 si se pasa; sin esta caché, dos
  refrescos seguidos dejaban el carrusel vacío.
- **Deduplica** (GDELT repite el mismo teletipo de agencia en decenas de
  medios) y limpia títulos tokenizados (`"AP News in Brief at 6 : 04 a . m"`).

**Conclusión para quien toque esto después:** no hace falta el endpoint
`/api/mobile/news` que sugería la versión anterior de este documento — ya
está resuelto del lado Flutter con datos 100% públicos + la tabla curada. Si
en el futuro se necesitan las cifras de víctimas (`extractCrisisFigures`,
que sí depende de OpenAI de pago) o el fallback GNews en español, **esas sí**
necesitan pasar por un endpoint del sitio web o por la Edge Function — no
tiene sentido meter esas llaves en el cliente.

## Resumen para Manuu

| Dato | Fuente real | Cron/refresco | Tabla en Supabase | Estado en Flutter |
|---|---|---|---|---|
| Noticias (carrusel, web) | GDELT → GNews (fallback) + traducción OpenAI | Caché 6h, cron horario "calienta" | No — vive en memoria/disco del proceso Next | — |
| Noticias (carrusel, Flutter) | GDELT directo + `news_items` curadas | Caché 10 min en memoria (límite de GDELT) | `news_items` (curadas) | ✅ Hecho (`7ecdb2d`) — GNews/traducción fuera a propósito, ver §4 |
| Cifras de víctimas | GDELT + IA (GPT-4o-mini) | Caché 3h | No | Igual que arriba |
| Sismos | USGS (API pública, sin clave) | Caché 30 min (nativo de Next) | No | `CifrasRepository.sismo()` devuelve `null` a propósito — falta llamar a USGS directo, ver §2 |
| Posts humanos directos | Formulario web (pronto: app) | Instante, sin cola | `posts`, `moderation_status='approved'` | Ya filtra bien; falta Realtime (opcional) |
| Posts de redes sociales | Bluesky/Mastodon/Reddit (APIs oficiales) | Cron cada 15 min | `posts`, nace `moderation_status='pending'`, requiere aprobación en `/admin` | Ya filtra bien |
