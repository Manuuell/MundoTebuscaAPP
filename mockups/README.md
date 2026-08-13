# Mockups

Maquetas estáticas en HTML (abrir directo en el navegador, sin servidor).
Usan la paleta y tipografías reales del sitio web — ver
[04-tema-visual.md](../04-tema-visual.md) — cargadas por CDN (Google Fonts +
Tabler Icons), así que necesitan conexión a internet para verse con las
fuentes/íconos correctos; sin internet igual se lee el contenido con las
fuentes de reserva del sistema.

Son punto de partida visual, **no diseño final aprobado**.

- [inicio.html](inicio.html) — pantalla Inicio + barra inferior de 5 tabs,
  1:1 con el contenido descrito en
  [02-contenido-y-navegacion.md](../02-contenido-y-navegacion.md): hero con
  2 CTAs, panel "Juntos somos más fuertes" (4 cifras con ícono, según
  `HomeHero.tsx`), bloque de cifra del sismo separado (fallecidos, heridos,
  desaparecidos, afectados, cada uno con fuente y fecha, según
  `CrisisStatsPanel`), fila completa de 8 cifras deslizables (según
  `DashboardStats.tsx`, mismos tonos de color: rose/amber/emerald/sky/zinc/
  violet), y carrusel de noticias verificadas con varias tarjetas.
