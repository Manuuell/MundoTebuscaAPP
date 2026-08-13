# 10. "¿Estás bien?" — check-in automático y compartir ubicación tras un sismo

> **Estado (2026-08-13):** implementado el MVP del §7.1 salvo el cron de
> USGS. En el repo web: tablas `safety_optins`/`safety_checkins` en
> `supabase/schema.sql` (sin política pública, service role únicamente) y la
> Edge Function `supabase/functions/safety-optin` (`activate`, `deactivate`,
> `update-location`, `respond`, y `test-alert` para poder probar el flujo
> completo sin esperar un sismo real). En este repo: interruptor "Red de
> auxilio" en `configuracion_screen.dart` (permiso + ubicación +
> consentimiento visible), `SafetyRepository` (`lib/repositories/safety_repository.dart`)
> y actualización oportunista de ubicación al abrir/reanudar la app
> (`app.dart`). **Falta desplegar** la función (`supabase functions deploy
> safety-optin`) y aplicar el SQL nuevo contra el proyecto real antes de que
> el interruptor funcione de punta a punta. Pendiente de una sesión aparte:
> el cron de USGS que detecta sismos y dispara el push real (§3-§5) — hoy el
> único disparador es `test-alert`, manual.

Idea de Angel: un interruptor en **Ajustes** (activo/inactivo, con permisos y
persistencia) para que, si la app detecta que la persona estuvo cerca de un
sismo real, le pregunte si está bien — y si no responde, o responde que no,
comparta su ubicación con voluntarios/rescatistas de la app. Objetivo: que le
llegue a cualquiera con la app instalada, sin que tenga que hacer nada activo
en el momento del sismo.

## 0. Esto NO es HelpSearch — no confundir los dos proyectos

[`Angelsistemas7/HelpSearch`](https://github.com/Angelsistemas7/HelpSearch) es
un **repo aparte**, una app **React Native independiente**: un faro SOS por
**Bluetooth mesh 100% offline** (sin internet, sin servidor, salta de celular
en celular). Cubre el momento en que no hay señal en absoluto.

Lo que describe este documento es distinto y vive **dentro de esta app**
(Flutter, este repo): usa **internet + Supabase + push notifications**, no
Bluetooth. Es un check-in automático de "¿estás bien?" que solo funciona si
hay señal (aunque sea intermitente, ya que solo necesita un instante de datos
para mandar la ubicación). Son **complementarios, no el mismo mecanismo** —
igual que `09-diseno-ios.md` avisó que la tab bar flotante era mejora nueva y
no algo ya existente, esto queda marcado igual de explícito para que nadie
intente fusionar el módulo BLE de HelpSearch con esto.

Si algún día se linkean entre sí (ej. "si no hay señal para el check-in,
sugerir instalar HelpSearch"), es una decisión de producto aparte — no un
requisito de este documento.

## 1. Flujo completo

```
Usuario activa el interruptor en Ajustes
        │
        ▼
Pide permisos (ubicación + notificaciones) ── si los niega, el interruptor
        │                                       vuelve solo a "inactivo"
        ▼
App registra: opt-in = true, push_token, última ubicación conocida
        │
        │   (nada más pasa hasta que el backend detecte un sismo cerca)
        ▼
Cron del backend detecta sismo nuevo relevante (USGS, ver §3)
        │
        ▼
Busca usuarios opt-in cuya última ubicación cae dentro del radio del sismo
        │
        ▼
Push: "Hubo un sismo cerca de ti. ¿Estás bien?"  [Sí, estoy bien] [Necesito ayuda]
        │
        ├── Toca "Sí, estoy bien" ──────────────► marca check-in OK, NO comparte ubicación
        │
        ├── Toca "Necesito ayuda" ──────────────► comparte ubicación YA, visible a
        │                                          voluntarios/rescatistas cercanos
        │
        └── No responde en la ventana (ej. 20 min) ► comparte ubicación igual
                                                       (silencio en emergencia = señal,
                                                       no se asume que está bien)
```

La regla "si no dice que sí, se comparte" es intencional y va en el propio
mensaje de consentimiento al activar el interruptor (§5) — la persona tiene
que saber esto ANTES de activarlo, no enterarse cuando ya pasó.

## 2. Qué significa "el interruptor" en código — reusa lo que ya existe

`configuracion_screen.dart` ya es la pantalla correcta (reemplazó a SOS en la
tab bar, ver `adcd3e9`). El interruptor va ahí, como una sección nueva
("Red de auxilio" o similar), con:

- Un `Switch` que dispara el flujo de permisos (no un simple booleano local:
  hasta que los permisos estén concedidos Y el registro en servidor confirme,
  se queda desactivado).
- Texto de consentimiento explícito, visible siempre que esté activo (no solo
  la primera vez): qué se comparte, con quién, y bajo qué condición.
- Poder desactivarlo en cualquier momento — deshace el opt-in en servidor de
  inmediato (`DELETE`/`update` sobre la fila de consentimiento), no solo local.

Persistencia local (el propio interruptor, para no volver a pedir permisos
cada vez que se abre la app) va con lo que ya usa el repo para banderas
simples: `shared_preferences`, mismo patrón que `UltimaVisita` en
`novedades_repository.dart:116-131`. Persistencia real (que el backend sepa
que este usuario está opt-in) va en Supabase — ver §4.

## 3. Detección: "¿estuvo cerca de un sismo?" — server-side, no on-device

**No hay que perseguir un sismo con GPS en tiempo real desde el celular.**
Eso implicaría un servicio en foreground de ubicación corriendo todo el
tiempo (el mismo problema de batería/confiabilidad que `HelpSearch` resuelve
con un Foreground Service dedicado en Kotlin para BLE — no vale la pena
duplicar esa complejidad para esto). El enfoque correcto es más simple:

1. **El celular manda su última ubicación conocida al servidor de forma
   oportunista** — no en background continuo. Momentos naturales para
   actualizarla:
   - Al activar el interruptor (obligatorio, primera vez).
   - Cada vez que la app se abre en foreground (barato: una lectura de
     `Geolocator.getLastKnownPosition()` o `getCurrentPosition()` con
     precisión media, no GPS de alta precisión).
   - Opcional, para Fase 2 de esta función: `Geolocator` tiene un modo de
     **"cambios significativos de ubicación"** (`LocationSettings` con
     `distanceFilter` grande, ej. 500m-1km) que en iOS usa el *Significant-
     Change Location Service* de Apple (bajísimo consumo, sancionado por
     Apple para background) y en Android el `FusedLocationProviderClient`
     con intervalo largo — mucho más barato que tracking continuo, y
     suficiente porque el radio de un sismo relevante es de kilómetros, no
     de metros.
2. **El servidor decide si hay sismo cerca, no el cliente.** Un cron (mismo
   patrón que `warm-news`, ver `11-actualizacion-de-datos.md` §1-2) pega a la
   **API pública de USGS** (`usgs.ts` ya hace exactamente esto para la web)
   cada 5-10 minutos buscando sismos **nuevos** (no vistos en la corrida
   anterior) con magnitud relevante (sugerido: ≥ 5.0 — un umbral menor genera
   ruido de notificaciones para sismos que casi nadie siente).
3. Para cada sismo nuevo relevante, calcula un **radio de alerta** a partir de
   la magnitud (heurística simple tipo "radio sentido" — hay fórmulas
   públicas de USGS/ShakeMap para esto, no hace falta inventar una propia;
   como aproximación gruesa de arranque, algo como `radio_km = 50 * (mag - 4)`
   con un piso de 20 km sirve para el MVP y se puede afinar después con datos
   reales de "sintieron el sismo" que USGS también expone en su API
   `dyfi` — *Did You Feel It*).
4. Busca en la tabla de opt-in (§4) quiénes tienen su última ubicación dentro
   de ese radio y manda el push (§5).

Esto reutiliza directamente el trabajo de `11-actualizacion-de-datos.md` §2
(USGS ya identificado como la fuente correcta) — es el mismo fetch, con un
paso extra de "¿hay alguien opt-in en el radio?".

## 4. Esquema (van en el repo **web**, `supabase/schema.sql`, igual que
deep linking — es la fuente de verdad compartida)

Dos tablas nuevas, ninguna reutiliza `persons` (esto es sobre usuarios de la
app, no sobre personas reportadas):

```sql
-- Quién optó por el check-in, y su última ubicación conocida.
create table if not exists safety_optins (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,           -- mismo UUID de dispositivo que ya usa
                                      -- core/util (device_id), no requiere cuenta
  user_id uuid references auth.users(id),  -- null si es anónimo, igual que posts
  push_token text,                   -- FCM/APNs token
  last_lat double precision,
  last_lng double precision,
  last_location_at timestamptz,
  country text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (device_id)
);

-- Un check-in disparado por un sismo concreto.
create table if not exists safety_checkins (
  id uuid primary key default gen_random_uuid(),
  optin_id uuid not null references safety_optins(id) on delete cascade,
  quake_id text not null,            -- id de USGS, evita duplicar por el mismo sismo
  status text not null default 'pending'
    check (status in ('pending', 'ok', 'needs_help', 'no_response')),
  lat double precision,              -- snapshot de la ubicación EN ESE MOMENTO,
  lng double precision,              -- no la que tenga hoy — para que un rescatista
                                      -- vea dónde estaba, no dónde está ahora
  notified_at timestamptz not null default now(),
  responded_at timestamptz,
  resolved_at timestamptz,           -- cuando ya no es visible (ver retención, §6)
  unique (optin_id, quake_id)
);
```

RLS: **nada de esto es de lectura pública.** `safety_optins` no se lee nunca
desde el cliente directo (solo la Edge Function, con `service_role`, puede
escribir/leer ubicación exacta). `safety_checkins` con `status IN
('needs_help', 'no_response')` es lo único que puede exponerse a un rol
`volunteer`/`rescuer` verificado — reutilizando la tabla `app_roles` que **ya
existe** en `schema.sql:206` (mismo patrón de roles que usa `/admin` hoy,
verificar campos exactos ahí antes de escribir la política).

## 5. Notificación y consentimiento

- **Push:** FCM (Android) / APNs (iOS). El plan ya identificó que push es
  "Fase 4, no MVP" en `05-fotos-push.md` y en `06-correcciones-y-reparto.md`
  — **esta función es la excepción justificada** a esa regla: sin push no
  hay forma de preguntar "¿estás bien?" cuando la persona no tiene la app
  abierta. Se puede adelantar SOLO la pieza de push necesaria para esto
  (registro de token + un tipo de notificación con dos botones de acción)
  sin adelantar el resto de Fase 4 (notificaciones de comunidad, etc.).
- **Texto de consentimiento al activar el interruptor** (obligatorio, no
  opcional, mostrarlo aunque sea repetitivo): algo como *"Si hay un sismo
  cerca de ti, te preguntaremos si estás bien. Si no respondes o dices que
  necesitas ayuda, tu ubicación se compartirá con voluntarios y rescatistas
  de la app cerca de ti. Puedes desactivarlo cuando quieras."* — sin este
  texto, compartir la ubicación por defecto (silencio = comparte) sería
  sorpresivo y rompería la confianza que la app necesita en un desastre real.
- **Ventana de respuesta** antes de considerar "no_response": sugerido 15-20
  minutos — bastante para que alguien reaccione a una notificación, no tanto
  como para que la ubicación pierda sentido si de verdad hace falta ayuda.

## 6. Privacidad — puntos que no se pueden pasar por alto

- **Opt-in explícito, nunca activado por defecto.** Coincide con el
  principio de privacidad que ya identificó la revisión de GPT sobre
  `persons` (no todo dato debe ser público por defecto) — aquí aplica igual
  o más fuerte, porque es la ubicación en vivo de una persona real, no un
  registro histórico.
- **Solo la ubicación al momento del sismo se comparte**, no tracking
  continuo ni historial — de ahí el snapshot `lat`/`lng` en `safety_checkins`
  en vez de apuntar siempre a `last_lat`/`last_lng` de `safety_optins` (que
  sigue cambiando).
- **Expiración obligatoria.** Un `safety_checkin` visible a rescatistas debe
  dejar de serlo pasado un tiempo razonable (ej. 48-72h) — se marca
  `resolved_at` por cron o manualmente cuando un rescatista/voluntario
  confirma contacto. No debe quedar un mapa histórico permanente de
  ubicaciones de gente.
- **Quién puede ver esto** no es "cualquiera con la app" — es el rol
  `volunteer`/`rescuer` de `app_roles`, mismo modelo que ya protege `/admin`.
  Mostrarlo en el mapa general (capa nueva, coordinar con jerdiaz si se hace)
  solo como pin aproximado, nunca con nombre/foto de la persona salvo que
  ella lo haya puesto ahí explícitamente (ej. si ya tiene un registro propio
  en `persons`).
- **Rate limiting y abuso**: mismo mecanismo atómico que ya diseñó Angel en
  `01-escritura-segura.md` para el resto de escrituras — nada de esto pasa
  por fuera de la Edge Function ni abre RLS de insert/update público nuevo.

## 7. Fases sugeridas (no es todo de una vez)

1. **MVP mínimo demostrable**: interruptor + permisos + registrar
   `last_lat/last_lng` en cada apertura de la app (sin background real
   todavía) + cron USGS que detecta sismo relevante + push simple "¿Estás
   bien?" con los dos botones + tabla `safety_checkins`. Ya es una demo
   completa del concepto sin necesitar background location.
2. **Ubicación oportunista mejor**: cambios significativos de ubicación
   (`Geolocator`, §3.1) en vez de solo "al abrir la app", para cubrir a
   alguien que no abre la app justo cuando pasa el sismo.
3. **Capa en el mapa** para voluntarios/rescatistas (coordinar con
   `03-mapa-flutter.md`, capas ya son conmutables).
4. **Radio de alerta más preciso** con datos reales de USGS `dyfi` en vez de
   la heurística simple del MVP.

## Fuentes

- USGS Earthquake API (`earthquake.usgs.gov/fdsnws/event/1/`) — ya en uso en
  `src/lib/usgs.ts` del repo web, sin clave, documentada oficialmente por
  USGS.
- USGS "Did You Feel It?" (`dyfi`) — datos reales de radio sentido por
  magnitud, para afinar §3 más adelante.
- `geolocator` (paquete Flutter) — soporta `getCurrentPosition`,
  `getLastKnownPosition` y un modo de precisión/distancia configurable que
  mapea a Significant-Change Location Service (iOS) y `FusedLocationProviderClient`
  (Android) sin necesitar un Foreground Service dedicado.
- Repo `HelpSearch` (`Angelsistemas7/HelpSearch`) — confirmar el límite claro
  con este documento (§0) cada vez que alguien lo mencione en el equipo.
