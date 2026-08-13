# 2. Contenido y navegación

## Qué no conviene tener como sección propia en la app — y por qué

| Ruta web | Por qué no |
|---|---|
| `/admin` | Uso de escritorio, poco frecuente, alta complejidad de UI (tablas, acciones en lote). Ya funciona bien en web para quien modera; replicarlo en móvil es esfuerzo alto para valor bajo |
| `/recursos` | Ya es un `redirect()` a `/emergencias` en la propia web (`src/app/recursos/page.tsx:6-8`) — no hay contenido real que portar |
| `/noticias` | Ya es un `redirect()` a `/ayuda` (`src/app/noticias/page.tsx:7-9`) — su contenido se repartió entre `/ayuda` (ReliefWeb, héroes, sismos) y `/comunidad` (historias destacadas) |
| `/mantenimiento` | No es contenido, es un estado global de la app cuando el backend está caído. En Flutter es una pantalla de estado a nivel de app, no un ítem de navegación |
| `/cuenta/confirmar`, `/cuenta/restablecer` | Son destinos de un enlace de correo (recuperar contraseña), no secciones que alguien visite por su cuenta. El equivalente móvil es una pantalla de "restablecer contraseña" propia, alcanzada por Universal Link/App Link desde el correo — se construye, pero no va en el menú |

## Sí, pero en fases posteriores (no en el MVP de lectura/escritura)

`/perfil`, `/configuracion`, `/perfil/publico/[username]` — cuentas y ajustes.
Ubicados en la Fase 3 (Cuentas) del [roadmap](03-roadmap.md); no son parte de
"salvar vidas ya" y no bloquean nada si se posponen.

## Todo lo demás: sí, heredando la jerarquía que la propia web ya definió para móvil

Hallazgo clave: `MobileNav.tsx` (la barra inferior que ya usa la PWA en
pantallas chicas, en el repo web) **ya resolvió esta jerarquía** — no hay que
inventarla de nuevo:

- **5 tabs primarios** (`MobileNav.tsx:33-39`): Inicio (`/`), Se busca
  (`/se-busca`), Comunidad (`/comunidad`), Mapa (`/mapa`), SOS (`/emergencias`).
- **Hoja "Más"** (`MobileNav.tsx:41-44`): Ayuda y hospitales, Mascotas.
- **Comunidad agrupa** voluntarios, caravanas y denuncias
  (`MobileNav.tsx:30`, `COMMUNITY_PATHS`) — no son tabs propios, son
  subsecciones dentro de Comunidad.
- **Ayuda agrupa** hospitales (`MobileNav.tsx:31`, `AYUDA_PATHS`).

Recomendación: Flutter **hereda esta misma jerarquía tal cual** (mismos 5 tabs
+ hoja "Más"), en vez de diseñar una nueva. Beneficio directo: quien ya usa la
PWA no tiene que reaprender nada al pasar a la app nativa.

## Pantalla Inicio: contenido exacto (de `src/app/page.tsx:12-35` en el repo web)

**No es un feed de tarjetas** — son 4 bloques verticales, cada uno en su
propio `Suspense` en la web para que el cascarón aparezca de inmediato aunque
las noticias externas tarden:

1. **Selector de país** (`CountrySwitcher`, dentro de `HomeHero.tsx:159-161`)
   — en móvil se reduce a un control compacto en la barra superior (bandera +
   nombre + chevron) en vez de la tarjeta grande de escritorio.
2. **Hero** (`HomeHero.tsx:140-213`): título+subtítulo con gancho emocional
   (mención al país activo y fecha del sismo), 2 CTAs — *"¿Cómo puedo
   ayudar?"* → guía de voluntarios, y *"Ver mapa EN VIVO"* → en móvil esto
   debería **cambiar a la pestaña Mapa** en vez de navegar a una pantalla
   nueva (evita apilar una ruta redundante sobre un tab ya existente) — y el
   panel **"Juntos somos más fuertes"** con 4 cifras animadas: Personas
   buscadas, Reportes verificados, Voluntarios activos, Puntos de ayuda.
3. **Cifra del sismo** (`CrisisStatsPanel`, `HomeHero.tsx:102-129`):
   fallecidos/heridos/desaparecidos/afectados **según prensa reciente, con
   fuente y fecha visibles** — o el bloque curado estático si la cifra de
   prensa tiene más de 30 días (`CRISIS_STAT_FRESHNESS_MS`, línea 89). Regla
   de honestidad ya resuelta en la web: nunca mostrar una cifra vieja como si
   fuera reciente — el mismo principio que ya aplica al cache offline (ver
   [arquitectura](01-arquitectura.md)).
4. **Fila de 8 cifras deslizables** (`DashboardStats.tsx:34-59`):
   Desaparecidos, En hospitales, A salvo, Niños, Fallecidos, Denuncias,
   Necesidades, Ofrecen ayuda — cada una es un enlace a su filtro. En web ya
   es una fila de scroll horizontal en móvil (`DashboardStats.tsx:49-51`); en
   Flutter es un `ListView` horizontal directo, cada chip navega a la
   pestaña/pantalla correspondiente con el filtro pre-aplicado.
5. **Carrusel de noticias verificadas** (`VerifiedNewsCarousel.tsx`):
   tarjetas con foto, fuente y título de GDELT/GNews; al tocar abren la nota
   **fuera de la app** (advertir antes de salir, como ya hace
   `ExternalLinkGuard` en la web).

**No migran al Inicio de la app:**
- `DevModeNotice` — solo modo demostración/desarrollo, no existe en producción.
- `CountryIntroModal` — se mantiene, pero como modal de primer lanzamiento
  (una vez), no como contenido permanente de la pantalla.

**Nota:** un primer mockup de esta planeación mostraba una lista de tarjetas
tipo "cerca de ti" (persona + punto de ayuda) que **no existe** en el Inicio
real — esa clase de tarjeta sí es el contenido real de `/se-busca` y `/ayuda`,
no de `/`. Un banner de SOS tampoco es contenido documentado del Inicio (SOS
ya es un tab primario); queda como decisión abierta, no como algo ya
confirmado en la web.
