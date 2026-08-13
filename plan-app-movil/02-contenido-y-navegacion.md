# 2. Contenido y navegación

## Qué no conviene tener como sección propia en la app — y por qué

| Ruta web | Por qué no |
|---|---|
| `/admin` | Uso de escritorio, poco frecuente, alta complejidad de UI (tablas, acciones en lote). Ya funciona bien en web para quien modera; replicarlo en móvil es esfuerzo alto para valor bajo |
| `/recursos` | Ya es un `redirect()` a `/emergencias` en la propia web (`src/app/recursos/page.tsx:6-8`) — no hay contenido real que portar |
| `/noticias` | Ya es un `redirect()` a `/ayuda` (`src/app/noticias/page.tsx:7-9`) — su contenido se repartió entre `/ayuda` (ReliefWeb, héroes, sismos) y `/comunidad` (historias destacadas) |
| `/mantenimiento` | No es contenido, es un estado global de la app cuando el backend está caído. En Flutter es una pantalla de estado a nivel de app, no un ítem de navegación |
| `/cuenta/confirmar`, `/cuenta/restablecer` | Son destinos de un enlace de correo (recuperar contraseña), no secciones que alguien visite por su cuenta. El equivalente móvil es una pantalla de "restablecer contraseña" propia, alcanzada por Universal Link/App Link desde el correo — se construye, pero no va en el menú |

## Decisión del equipo (2026-08-13): Ajustes reemplaza a SOS en la barra principal

El equipo decidió que la app **no** hereda 1:1 los 5 tabs de `MobileNav.tsx`
— cambia SOS por **Ajustes** (perfil y cuenta) como quinto tab primario.
Justificación de producto: cuenta/perfil es algo que se consulta con más
frecuencia que emergencias, y Emergencias sigue accesible a un toque extra
desde "Más", no desaparece.

- **Emergencias/SOS se muda a la hoja "Más"**, junto con Ayuda y Mascotas —
  ver tabla actualizada abajo.
- **Ajustes deja de ser "Fase 3 pospuesta"** y pasa a ser navegación
  primaria desde el día uno: `/perfil`, `/configuracion`,
  `/perfil/publico/[username]` (antes descritos aquí como pospuestos a
  Fase 3 del [roadmap](03-roadmap.md) — la construcción real de login/cuenta
  puede seguir llegando por fases, pero el **tab** ya existe desde el MVP de
  navegación, no hay que esperar a Fase 3 para que aparezca en la barra).

## Todo lo demás: hereda la jerarquía de la web, con el cambio de arriba

Hallazgo clave: `MobileNav.tsx` (la barra inferior que ya usa la PWA en
pantallas chicas, en el repo web) **ya resolvió la jerarquía base** — no hay
que inventarla de nuevo, solo aplicarle el cambio ya decidido:

- **5 tabs primarios** (base: `MobileNav.tsx:33-39`, con el swap ya
  decidido): Inicio (`/`), Se busca (`/se-busca`), Comunidad (`/comunidad`),
  Mapa (`/mapa`), **Ajustes** (`/perfil` + `/configuracion` — antes SOS en la
  web).
- **Hoja "Más"** (base: `MobileNav.tsx:41-44`, con Emergencias agregada):
  Ayuda y hospitales, Mascotas, **Emergencias/SOS** (`/emergencias`).
- **Comunidad agrupa** voluntarios, caravanas y denuncias
  (`MobileNav.tsx:30`, `COMMUNITY_PATHS`) — no son tabs propios, son
  subsecciones dentro de Comunidad.
- **Ayuda agrupa** hospitales (`MobileNav.tsx:31`, `AYUDA_PATHS`).

Recomendación: Flutter hereda el resto de la jerarquía tal cual (mismo
agrupamiento de Comunidad/Ayuda, misma hoja "Más"), solo con el tab 5
cambiado. Quien ya usa la PWA reconoce casi todo salvo ese swap deliberado.

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
