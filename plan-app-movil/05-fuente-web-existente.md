# 05 — Fuente: repositorio web existente

> Extraído de `C:\venezuela-te-busca` (repo: [Angelsistemas7/ElMundo-Te-Busca](https://github.com/Angelsistemas7/ElMundo-Te-Busca)) el 2026-08-13.
> Este documento es la base factual para el resto del plan móvil: describe lo que la web **realmente** hace hoy, no lo que dice el README (desactualizado).

## Nota de contexto importante

El proyecto **cambió de nombre y alcance** durante su desarrollo. Nació como "Venezuela te busca" (terremoto VE) pero ahora es **multi-país** bajo la marca **"El Mundo Te Busca"** (`elmundotebusca.com`), con Venezuela y Colombia como instancias activas y arquitectura lista para agregar más países/desastres. El `README.md` describe la versión original (solo Venezuela, deploy en Vercel); la realidad actual es multi-país y desplegada en un **VPS propio**.

**Decisión pendiente para el plan móvil:** ¿la app se alinea a la visión multi-país desde el día uno (selector de país, campo `country` en cada entidad), o se limita intencionalmente a un país?

---

## 1. Stack y arquitectura general

### Stack tecnológico (web)
- **Framework**: Next.js 15 (App Router), React 19, TypeScript, Server Components + Server Actions.
- **Estilos**: Tailwind CSS v4 (`@theme` en `globals.css`, sin `tailwind.config.js` tradicional).
- **Base de datos**: Supabase (PostgreSQL) + Supabase Storage (fotos) + Supabase Auth + Row Level Security.
- **Anti-bot**: Cloudflare Turnstile en formularios públicos.
- **Mapa**: Leaflet / react-leaflet.
- **Validación**: zod (mismos esquemas en cliente y servidor).
- **Imagen**: `sharp` (compresión a WebP antes de subir).

### Hosting / despliegue real
VPS propio (no Vercel): GitHub Actions → rsync por SSH → PM2 corre el build `standalone` de Next.js detrás de nginx. Cron interno para precalentar noticias.

### Patrones de arquitectura clave
1. **Capa de datos doble** (`src/lib/data.ts`): cada función intenta Supabase primero; si no hay credenciales, usa un store en memoria con datos semilla. La UI nunca toca Supabase directamente.
2. **Todas las escrituras van por Server Actions**, validadas con zod + Turnstile, ejecutadas con la service role de Supabase (no hay INSERT/UPDATE público con clave anon).
3. **Dos modelos de "verdad"**:
   - **Personas → autoridad**: solo el autor (token privado) o un moderador cambian el estado oficial. Cualquier otro reporte queda visible pero "sin verificar".
   - **Recursos (puntos de ayuda, hospitales) → consenso**: la comunidad vota, un voto por cuenta/dispositivo.
4. **Gestión por enlace de autor**: tabla genérica `resource_owners` da un token privado de gestión sin necesidad de cuenta.
5. **Cuentas opcionales**: se puede publicar sin sesión (token anónimo) o con cuenta (username + password, correo opcional).
6. **Multi-país**: casi todas las tablas tienen columna `country`; `src/lib/countries.ts` centraliza configuración por país.

**Implicación para móvil:** el patrón "publicar sin cuenta + token de gestión por enlace" es una decisión de producto central, no trivial de trasladar a una app nativa (los enlaces con token funcionan bien en web/WhatsApp; en móvil habría que decidir entre deep links, guardar el token localmente, o forzar cuenta).

---

## 2. Modelo de datos

Fuente de verdad: `supabase/schema.sql`. Tablas principales:

| Tabla | Propósito | Campos/notas clave |
|---|---|---|
| `persons` | Núcleo: personas buscadas/encontradas | `status` (por_localizar/localizado/hospitalizado/fallecido), `is_unidentified`, `search_doc` (full-text incluyendo descripción), `photo_hash` (dedup), `country` |
| `person_owners` | Token privado de gestión (1:1 con persona) | sin lectura pública |
| `resource_owners` | Token de gestión genérico | `entity_type` (aid_point/march/post/pet) + `entity_id` |
| `resource_managers` | Gestor delegado de UN recurso concreto | asignado por admin |
| `manager_requests` | Solicitud de ser gestor delegado | aprobación por admin |
| `app_roles` | Roles globales por cuenta | admin / moderator / hospital_moderator / aid_point_moderator |
| `status_reports` | Reportes de cambio de estado de una persona | `verified` (no cambia el estado público hasta verificarse) |
| `aid_points` | Puntos de ayuda | `types[]`, `category_status` (jsonb: urgente/limitado/cubierto por categoría), votos de consenso |
| `marches` | Caravanas | origen/destino/fecha, WhatsApp, vínculo opcional a `aid_point` |
| `hospitals` | Hospitales | `status` (operativo/saturado/lleno/cerrado), especialidades, consenso de insumos |
| `hospital_patients` | Pacientes por hospital | para que la familia ubique a alguien |
| `posts` | Feed de Comunidad | `type` (necesito/ofrezco/rescate/medico/caravana/identificar/info), ingesta automática desde Bluesky/Mastodon con cola de moderación |
| `complaints` | Denuncias | requiere sesión (no anónimo) |
| `pets` | Mascotas | mismo modelo que personas |
| `volunteers` | Directorio "Puedo ayudar" | tipo, disponibilidad, habilidades |
| `heroes` | Sección curada de Noticias | cualquiera propone, admin verifica |
| `news_items` | Noticias curadas por el equipo | |
| `comments` | Foro transversal | `entity_type` cubre casi todas las tablas, hilos de 1 nivel |
| `profiles` | Perfil de usuario | username único, correo opcional (sintético si no hay) |
| `saved_items` | "Guardados" por cuenta | único por (user, entity_type, entity_id) |
| `consensus_votes` | Un voto por cuenta y recurso | reemplaza contador libre anterior |

**Notas clave para el modelo de datos móvil:**
- `country` es dimensión de primer nivel en casi toda tabla.
- Coordenadas (`lat/lng`) son **opcionales** en casi todas las entidades — mucha ubicación es solo texto libre.
- Roles se resuelven en cascada: `ADMIN_TOKEN` (llave maestra) → `app_roles` (rol global) → `resource_managers` (gestor de un recurso) → autor (token o cuenta).

---

## 3. Mapa de rutas / pantallas (IA de referencia para la app)

### Navegación principal (idéntica en desktop y móvil — candidata directa a bottom tab bar nativa)
1. `/` — Inicio (dashboard, cifras, selector de país)
2. `/se-busca` — Se busca (incluye vista "¿La reconoces?" tipo Tinder)
3. `/comunidad` — Comunidad (incluye Voluntarios, Caravanas, Denuncias)
4. `/mapa` — Mapa de crisis
5. `/emergencias` — Emergencias / SOS

**"Más"** (hoja inferior en móvil): `/ayuda` (incluye Hospitales), `/mascotas`.

### Árbol de rutas completo

**Personas / búsqueda**
- `/se-busca` — listado con filtros/paginación, toggle a "¿La reconoces?" (baraja deslizable)
- `/persona/[id]` — ficha (foto, reacciones, comentarios, reportes)
- `/persona/[id]/gestion` — gestión por el autor (token)

**Comunidad**
- `/comunidad` — muro de publicaciones por tipo
- `/voluntarios`, `/voluntarios/guia`, `/voluntarios/solicitar-gestor`
- `/caravanas`, `/caravanas/[id]`, `/caravanas/[id]/gestion`
- `/denuncias` — requiere sesión

**Ayuda y salud**
- `/ayuda`, `/ayuda/[id]`, `/ayuda/[id]/gestion`
- `/hospitales`, `/hospitales/[id]`

**Mascotas**
- `/mascotas`, `/mascotas/[id]`, `/mascotas/[id]/gestion`

**Contenido informativo**
- `/noticias` — pestañas Héroes / Ayuda humanitaria / Últimas noticias / Sismos (ReliefWeb + GDELT + USGS)
- `/emergencias` — línea 911/123, directorio de bomberos/ambulancias, guía rápida, compartir por WhatsApp
- `/mapa` — Leaflet con capas activables (zonas, ayuda, hospitales, caravanas, rescates, epicentro)

**Cuenta y perfil**
- `/perfil`, `/perfil/publico/[username]`
- `/configuracion` — contraseña, correo de recuperación, notificaciones, eliminar cuenta
- `/notificaciones`
- `/cuenta/confirmar`, `/cuenta/restablecer`

**Administración**
- `/admin` — panel de moderación completo (login por token o rol)

---

## 4. Funcionalidades clave y roles de usuario

### Funcionalidades destacadas
- **Dos intenciones al publicar persona**: "Busco a alguien" vs. "Vi/encontré a alguien" (formulario adapta campos obligatorios).
- **Baraja tipo Tinder** para "¿La reconoces?": deslizar, sellos, atajos de teclado, estado vacío. Pendiente (según docs del equipo): modal de comentarios, deshacer, extender a "Se busca".
- **Reportes con fricción anti-abuso**: visibles al instante como "sin verificar"; solo autor/moderador cambian estado oficial.
- **Detección de posibles duplicados** (nombre, cédula o foto idéntica) revisable en admin.
- **Ingesta automática de redes** (Bluesky/Mastodon por hashtag) con cola de moderación antes de publicar.
- **Consenso de disponibilidad** por categoría en puntos de ayuda (urgente/limitado/cubierto).
- **Multi-país**: cada país es una instancia con sus propios datos/regiones/teléfonos sobre la misma base de datos.

### Roles de usuario (modelo de permisos)
1. **Visitante anónimo** — lee todo públicamente, puede publicar la mayoría de recursos sin cuenta (recibe token de gestión).
2. **Usuario con cuenta** — además: guardar publicaciones, "mis publicaciones" multi-dispositivo, comentar con usuario visible, denunciar (obligatorio con sesión), pedir ser gestor delegado, notificaciones.
3. **Autor de un recurso** (token o cuenta) — edita/elimina su propio registro.
4. **Gestor delegado** — autorizado por admin para UN hospital o punto de ayuda específico.
5. **Moderador de categoría** — gestiona cualquier hospital o punto de ayuda de esa categoría.
6. **Moderador general** — aprueba reportes y posts, verifica entidades.
7. **Admin completo** — control total (roles, gestores, denuncias, duplicados, noticias curadas).

---

## 5. Sistema de diseño / tema visual

> `04-tema-visual.md` ya cubre bien la paleta y tipografía base. Esta sección agrega lo que falta ahí, especialmente relevante para una app nativa (Flutter/iOS/Android).

### Paleta (resumen, ver `globals.css` para escala completa)
- **Brand (terracota)**: `brand-500 #d3824a` (CTAs, enlaces, tab activo), `brand-700 #9c552e` (tono exacto del logo).
- **Navy**: `navy-700 #1d1b40` (tono exacto del logo, fondos oscuros).
- **Gold**: acento secundario puntual (no reemplaza a brand) — **no está en `04-tema-visual.md` todavía**.
- **Semántico**: success (verde), warning (ámbar), danger (rosa/rojo), info (celeste) — usados para insignias de consenso y estados de hospital.

### Tipografía
- Cuerpo: Figtree. Títulos (`h1`-`h6`): Signika.

### Elementos que `04-tema-visual.md` aún no cubre
- **Curva de animación iOS** (`cubic-bezier(0.32, 0.72, 0, 1)`) — curva "spring" de UIKit, usada en modales/sheets.
- **Patrón `.tap-card`**: tarjeta interactiva reutilizada en TODO listado — elevación al hover, "presión" al tocar.
- **Bottom sheets**: suben desde abajo con la curva iOS, barra de arrastre (look iOS), pila de modales.
- **Safe area**: uso de `env(safe-area-inset-bottom)` — directamente relevante para notch/Dynamic Island en móvil.
- **`prefers-reduced-motion`**: todo el sistema de animación se apaga si el usuario lo pide — vale la pena replicar.
- **Transición "hero" tarjeta→ficha**: la foto "morphea" de tamaño/posición al navegar (View Transitions API) — equivalente a un "shared element transition" en Android o transición custom en iOS.
- **Mapa**: marcadores custom con pulso animado por tipo (zona afectada, rescate con doble anillo rojo, epicentro con anillos concéntricos), colores por categoría (ayuda `#f59e0b`, caravana `#0ea5e9`, necesito `#e11d48`, puedo-ayudar `#059669`, persona `#8b5cf6`).

### Componentes UI reutilizables de referencia
`Card` (contenedor "widget" base), `Modal` (con pila global), tarjetas por entidad (Person/AidPoint/Hospital/March/Post/Pet/Complaint/News/Hero), paneles de gestión por autor, `CommentSection`, componentes de foto (`PhotoView`, `PhotoLightbox`, `AvatarUpload`).

**Nota**: no hay PWA configurada (sin `manifest.json` ni iconos PWA) — descartado como atajo si se pensaba "empezar desde PWA".

---

## 6. APIs / backend disponible para la app móvil

**Hallazgo crítico**: el proyecto **no tiene API REST/GraphQL pública**. La lógica de negocio vive casi enteramente en **Server Actions de Next.js** (funciones `"use server"` invocadas directo desde el frontend web, sin URL/verbo HTTP). La única API route REST real es `GET /api/cron/warm-news` (uso interno, protegida por secreto).

Server Actions existentes cubren: autenticación/cuenta (`signUpAction`, `signInAction`, etc.), personas (`registerPersonAction`, `reportStatusAction`, etc.), puntos de ayuda, caravanas, posts, mascotas, voluntarios, héroes/noticias, denuncias, hospitales, comentarios, y un set completo de acciones de administración/moderación.

### Opciones para que la app móvil consuma los mismos datos (de menor a mayor reutilización de lo ya construido)

1. **Conectar directo a Supabase** con el SDK oficial — mismo Postgres, RLS ya define qué es público, pero habría que **replicar en el cliente móvil** la validación zod y la lógica de negocio que hoy solo vive en las Server Actions (Turnstile, tokens de propietario, roles, generación de tokens de gestión).
2. **Envolver las Server Actions actuales en API routes REST** — reutiliza toda la lógica de validación/seguridad ya escrita, es el camino de **menor riesgo de seguridad duplicada**. *(Recomendado como punto de partida.)*
3. **Supabase Edge Functions** para lógica compartida (Turnstile, tokens) si se quiere desacoplar del propio Next.js.

**Esto define el primer bloque de trabajo real antes de poder construir la app móvil**: no existe hoy una API que la app pueda consumir; hay que construirla (opción 2 es la más consistente con la arquitectura actual).

---

## Resumen de implicaciones para el plan móvil

- **Backend**: hace falta construir una capa de API REST sobre las Server Actions existentes antes de poder avanzar con clientes nativos.
- **Identidad de producto**: confirmar si la app se llama y se comporta como "El Mundo Te Busca" (multi-país) desde el inicio.
- **Autenticación sin cuenta**: decidir cómo se traduce el patrón "token de gestión por enlace" a una app nativa (deep link, almacenamiento local del token, o exigir cuenta siempre).
- **Navegación**: el patrón "5 tabs + Más" ya validado en la web es el punto de partida natural para la bottom tab bar nativa.
- **Diseño**: `04-tema-visual.md` necesita actualizarse con la paleta `gold`, la curva de animación iOS, el patrón de bottom-sheet y `.tap-card` para mantener fidelidad visual con la web.
- **Mapa**: Leaflet no es nativo — habrá que decidir el equivalente en móvil (ej. `flutter_map`, Mapbox, Google Maps) manteniendo las mismas capas y estilos de marcador.
