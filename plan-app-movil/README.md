# Plan de implementación — app móvil (Flutter/Dart)

Carpeta pensada para copiarse tal cual al repositorio nuevo donde se va a
desarrollar la app móvil de **El Mundo Te Busca** (Android + iOS, Flutter/Dart).
Contenido producido en sesión de planeación — **no se construyó código
todavía**; es la arquitectura y el contenido acordados antes de empezar.

Fecha de la planeación: 2026-08-12/13.

## Cómo leer las referencias a archivos

Estos documentos citan archivos del repositorio **web** actual
(`venezuela-te-busca`, Next.js) como fuente de verdad del comportamiento que
hay que replicar o reemplazar — por ejemplo `src/lib/data.ts:74-77`. Esas
rutas **no existen en este repo nuevo**: son un puntero a dónde mirar en el
repo web si hace falta confirmar un detalle mientras se implementa. Mantener
ambos repos accesibles en paralelo durante el desarrollo.

## Índice

1. [Arquitectura](01-arquitectura.md) — decisión de backend (Flutter habla
   directo con Supabase, sin API intermedia) y tabla de piezas web sin
   equivalente directo en móvil, con su reemplazo propuesto.
2. [Contenido y navegación](02-contenido-y-navegacion.md) — qué secciones de
   la web migran, cuáles no y por qué; jerarquía de navegación heredada;
   contenido exacto de la pantalla Inicio.
3. [Roadmap por fases](03-roadmap.md) — 0 a 5, de cimientos a publicación.
4. [Tema visual](04-tema-visual.md) — paleta de colores y tipografías reales
   del sitio web, con un snippet de `ThemeData` de Flutter listo para pegar.

## Contexto de recursos (para no repetir la conversación)

Un compañero del equipo tiene Mac; por ahora la app se instala por depuración
(Xcode → dispositivo/simulador), **no se publica en App Store todavía** — no
aplican aún las reglas de revisión de Apple ni la cuenta Apple Developer de
pago ($99/año).

## Decisiones abiertas (sin resolver a propósito)

- ¿La Edge Function de validación de escrituras se escribe desde la Fase 2, o
  se empieza con RLS + constraints directo y se migra si aparece abuso?
- ¿`flutter_map` con los mismos tiles que usa `CrisisMap.tsx` en la web hoy, o
  revisar el proveedor de tiles de una vez?
- Nombre final, bundle ID / application ID, ícono de la app — nada de esto se
  decidió porque no hay publicación planeada todavía.
