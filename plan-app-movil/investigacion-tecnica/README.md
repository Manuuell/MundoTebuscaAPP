# Investigación técnica de apoyo (2026-08-13)

11 investigaciones profundas (web + verificación contra el código real de
`Elmundotebusca` y de este repo), hechas para llenar los huecos técnicos que
`01-05` (el plan original) dejó identificados pero sin resolver. No repiten
decisiones ya tomadas ahí (arquitectura, multi-país, roadmap, tema visual
base) — las dan por buenas y construyen encima.

Cada documento tiene su propia sección de Fuentes con URLs. Enlazados desde
[`../06-correcciones-y-reparto.md`](../06-correcciones-y-reparto.md) según a
quién le toca cada parte.

| Doc | Tema | Para quién (ver reparto) |
|---|---|---|
| [01-escritura-segura.md](01-escritura-segura.md) | Diseño completo de la Edge Function delgada (RLS de escritura se queda cerrado), verificación server-side de App Attest/Play Integrity, auth Flutter→Edge Function, rate limiting sin memoria compartida | **Angel** — bloquea la Fase 2 de Manuu y jerdiaz |
| [02-deep-linking.md](02-deep-linking.md) | `assetlinks.json`/`apple-app-site-association` (van en el repo **web**, no aquí), configuración de `go_router`, fallback de custom scheme para probar hoy sin certificado/Team ID | **Angel** |
| [03-mapa-flutter.md](03-mapa-flutter.md) | Setup real de `flutter_map` con tiles de CartoDB, marcadores animados, clustering, capas togglables — **ojo: CARTO puede requerir licencia para uso comercial, vale pedir su programa de donación ONG** | **jerdiaz** |
| [04-estado-offline.md](04-estado-offline.md) | Riverpod + repositories (MVP), y cache offline con Drift para Fase 4 (NO es MVP) | **Todos** (patrón Riverpod) / **Angel** más adelante (offline) |
| [05-fotos-push.md](05-fotos-push.md) | `flutter_image_compress` (ya borra EXIF/GPS por defecto), hash de foto compatible con `photo_hash` de la web, subida a Storage; push notifications (Fase 4, no MVP) | **Manuu** (fotos en Comunidad/Personas) y **jerdiaz** (fotos en Ayuda/Mascotas) |
| [06-visual-accesibilidad.md](06-visual-accesibilidad.md) | Traducción a Flutter de la curva iOS, `.tap-card`, bottom sheets, `Hero`, `Semantics`, contraste (`brand600` falla AA como texto, usar `brand700`) | **Todos** |
| [07-testing-distribucion.md](07-testing-distribucion.md) | Cómo demostrar la app HOY sin tienda (Android: APK directo o Firebase App Distribution, gratis; **iOS: TestFlight SÍ exige cuenta Apple de pago, sin atajo**), CI mínimo, test de humo | **Angel** / todo el equipo para la demo de hoy |
| [08-multi-pais.md](08-multi-pais.md) | Config centralizada de país en Dart (equivalente a `countries.ts`), por qué usar SVG y no emoji de bandera, persistencia sin auto-detección de locale (igual que la web) | **Manuu** (ya tocó `pais_provider.dart`) |
| [09-diseno-ios.md](09-diseno-ios.md) | Tab bar flotante estilo iOS 26/Liquid Glass (mejora nueva: la web no flota), sistema de elevación en 3 niveles, `MTCard` con borde sutil, animaciones (`.animate-rise`/`.stagger`/`.hint-swipe`/`.press`), guía rápida offline empaquetada como asset | **Todos** (tab bar y `MTElevation`/`MTCard` son compartidos; guía rápida es de **Manuu**, junto con Comunidad) |
| [10-alerta-sismo-checkin.md](10-alerta-sismo-checkin.md) | Interruptor en Ajustes que, si detecta (server-side, vía USGS) que hubo un sismo cerca, pregunta "¿estás bien?" por push y comparte ubicación con voluntarios/rescatistas si no responde o dice que no — **no es HelpSearch** (ese es BLE offline, esto es Supabase+push), documento aclara el límite explícito | **Angel** (backend/push/Edge Function) |
| [11-actualizacion-de-datos.md](11-actualizacion-de-datos.md) | Respuesta a la pregunta de Manuu: de dónde salen y cada cuánto se refrescan noticias (GDELT/GNews, caché 6h, cron horario), sismos (USGS, caché 30 min, aún no conectado en Flutter) y mensajes de Comunidad (posts directos = instantáneo; redes sociales = cron cada 15 min, nace `pending`) | Informativo — **todos** |
| [12-revision-2026-08-13.md](12-revision-2026-08-13.md) | Auditoría del estado real por pantalla, hallazgo sobre por qué "¿La reconoces?" sale vacía (dato, no bug), revisión de fluidez/arquitectura/seguridad y próximos pasos explícitos por persona | Informativo — **todos** |
| [13-refinamiento-ios-fase2-y-sos.md](13-refinamiento-ios-fase2-y-sos.md) | Buscador/filtros/paginado compactos (`MTSearchBar`, referencia en Se busca), asistente como burbuja flotante, motor de guía interactiva tipo spotlight y SOS de punta a punta (sondeo, pantalla "¿Estás bien?", rol `volunteer`) — con instrucciones directas de qué falta aplicar en cada sección | **Manuu** (Comunidad/perfil) y **jerdiaz** (Ayuda/Hospitales/Mascotas/Mapa) |
