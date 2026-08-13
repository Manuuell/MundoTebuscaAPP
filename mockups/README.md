# Mockups

Maquetas estáticas en HTML (abrir directo en el navegador, sin servidor).
Usan la paleta y tipografías reales del sitio web — ver
[04-tema-visual.md](../04-tema-visual.md) — cargadas por CDN (Google Fonts +
Tabler Icons), así que necesitan conexión a internet para verse con las
fuentes/íconos correctos; sin internet igual se lee el contenido con las
fuentes de reserva del sistema.

Son punto de partida visual, **no diseño final aprobado**.

Todas las pantallas usan la **tab bar flotante estilo iOS 26 ("Liquid
Glass")** descrita en
[investigacion-tecnica/09-diseno-ios.md](../investigacion-tecnica/09-diseno-ios.md)
§1 — cápsula con blur sobre el contenido, no pegada al borde inferior como
`MobileNav.tsx` en la web. Es una mejora nueva para la app, no una réplica 1:1.

**Decisión del equipo (2026-08-13)**: el quinto tab es **Ajustes**, no SOS
— ver [02-contenido-y-navegacion.md](../02-contenido-y-navegacion.md).
Emergencias/SOS se movió a la hoja "Más" (junto con Ayuda y Mascotas), sigue
accesible pero ya no es tab primario.

- [inicio.html](inicio.html) — pantalla Inicio + tab bar flotante de 5 tabs,
  1:1 con el contenido descrito en
  [02-contenido-y-navegacion.md](../02-contenido-y-navegacion.md): hero con
  2 CTAs, panel "Juntos somos más fuertes" (4 cifras con ícono, según
  `HomeHero.tsx`), bloque de cifra del sismo separado (fallecidos, heridos,
  desaparecidos, afectados, cada uno con fuente y fecha, según
  `CrisisStatsPanel`), fila completa de 8 cifras deslizables (según
  `DashboardStats.tsx`, mismos tonos de color: rose/amber/emerald/sky/zinc/
  violet), y carrusel de noticias verificadas con varias tarjetas.
- [se-busca.html](se-busca.html) — pantalla "Se busca" con las dos vistas que
  describe [05-fuente-web-existente.md](../05-fuente-web-existente.md) §4:
  **Lista** (búsqueda, chips de filtro por estado con los mismos colores que
  `EstadoPersona` en el código Flutter, tarjetas con badge "👁️ Sin
  identificar" y "Menor") y **"¿La reconoces?"** (baraja tipo Tinder,
  equivalente a `RecognizeDeck.tsx`): tarjetas apiladas, botones ✕/✓,
  sellos "OTRA"/"LA RECONOZCO" al decidir, atajos de teclado (flechas
  izquierda/derecha), contador y estado vacío con reinicio. Tiene JS mínimo
  para poder probar el swipe/deck interactivamente, no solo verlo estático.
- [ajustes.html](ajustes.html) — pantalla "Ajustes" (perfil y cuenta),
  quinto tab desde la decisión de arriba. Equivalente a `/perfil` +
  `/configuracion` en la web: tarjeta de perfil con enlace a "Ver perfil
  público", atajos a "Mis publicaciones" y "Guardados", sección Cuenta
  (cambiar contraseña, correo de recuperación, avisos por correo con toggle
  interactivo), botón "Cerrar sesión" y "Eliminar cuenta" con la aclaración
  de que no borra publicaciones, solo las desvincula.
