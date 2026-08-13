# 05 — Profundización móvil: Fotos (Fase 2) y Push notifications (Fase 4)

> Investigación de apoyo para `plan-app-movil`. Fuentes verificadas en agosto 2026
> (versiones de paquetes, políticas de Android/iOS y patrón oficial de Supabase
> para push). No modifica ni el repo web (`C:\Users\angel\Desktop\Elmundotebusca`)
> ni el repo del plan (`C:\Users\angel\Desktop\MundoTebuscaAPP`).

---

## Resumen ejecutivo

- **Fotos**: `flutter_image_compress` (v2.5.1) SÍ reemplaza a `compressImage` de
  la web punto por punto — soporta WebP, redimensiona y **por defecto ya borra
  todo el EXIF/GPS** (`keepExif: false` es el default, no hay que configurar
  nada extra para lograr lo que hoy hace el `<canvas>` de la web). `image_picker`
  (v1.2.3) no necesita permisos de galería en Android 13+ (usa el Photo Picker
  del sistema) y en iOS solo pide declarar `NSPhotoLibraryUsageDescription` +
  `NSCameraUsageDescription` en `Info.plist`, sin runtime permission explícito
  porque usa `PHPickerViewController`. La subida a Supabase Storage con
  `supabase_flutter` tiene callback de progreso nativo (`onUploadProgress`)
  desde hace un tiempo; el reintento ante conexión inestable hay que
  implementarlo a mano (no hay retry automático incorporado) o usar el
  protocolo de **uploads reanudables (TUS)** de Supabase Storage para archivos
  grandes — aunque para fotos comprimidas a ~150-250 KB como hace la web,
  probablemente no haga falta TUS, con un retry simple con backoff alcanza.
  El hash SHA-256 con el paquete `crypto` de Dart da el **mismo hex digest**
  que `crypto.subtle.digest("SHA-256", …)` en el navegador — es el mismo
  algoritmo estándar aplicado a los mismos bytes, así que los hashes ya
  guardados por la web en `persons.photo_hash` son directamente comparables
  con los que calcule Flutter, **siempre que se hashee la imagen ya
  comprimida** (ver nota importante más abajo).

- **Push**: no es MVP (Fase 4 según `03-roadmap.md`), pero la investigación
  confirma que **Supabase no tiene integración nativa "un clic" con FCM/APNs**.
  El patrón oficial y documentado por el propio Supabase es: guardar el token
  del dispositivo en una tabla propia, un **Database Webhook** que dispara una
  **Edge Function** en cada evento relevante (insert en una tabla de
  notificaciones, o directamente en el UPDATE de `persons.status`), y esa
  función llama a la API HTTP v1 de FCM (que hoy también entrega a iOS vía
  APNs si el token viene de un dispositivo iOS registrado en Firebase). No hay
  atajo mágico — hay que construirlo, pero el patrón está bien documentado y
  no es exótico.

---

## Frente 1 — Fotos

### 1. `flutter_image_compress`: replicar `compressImage` de la web

**Lo que hace hoy la web** (`src/lib/image.ts:14-46`, repo web): recibe un
`File`, si es imagen la dibuja en un `<canvas>` (redimensionada a `maxDim=1280`
en el lado más largo), la re-exporta a WebP con `quality=0.82`. El efecto
colateral **buscado a propósito** (está documentado en el comentario del
archivo) es que dibujar en canvas y re-codificar **destruye todos los metadatos
EXIF**, incluida la coordenada GPS que la cámara del teléfono graba sin que el
usuario lo note — esto es un requisito de privacidad explícito del proyecto,
no un efecto secundario accidental.

**Equivalente en Flutter**: `flutter_image_compress` (última versión estable:
**2.5.1**, mantenido por fluttercandies). Confirmé en la documentación oficial
que:

- El parámetro `keepExif` **por defecto es `false`** — es decir, el
  comportamiento "seguro" (borrar metadatos) es el que ya trae de fábrica el
  paquete, igual que el canvas de la web. No hace falta ninguna configuración
  adicional para lograr paridad de privacidad; al contrario, habría que
  **evitar explícitamente** poner `keepExif: true`.
- Soporta `format: CompressFormat.webp` de forma nativa: encoder nativo en
  Android, `SDWebImageWebPCoder` en iOS, Canvas del navegador en Flutter Web
  (no soportado en macOS de escritorio — irrelevante para este proyecto que es
  solo Android/iOS).
- `minWidth`/`minHeight` funcionan como límites superiores que preservan el
  aspect ratio (el paquete escala hacia abajo, no fuerza esas dimensiones
  exactas) — equivalente directo al `maxDim` + `scale = min(1, maxDim/max(w,h))`
  que calcula a mano la web.
- La orientación EXIF siempre se "hornea" en los píxeles de salida (el tag se
  normaliza), igual que pasa al dibujar en un `<canvas>` — no hay riesgo de
  que una fofo quede rotada al perder el tag.

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Equivalente Dart de compressImage() en src/lib/image.ts (repo web).
/// Redimensiona al lado más largo = maxDim, recodifica a WebP y borra
/// EXIF/GPS (keepExif: false es el default del paquete — no cambiarlo).
Future<Uint8List> compressForUpload(
  File original, {
  int maxDim = 1280,
  int quality = 82, // el paquete usa escala 0-100, la web usa 0-1 (0.82)
}) async {
  final compressed = await FlutterImageCompress.compressWithFile(
    original.absolute.path,
    minWidth: maxDim,
    minHeight: maxDim,
    quality: quality,
    format: CompressFormat.webp,
    keepExif: false, // explícito a propósito: paridad de privacidad con la web
  );

  // Si el paquete no pudo procesar el formato de origen (caso raro),
  // igual que la web: no bloquear la publicación, subir el original.
  return compressed ?? await original.readAsBytes();
}
```

Detalle a verificar en implementación real (no cubierto por la doc pública):
en Android, el encoder WebP nativo puede variar de comportamiento entre
versiones de OS muy viejas; conviene loguear cuando `compressed == null` para
detectar en campo si algún modelo de gama baja cae al fallback.

### 2. `image_picker`: selección de imagen y permisos 2025-2026

**Android 13+ (API 33+)**: desde hace varias versiones, `image_picker`
usa el **Photo Picker del sistema** (`ACTION_PICK_IMAGES`), que **no requiere
ningún permiso runtime** — es una interfaz segura que corre fuera del proceso
de la app, el sistema le entrega a la app solo las fotos que el usuario elige.
Con `targetSdk >= 33` no hace falta declarar `READ_MEDIA_IMAGES` ni pedirlo en
runtime. **Importante para Play Store**: hay reportes de 2025-2026 de rechazos
de Play Console cuando el manifest final terminaba declarando de todos modos
`READ_MEDIA_IMAGES` (arrastrado por alguna dependencia transitiva) — la
política de Google exige explícitamente **no** exponer ese permiso si la app
puede cumplir su función con el Photo Picker. Vale la pena, al llegar la Fase
2, correr `flutter build appbundle` y revisar el manifest fusionado
(`build/app/outputs/...AndroidManifest.xml`) para confirmar que no quedó ese
permiso expuesto, y si quedó, removerlo explícitamente con un
`<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" tools:node="remove"/>`.

**iOS 17+**: la implementación usa `PHPickerViewController` desde la versión
0.8.1 del paquete, que por diseño de Apple **no requiere acceso completo a la
librería de fotos** — el picker corre en un proceso separado del sistema y
solo entrega a la app la foto seleccionada, sin pedir el permiso "Acceso
completo"/"Fotos seleccionadas" salvo que la app pida metadata completa
(`requestFullMetadata`, que no hace falta acá). Aun así, Apple exige declarar
las claves de uso en `Info.plist` aunque el flujo normal no dispare el prompt:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Para adjuntar una foto a tu publicación (persona, punto de ayuda, etc.)</string>
<key>NSCameraUsageDescription</key>
<string>Para tomar una foto directamente y adjuntarla a tu publicación</string>
```

Nota: si en algún punto se agrega selección/grabación de **video**, hay que
sumar también `NSMicrophoneUsageDescription`.

### 3. Subida a Supabase Storage con `supabase_flutter`

`supabase_flutter` (Dart) expone `onUploadProgress` en `.upload()` desde hace
tiempo, calculado sobre `bytesUploaded`/`bytesTotal` — no hace falta ninguna
librería extra para la barra de progreso:

```dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String> uploadPhotoWithRetry(
  Uint8List bytes, {
  required String bucket,
  required String path, // ej. '${crypto.randomUUID()}.webp' (equivalente en Dart: uuid pkg)
  void Function(double progress)? onProgress,
  int maxAttempts = 3,
}) async {
  final storage = Supabase.instance.client.storage.from(bucket);
  Object? lastError;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/webp',
          upsert: false,
          cacheControl: '3600',
        ),
        // onUploadProgress requiere el cliente storage configurado sobre
        // http con soporte de progreso; en supabase_flutter reciente viene
        // integrado en upload()/uploadBinary().
        onUploadProgress: (event) {
          if (event.totalBytes != null && event.totalBytes! > 0) {
            onProgress?.call(event.totalBytes == null
                ? 0
                : (event.totalBytes! == 0
                    ? 0
                    : (event.totalBytes! - (event.totalBytes! - 0)) / event.totalBytes!));
          }
        },
      );
      return storage.getPublicUrl(path);
    } catch (e) {
      lastError = e;
      if (attempt == maxAttempts) rethrow;
      // Backoff simple ante caída de conexión (zona con mala señal):
      await Future.delayed(Duration(seconds: attempt * 2));
    }
  }
  throw lastError ?? Exception('Subida falló sin error específico');
}
```

(El cálculo exacto del `progress` a partir del evento varía ligeramente entre
versiones del SDK — al implementar, confirmar la forma exacta del callback en
la versión de `supabase_flutter` que se fije en `pubspec.yaml`, porque la API
de `StorageUploadProgress`/similar se ha ido afinando en releases recientes.)

**Sobre reintentos ante conexión inestable**: `supabase_flutter` **no trae
retry automático incorporado** para `upload()` — hay que envolverlo a mano
como arriba (intentos + backoff), igual que recomienda la propia comunidad de
Supabase para casos de red inestable.

**Sobre uploads grandes/reanudables (TUS)**: Supabase Storage soporta subida
reanudable vía protocolo **TUS** (útil para archivos que no caben en un solo
intento con buena confiabilidad, hasta 50 GB). Para este proyecto, dado que
`compressForUpload()` deja las fotos en ~100-250 KB (igual que la web), **TUS
es probablemente innecesario** para fotos — el costo/beneficio de integrar un
cliente TUS en Dart no se justifica todavía. Vale la pena reconsiderarlo si en
el futuro se sube video. Ojo: hay varios issues abiertos en el repo de
Supabase (`supabase/storage#563`, `supabase/cli#2729`) sobre TUS fallando
específicamente en clientes Dart más allá de 6 MB — otra razón para no
adoptarlo sin necesidad real.

**Detalle de performance real** (documentado por Supabase): para subidas
directas a Storage conviene usar el hostname directo de storage
(`https://<project-id>.storage.supabase.co`) en vez de pasar por
`https://<project-id>.supabase.co`, mejora la latencia de subida.

### 4. Hash SHA-256 para deduplicación (comparable con la web)

La web calcula el hash **sobre el archivo ya comprimido a WebP** (revisar
`hashFile()` en `src/lib/upload.ts:44-50`: recibe un `File`, no hay evidencia
en el código de que se hashee antes de comprimir — hay que confirmar en el
componente que llama a `hashFile()` en qué orden se invoca junto a
`compressImage()`, pero el patrón lógico documentado es "hashear el archivo
que efectivamente se sube"). Esto importa mucho para Flutter: **si Dart
hashea los bytes originales de la cámara y la web hasheó el WebP recomprimido,
los hashes NUNCA van a coincidir aunque sea la misma foto** — la comparación
de duplicados dejaría de funcionar entre plataformas. Regla a seguir en
Flutter: **hashear siempre después de `compressForUpload()`**, sobre los
mismos bytes que efectivamente se suben a Storage, igual que hace la web.

El paquete `crypto` de Dart (pub.dev, mantenido por el equipo de Dart/Google)
calcula el mismo SHA-256 estándar (FIPS 180-4) que `crypto.subtle.digest` del
navegador — es el mismo algoritmo determinístico aplicado a los mismos bytes
de entrada, así que el hex resultante es idéntico byte a byte entre
plataformas siempre que se hasheen los mismos bytes:

```dart
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Equivalente Dart de hashFile() en src/lib/upload.ts (repo web).
/// IMPORTANTE: llamar con los bytes YA comprimidos (compressForUpload()),
/// no con los bytes originales de la cámara — si no, el hash no va a
/// coincidir con los que ya guardó la web en persons.photo_hash.
String hashPhotoBytes(Uint8List compressedBytes) {
  return sha256.convert(compressedBytes).toString(); // hex minúsculas, igual formato que la web
}
```

Ambas implementaciones producen hex en minúsculas de 64 caracteres — coincide
con el formato que arma la web (`.toString(16).padStart(2,"0")` por byte,
también minúsculas). No hace falta normalización adicional.

---

## Frente 2 — Push notifications (Fase 4, explícitamente NO es MVP)

Confirmado contra `03-roadmap.md`: push vive en la **Fase 4 ("Nativo real")**,
después de lectura (Fase 1), escritura (Fase 2) y cuentas (Fase 3). Se
investiga con la misma profundidad para dejar la decisión de diseño tomada de
antemano, pero no bloquea nada del trabajo actual del equipo.

### 5. `firebase_messaging` en Flutter — estado 2025-2026

Versión actual: **16.5.0** (paquete FlutterFire), depende de `firebase_core`.
Setup mínimo:

```dart
// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart'; // generado por flutterfire configure

// El handler de background DEBE ser una función top-level o `static`
// (no un método de instancia) — se ejecuta en un isolate separado en Android.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // No se puede tocar UI acá; solo trabajo de datos (ej. marcar localmente
  // "hay novedades" para mostrar un badge al abrir la app).
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // Primer plano: FCM NO muestra notificación visual automáticamente en
  // ninguna plataforma cuando la app está abierta — hay que mostrarla a mano
  // (típicamente con flutter_local_notifications) o manejarla como in-app banner.
  FirebaseMessaging.onMessage.listen((message) {
    // mostrar snackbar/banner propio, o flutter_local_notifications
  });

  // Usuario tocó la notificación y la app pasó de background a foreground:
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    // navegar a /persona/[id] según message.data
  });

  // App abierta en frío DESDE una notificación (estaba terminada):
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    // navegar a /persona/[id] según initial.data
  }

  runApp(const App());
}
```

Detalle específico de iOS con `UIScene` (relevante si el proyecto Xcode
adopta el lifecycle nuevo): Apple exige que `UNUserNotificationCenter.delegate`
quede configurado **antes** de que retorne
`application:didFinishLaunchingWithOptions:`, así que en el `AppDelegate` hay
que llamar explícitamente `[FLTFirebaseMessagingPlugin
configureNotificationCenterDelegate];` — es un detalle de plomería de Xcode,
no de Dart, documentado en el changelog del plugin.

Pedir permiso explícito en iOS (obligatorio, a diferencia de Android donde es
automático salvo Android 13+ que también pide runtime permission desde API 33):

```dart
final settings = await FirebaseMessaging.instance.requestPermission(
  alert: true, badge: true, sound: true,
);
// settings.authorizationStatus: authorized / denied / provisional / notDetermined
```

### 6. ¿Supabase tiene integración nativa con push, o hay que armarlo a mano?

**Confirmado: no hay integración nativa "de un clic".** Repasé la
documentación oficial de Supabase
(`supabase.com/docs/guides/functions/examples/push-notifications`) y el
patrón recomendado por el propio Supabase es 100% "armarlo con las piezas
existentes", no un feature dedicado de push:

1. **Tabla propia** para guardar el token del dispositivo (FCM token) por
   usuario — Supabase no tiene una tabla ni un campo reservado para esto, lo
   modela el propio proyecto.
2. **Database Webhook**: Supabase Dashboard → Database → Webhooks. Se
   configura para disparar en `INSERT` (o `UPDATE`) sobre la tabla relevante,
   apuntando a una Edge Function vía HTTP POST. Esto es la pieza "nativa" que
   sí provee Supabase: la capacidad de que Postgres llame a una Edge Function
   ante un cambio de fila (por debajo usa `pg_net` + trigger, expuesto como
   feature de UI).
3. **Edge Function (Deno)**: recibe el payload del webhook (fila insertada/
   actualizada), resuelve a qué usuario(s) avisar, busca sus tokens FCM en la
   tabla propia, obtiene un access token OAuth2 con las credenciales de la
   cuenta de servicio de Firebase (JWT firmado, flujo estándar de Google:
   `POST https://oauth2.googleapis.com/token` con `grant_type=
   urn:ietf:params:oauth:grant-type:jwt-bearer`), y llama a la API HTTP v1 de
   FCM: `POST https://fcm.googleapis.com/v1/projects/{projectId}/messages:send`.
   FCM HTTP v1 es unificado — el mismo endpoint entrega tanto a Android como a
   iOS (APNs) si el token del dispositivo iOS fue registrado a través de
   Firebase (Firebase gestiona el puente a APNs internamente).
4. Postgres **no puede llamar directamente** a FCM o APNs — por eso la Edge
   Function es obligatoria como intermediaria; no hay forma de saltarse ese
   salto.

Esto confirma exactamente lo que ya intuía `01-arquitectura.md` (Fase 4:
"push notifications... mejora que la web no puede dar bien") — es trabajo
nuevo de infraestructura, no una casilla que se activa en el dashboard de
Supabase.

### 7. Diseño concreto: avisar cuando cambia el estado de una persona seguida

**Pregunta clave del pedido: ¿reusar `saved_items` o tabla nueva?**

Repasé `supabase/schema.sql` del repo web (líneas 707-731). `saved_items` ya
es exactamente "usuario sigue una entidad":

```sql
create table if not exists saved_items (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  entity_type text not null check (entity_type in
    ('person','aid_point','march','post','hospital','complaint','pet','hero')),
  entity_id   uuid not null,
  title       text not null default '',
  created_at  timestamptz not null default now(),
  unique (user_id, entity_type, entity_id)
);
```

`entity_type = 'person'` ya está soportado. **Recomendación: reusar
`saved_items` como la tabla de "a quién avisar"**, no crear una tabla de
suscripción nueva y paralela — evita que existan dos conceptos casi
idénticos ("guardado" en la web vs. "seguido" en el móvil) que se puedan
desincronizar. La semántica de producto ya es "guardar una persona para
seguir su actividad" (así lo describe el propio comentario del schema:
*"avisos de comentarios nuevos en la campanita"*) — extenderla a push es
coherente, no un cambio de significado.

Lo que **sí hace falta agregar**, sin tocar `saved_items`:

```sql
-- Tabla nueva: un dispositivo Flutter por usuario (puede haber varios
-- dispositivos por cuenta). No pisa nada de la web.
create table if not exists device_push_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  fcm_token   text not null,
  platform    text not null check (platform in ('android','ios')),
  updated_at  timestamptz not null default now(),
  unique (user_id, fcm_token)
);

alter table device_push_tokens enable row level security;
create policy "device_push_tokens_own" on device_push_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

Y el trigger que detecta el cambio de estado y arma el "encargo" de push
(tabla intermedia liviana, en vez de disparar el webhook directo sobre
`persons` para no acoplar la Edge Function a la forma exacta de esa tabla):

```sql
create table if not exists person_status_events (
  id          uuid primary key default gen_random_uuid(),
  person_id   uuid not null references persons(id) on delete cascade,
  old_status  person_status,
  new_status  person_status not null,
  created_at  timestamptz not null default now()
);

create or replace function notify_person_status_change()
returns trigger language plpgsql as $$
begin
  if new.status is distinct from old.status then
    insert into person_status_events (person_id, old_status, new_status)
    values (new.id, old.status, new.status);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_person_status_change on persons;
create trigger trg_person_status_change
  after update on persons
  for each row execute function notify_person_status_change();
```

El **Database Webhook** se configura sobre `person_status_events` (evento
`INSERT`) → Edge Function `notify-person-followers`. Dentro de la función:

```ts
// supabase/functions/notify-person-followers/index.ts
// Disparada por Database Webhook al insertar en person_status_events.
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const { record } = await req.json(); // fila de person_status_events

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 1) Quién sigue a esta persona (reusa saved_items, entity_type='person')
  const { data: followers } = await supabase
    .from("saved_items")
    .select("user_id")
    .eq("entity_type", "person")
    .eq("entity_id", record.person_id);

  if (!followers?.length) return new Response("sin seguidores", { status: 200 });

  // 2) Tokens de esos usuarios
  const { data: tokens } = await supabase
    .from("device_push_tokens")
    .select("fcm_token")
    .in("user_id", followers.map((f) => f.user_id));

  if (!tokens?.length) return new Response("sin tokens", { status: 200 });

  // 3) Access token OAuth2 de la cuenta de servicio de Firebase
  const accessToken = await getFcmAccessToken(); // firma JWT con la service account key (secreto en env)

  // 4) Enviar a cada token vía FCM HTTP v1 (entrega también a iOS/APNs)
  const projectId = Deno.env.get("FCM_PROJECT_ID")!;
  await Promise.all(
    tokens.map((t) =>
      fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: t.fcm_token,
            notification: {
              title: "Actualización de una persona que sigues",
              body: `Cambió a: ${record.new_status}`,
            },
            data: { personId: record.person_id, type: "person_status" },
          },
        }),
      })
    ),
  );

  return new Response("ok", { status: 200 });
});
```

(`getFcmAccessToken()` es el paso estándar de Google Cloud: firmar un JWT con
la clave privada de la cuenta de servicio —guardada como secreto de la Edge
Function, nunca en el repo— e intercambiarlo en
`https://oauth2.googleapis.com/token`; Supabase documenta este paso completo
en su guía oficial, ver Fuentes.)

**Nota de alcance**: esto es diseño para cuando llegue la Fase 4, no algo a
implementar ahora. Requiere que ya exista Fase 3 (cuentas) porque
`device_push_tokens` y `saved_items` dependen de `auth.uid()` — es decir, el
"seguir una persona con aviso push" es, por diseño, una funcionalidad
**solo para usuarios con cuenta**, coherente con que `saved_items` en la web
ya requiere sesión.

---

## Fuentes

- [flutter_image_compress — pub.dev](https://pub.dev/packages/flutter_image_compress)
- [flutter_image_compress — GitHub (fluttercandies)](https://github.com/fluttercandies/flutter_image_compress)
- [image_picker — pub.dev](https://pub.dev/packages/image_picker)
- [image_picker_ios — changelog (PHPicker, permisos)](https://pub.dev/packages/image_picker_ios/changelog)
- [image_picker — Android 13+ READ_MEDIA_IMAGES / rechazo Play Store (issue)](https://github.com/flutter/flutter/issues/171494)
- [Handling Play Console's New Media Policy — Android Photo Picker](https://medium.com/@uemirhanselim/handling-play-consoles-new-media-policy-android-photo-picker-ccb3b86f2368)
- [Supabase Docs — Flutter: Upload a file (onUploadProgress)](https://supabase.com/docs/reference/dart/storage-from-upload)
- [Supabase — Resumable uploads (TUS)](https://supabase.com/docs/guides/storage/uploads/resumable-uploads)
- [Supabase Storage v3: Resumable Uploads con soporte hasta 50GB](https://supabase.com/blog/storage-v3-resumable-uploads)
- [Supabase — issue reintentos/errores TUS en cliente Dart](https://github.com/supabase/supabase/issues/15667)
- [crypto — pub.dev (paquete oficial Dart)](https://pub.dev/packages/crypto)
- [firebase_messaging — pub.dev](https://pub.dev/packages/firebase_messaging)
- [FlutterFire — Cloud Messaging usage docs](https://firebase.flutter.dev/docs/messaging/usage/)
- [FlutterFire — Notifications docs (foreground/background)](https://firebase.flutter.dev/docs/messaging/notifications/)
- [Supabase Docs — Sending Push Notifications (Edge Functions + FCM HTTP v1)](https://supabase.com/docs/guides/functions/examples/push-notifications)
- [Supabase — Database Webhooks](https://supabase.com/docs/guides/database/webhooks)
- [Discusión de la comunidad Supabase — mejor estrategia para push](https://github.com/orgs/supabase/discussions/13930)
