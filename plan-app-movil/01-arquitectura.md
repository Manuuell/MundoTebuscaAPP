# 1. Arquitectura

## Decisión: Flutter habla directo con Supabase

**No construir una API intermedia.** `supabase_flutter` (SDK oficial Dart) da
paridad casi total con lo que ya usa la web — Auth, Postgres vía RLS,
Storage, Realtime — así que el móvil se conecta al **mismo proyecto
Supabase**, gobernado por las **mismas políticas RLS** (`supabase/schema.sql`
en el repo web) que ya son la única fuente de verdad de permisos. Evita
mantener reglas de negocio duplicadas en dos lenguajes.

Esto es coherente con el patrón que ya existe en el repo web
(`src/lib/data.ts:74-77`): la UI nunca habla con la base directo, siempre pasa
por una capa. En Flutter esa capa es un conjunto de *repositories* Dart que
replican las funciones de `data.ts` (sin la rama de memoria/demo, que no
aplica a producción móvil).

## Piezas web sin equivalente directo — y su reemplazo

| Pieza web | Ubicación (repo web) | Por qué no aplica igual en móvil | Reemplazo propuesto |
|---|---|---|---|
| Cloudflare Turnstile | `src/lib/turnstile.ts:7` (`verifyTurnstile`), sitekey en `:34` | Widget es web-only (challenges.cloudflare.com) | **App Attest** (iOS) + **Play Integrity API** (Android) — certifican que la llamada viene de la app real firmada, no de un script. Más fuerte que Turnstile para apps nativas |
| Validación zod en Server Actions | `src/app/actions.ts` (todas las mutaciones) | Duplicar los esquemas en Dart = mantenerlos 2 veces, se desincronizan con el tiempo | Validación de escritura movida a una **Supabase Edge Function** delgada (Deno) que web y Flutter llamen por igual para las mutaciones sensibles (crear persona, reportar estado). Constraints de Postgres como segunda capa de defensa, igual que hoy |
| `revalidatePath` tras cada mutación | por toda `actions.ts` | No existe fuera de Next | **Supabase Realtime** (subscribe a cambios) o refetch simple — de hecho mejora la UX: listas se actualizan sin acción del usuario |
| Leaflet (`CrisisMap.tsx`, `next/dynamic({ssr:false})`) | mapa de zonas/ayuda/hospitales/rescates | Web-only | `flutter_map` + mismos tiles (evita atarse a Google Maps y su facturación) |
| `localStorage` para deduplicar votos/likes por dispositivo | patrón en varios componentes de voto | No existe en móvil | UUID de dispositivo generado una vez, guardado en `shared_preferences` — mismo concepto, otro storage |
| `compressImage` (`src/lib/image.ts:14`) + `uploadPhoto` (`src/lib/upload.ts:15`) | subida de fotos | JS/Canvas-only | `flutter_image_compress` antes de subir directo a Supabase Storage con `supabase_flutter` |
| Enlaces de gestión con token (`verifyResourceOwner`, `src/lib/data.ts:1219`; `person_owners`) | `/persona/[id]/gestion?token=`, `/ayuda/[id]/gestion`, etc. | Deben abrir la app si está instalada, no solo el navegador | **App Links** (Android) / **Universal Links** (iOS) sobre el mismo dominio; si la app no está instalada, cae al sitio web actual sin romper nada |
| Rate limiting / bloqueo por IP (`src/lib/rateLimit.ts`, `src/lib/ipLockout.ts`) | login, formularios públicos | Pensado para peticiones HTTP con IP de servidor | Se mantiene igual si las mutaciones sensibles pasan por la Edge Function (ahí sí hay IP de servidor); si se escribe directo a Postgres desde el cliente, ese control se pierde — **razón adicional para la Edge Function en escrituras sensibles** |
| `/admin` (moderación) | `src/app/admin/` | Bajo uso, alta complejidad de UI | **Queda solo web.** No replicar en el MVP móvil |
| Supabase Auth (usuario/contraseña, correo sintético) | `src/lib/auth.ts:35-155` | — | Paridad casi total: `supabase_flutter` soporta `signInWithPassword`, sesión persistida de forma segura (Keychain/Keystore vía `flutter_secure_storage` internamente) |

## Nota de consistencia: no cachear estado como si fuera actual

La investigación de la web sobre PWA/offline (`03-pwa-offline.md` en el repo
web) **descartó explícitamente** cachear datos de personas/disponibilidad de
forma offline-first, porque servir un estado desactualizado sin avisar es
peligroso en una app de personas desaparecidas. La misma regla aplica al cache
offline de Flutter (Fase 4 del [roadmap](03-roadmap.md)): cualquier dato
mostrado sin conexión fresca necesita un aviso visible de "última
actualización hace X" — nunca presentarse como estado actual.
