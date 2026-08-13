# 02 — Deep linking: App Links (Android) + Universal Links (iOS) para los enlaces de gestión

> Investigación técnica. No se tocó código de `Elmundotebusca` ni de
> `MundoTebuscaAPP\plan-app-movil` — este documento vive solo en el scratchpad.
> Fecha: 2026-08-13.

## 0. Resumen ejecutivo (TL;DR)

- Los archivos `.well-known/assetlinks.json` (Android) y
  `.well-known/apple-app-site-association` (iOS) **van en el repo web
  (`Elmundotebusca`, Next.js)**, no en el repo Flutter. El repo Flutter solo
  necesita saber el dominio (`elmundotebusca.com`) y sus propios
  Bundle ID/Package name + certificado de firma.
- Ambos archivos se sirven mejor con un **Route Handler de Next.js**
  (`route.ts`), no como archivo estático en `public/`, para controlar el
  `Content-Type` explícitamente — crítico sobre todo para
  `apple-app-site-association`, que no tiene extensión.
- **Bloqueadores reales hoy**: no existe todavía (a) el certificado de firma
  Android (ni siquiera el de debug del compañero que está armando el repo
  Flutter) ni (b) el Team ID de Apple / Bundle ID definitivo (el propio
  `README.md` del plan móvil dice explícitamente que el bundle ID "no se
  decidió"). Sin esos dos datos **no se pueden generar los archivos reales**
  — ver §5.
- Mientras tanto, `go_router` puede probarse ya con un **custom scheme
  `elmundotebusca://`** (sin verificación de dominio, funciona hoy mismo en
  local) y migrar a App Links/Universal Links en cuanto existan certificado y
  Team ID.
- Si la app no está instalada o la verificación del dominio falla, el
  sistema operativo cae al navegador automáticamente — no hay nada que
  romper del lado web, es el comportamiento por defecto de ambos
  mecanismos ("mejor esfuerzo").

---

## 1. Por qué esto no es trivial: "mejor esfuerzo", no garantía

Tanto **Android App Links** como **iOS Universal Links** son en esencia lo
mismo con nombres distintos: un enlace `https://elmundotebusca.com/...`
normal que, si el sistema operativo pudo **verificar criptográficamente**
que el dueño del dominio autoriza a una app concreta a manejar esas URLs,
abre la app en vez del navegador. Si la verificación no se hizo (o falla, o
la app no está instalada), el enlace **sigue siendo un enlace HTTPS normal**
y abre el navegador — exactamente el comportamiento actual de
`elmundotebusca.com/persona/[id]/gestion?token=...`. Por diseño no hay forma
de "romper" la web con esto: en el peor caso, App Links/Universal Links
simplemente no se activan y todo sigue como hoy.

La verificación funciona así en ambos sistemas:

1. El sistema operativo, al instalar la app (o en background), pide al
   **servidor web** (no a una tienda de apps) un archivo JSON en una ruta
   fija bajo `/.well-known/`.
2. Ese JSON declara "el package/bundle ID `X`, firmado con el certificado
   `Y`, tiene permiso para manejar enlaces de este dominio".
3. El sistema compara eso contra el certificado real con el que está firmada
   la app instalada. Si coincide, marca el dominio como verificado para esa
   app.

Por eso el archivo **tiene que vivir en el servidor web** (repo
`Elmundotebusca`) — es una declaración que hace el dueño del dominio, no
algo que la app pueda declarar por sí sola (eso sería trivial de falsificar).

---

## 2. Android App Links

### 2.1 `assetlinks.json` — contenido

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.elmundotebusca.app",
      "sha256_cert_fingerprints": [
        "14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"
      ]
    }
  }
]
```

- `package_name`: el `applicationId` de Android (aún **no decidido** — ver
  §5). Usa un valor de ejemplo hasta que el equipo lo confirme.
- `sha256_cert_fingerprints`: array — puede (y conviene) tener **varias
  entradas a la vez**: el certificado de **debug** (para probar mientras se
  desarrolla) y el de **release** (para producción). No hace falta elegir
  uno solo.
- El array raíz puede tener más de un objeto `statement` si en el futuro hay
  más de una app (ej. una app separada para admin) — no es el caso ahora.

### 2.2 Cómo se obtiene el fingerprint SHA-256

**Durante desarrollo (keystore de debug), Mac/Linux/Windows:**

```bash
keytool -list -v \
  -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
```

En Windows la ruta es `%USERPROFILE%\.android\debug.keystore`. La
contraseña del keystore de debug es siempre `android` (generado
automáticamente por el SDK de Android la primera vez que se compila). El
`SHA256:` sale en la salida de `keytool`, con el formato de 32 bytes en hex
separados por `:`.

**Para el keystore de release (antes de publicar):**

```bash
keytool -list -v -keystore ruta/al/release.jks -alias tu-alias
```

**Punto crítico que casi siempre se pasa por alto — Play App Signing.**
Si la app se sube a Google Play con "Play App Signing" activado (es el
comportamiento **por defecto** desde 2021 para apps nuevas), Google
**re-firma** el APK/AAB con su propia clave antes de distribuirlo. El
certificado que termina en el teléfono del usuario final **no es** el de tu
`release.jks` local, sino el de Google. Eso significa:

- El fingerprint que hay que poner en `assetlinks.json` para producción
  real (apps instaladas desde Play Store) es el que aparece en
  **Play Console → tu app → Configuración → Integridad de la app →
  Certificado de firma de la app** (App signing key certificate), NO el de
  tu keystore de subida (upload key).
- Es buena práctica incluir **ambos** en el array (upload key + app signing
  key), así los debug/side-load y las instalaciones desde Play Store
  verifican igual.
- Esto **no aplica todavía** al equipo (según `plan-app-movil/README.md`,
  "no se publica en App Store/Play Store todavía", se instala por
  depuración) — pero vale documentarlo ahora para no repetir la
  investigación cuando llegue el momento de publicar.

### 2.3 Cómo servirlo desde Next.js (repo web)

Dos formas posibles; **la recomendada es Route Handler**, no archivo
estático, para controlar el `Content-Type` con certeza (ver §2.4 sobre por
qué esto importa en este despliegue concreto).

**Opción A (recomendada) — Route Handler:**

`src/app/.well-known/assetlinks.json/route.ts`

```ts
import { NextResponse } from "next/server";

// Declara qué apps Android pueden abrir enlaces https://elmundotebusca.com/...
// como App Links en vez de en el navegador. Ver docs/... (pendiente) o
// scratchpad de investigación 02-deep-linking.md para contexto completo.
export async function GET() {
  return NextResponse.json(
    [
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: {
          namespace: "android_app",
          package_name: "com.elmundotebusca.app", // TODO: confirmar applicationId real
          sha256_cert_fingerprints: [
            // TODO: reemplazar por los fingerprints reales (debug + release/Play App Signing)
          ],
        },
      },
    ],
    { headers: { "Content-Type": "application/json" } }
  );
}
```

Nota de convención de Next.js App Router: la carpeta `.well-known` bajo
`src/app/` es válida como segmento de ruta normal (el punto inicial no
tiene tratamiento especial), y el nombre de archivo `assetlinks.json` como
carpeta contenedora de `route.ts` hace que la URL final sea exactamente
`/.well-known/assetlinks.json`.

**Opción B — archivo estático en `public/`:**

`public/.well-known/assetlinks.json` con el JSON tal cual. Next.js sirve
`public/` bajo la raíz automáticamente. Como el archivo **sí tiene**
extensión `.json`, el Content-Type se infiere correctamente en la mayoría de
los casos. Es más simple, pero menos explícito/controlable que el Route
Handler.

### 2.4 Detalle específico de este despliegue (VPS + PM2 + nginx)

`Elmundotebusca` no está en Vercel: el `deploy.yml` construye
`next build` con `output: "standalone"`, copia `public/` dentro de
`.next/standalone/public`, y **el propio servidor Node de Next** (vía PM2)
sirve esos estáticos — nginx está delante como reverse proxy, pero no
sirve archivos directo del filesystem (no hay `location /.well-known {
root ...}` en el `nginx.conf`, no hay ese config en este repo). Eso es
bueno: significa que el `Content-Type` para `.json` en `public/` sale del
`mime-lookup` interno de Next/Node, que sí mapea `.json` →
`application/json` de forma confiable. **Para `assetlinks.json` (con
extensión) la Opción B (estático) funcionaría bien en este despliegue.**
Para `apple-app-site-association` (sin extensión) es más arriesgado — ver
§3.3. Por consistencia y para no depender de detalles de infraestructura,
la recomendación general sigue siendo el Route Handler para ambos.

### 2.5 AndroidManifest.xml — intent-filter

Dentro de la `<activity>` principal (la que lanza Flutter, normalmente
`.MainActivity`):

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    ...>

    <!-- Lanzador normal -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>

    <!-- App Links: enlaces https://elmundotebusca.com/... abren la app -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="https" android:host="elmundotebusca.com"/>
    </intent-filter>

    <!-- Fallback temporal sin verificación de dominio (ver §5) -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="elmundotebusca"/>
    </intent-filter>
</activity>
```

`android:autoVerify="true"` es lo que dispara la verificación automática de
`assetlinks.json` contra el dominio declarado en `<data android:host=...>`.
Sin ese atributo, el intent-filter funciona pero Android trata el enlace
como "deep link" ambiguo (puede mostrar el selector de apps) en vez de App
Link verificado (abre directo).

### 2.6 Verificar que quedó bien configurado

- **Comando ADB** (con la app instalada, API 31+):
  `adb shell pm get-app-links com.elmundotebusca.app` — muestra el estado de
  verificación por dominio (`verified`, `legacy_failure`, etc.).
- **Herramienta de Google** para validar el JSON antes de desplegar:
  Statement List Generator/Tester de Digital Asset Links
  (`https://developers.google.com/digital-asset-links/tools/generator`).
- Requisito no negociable: Android **no sigue redirecciones** al pedir
  `/.well-known/assetlinks.json` — debe responder 200 directo en esa ruta
  exacta, sin pasar por `www.` → `elmundotebusca.com` ni HTTP → HTTPS.
  Confirmar que no hay una regla de redirect en nginx/Next que intercepte
  específicamente esta ruta.

---

## 3. iOS Universal Links

### 3.1 `apple-app-site-association` — contenido (formato moderno 2025-2026)

Apple soporta dos formatos: el clásico `appID` (singular) + `paths`, y el
moderno (desde iOS 13) `appIDs` (array) + `components`, que permite reglas
de exclusión, fragmentos, y comentarios legibles. Para un proyecto nuevo,
usar el formato moderno:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["ABCDE12345.com.elmundotebusca.app"],
        "components": [
          {
            "/": "/persona/*/gestion",
            "comment": "Gestión de una persona por token — abre la ficha de gestión en la app"
          },
          {
            "/": "/ayuda/*/gestion",
            "comment": "Gestión de un punto de ayuda por token"
          },
          {
            "/": "/caravanas/*/gestion",
            "comment": "Gestión de una caravana por token"
          },
          {
            "/": "/persona/*",
            "comment": "Ficha de persona (lectura) — también útil para compartir por WhatsApp"
          }
        ]
      }
    ]
  }
}
```

- `ABCDE12345` es el **Team ID** de Apple (10 caracteres alfanuméricos,
  visible en developer.apple.com → Account → Membership, o en Xcode →
  Signing & Capabilities). `com.elmundotebusca.app` es el **Bundle ID**
  (aún no decidido — mismo blocker que el package name de Android, ver §5).
- Los patrones con `*` en `components` matchean cualquier segmento — cubre
  el `[id]` dinámico de `/persona/[id]/gestion` sin listar cada persona.
- El query string (`?token=...`) **no necesita** regla aparte: Universal
  Links matchea sobre el path, no sobre la query string; el token llega
  intacto a la app vía la URL completa que se le pasa al handler.

### 3.2 Sobre la firma del archivo (JWS) — aclaración

El enunciado de la tarea planteaba la duda de si Apple exige firmar el
archivo. **No encontré evidencia de que la firma (JWS) sea requisito para
Universal Links estándar** en 2025-2026: sigue siendo JSON plano servido
por HTTPS. La confusión probable viene de un mecanismo **distinto** (Shared
Web Credentials / autocompletado de contraseñas y passkeys entre Safari y
apps), que sí puede involucrar validaciones adicionales pero no aplica a
"abrir la app al tocar un enlace". Para este caso (deep linking de enlaces
de gestión), JSON plano sin firmar es suficiente. Si en el futuro se agrega
Shared Web Credentials (autocompletar login de la web en la app), conviene
reinvestigar ese mecanismo aparte.

### 3.3 Requisitos de hosting — más estrictos que Android

- **Sin extensión** en el nombre de archivo: la URL final es
  `https://elmundotebusca.com/.well-known/apple-app-site-association`
  (sin `.json`).
- **Content-Type: `application/json`** explícito. Justo por no tener
  extensión, muchos servidores (incluido el `mime-lookup` de Node cuando no
  reconoce la extensión) caen a `application/octet-stream` o no fijan
  ningún `Content-Type`. **Este es el motivo principal para usar Route
  Handler en vez de archivo estático para este archivo en particular** —
  con `public/.well-known/apple-app-site-association` sin extensión, el
  comportamiento del servidor de estáticos de Next no está garantizado.
- **Tamaño máximo 128 KB.**
- **Sin redirecciones** — igual que Android, tiene que responder 200 en esa
  ruta exacta.
- Debe ser accesible **sin autenticación** y servido en el dominio raíz
  (`elmundotebusca.com`, no un subdominio distinto, salvo que se declare
  ese subdominio específico en Associated Domains).

**Route Handler recomendado** —
`src/app/.well-known/apple-app-site-association/route.ts`:

```ts
import { NextResponse } from "next/server";

// Sin extensión a propósito: Apple pide exactamente esta ruta.
// Content-Type explícito porque el archivo no tiene .json y muchos
// servidores (incluido el nuestro) no lo infieren solos.
export async function GET() {
  return NextResponse.json(
    {
      applinks: {
        details: [
          {
            appIDs: ["ABCDE12345.com.elmundotebusca.app"], // TODO: Team ID + Bundle ID reales
            components: [
              { "/": "/persona/*/gestion" },
              { "/": "/ayuda/*/gestion" },
              { "/": "/caravanas/*/gestion" },
              { "/": "/persona/*" },
            ],
          },
        ],
      },
    },
    { headers: { "Content-Type": "application/json" } }
  );
}
```

En Next.js App Router, un archivo llamado literalmente
`apple-app-site-association` (sin extensión) funciona como nombre de
carpeta contenedora de `route.ts` sin problema — el router de Next no exige
extensión en los segmentos de ruta.

### 3.4 Info.plist / entitlements — Associated Domains

En Xcode: target de la app → **Signing & Capabilities** → **+ Capability**
→ **Associated Domains**. Esto genera/edita el archivo `.entitlements`:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:elmundotebusca.com</string>
</array>
```

El prefijo `applinks:` es obligatorio (a diferencia de Android, que solo
usa el host). Si en algún momento se sirve también desde `www.`, hay que
añadir una segunda entrada `applinks:www.elmundotebusca.com`.

Además, para el fallback de custom scheme (ver §5), en `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>elmundotebusca</string>
    </array>
    <key>CFBundleURLName</key>
    <string>com.elmundotebusca.app</string>
  </dict>
</array>
```

### 3.5 Verificar

- Apple **cachea agresivamente** el AASA vía su propia CDN (`swcdn`) al
  instalar la app o cuando el dispositivo lo revalida en background — los
  cambios al archivo pueden tardar en reflejarse en dispositivos reales;
  para pruebas rápidas, reinstalar la app fuerza una relectura.
- Prueba directa en simulador (no depende de la CDN de Apple, útil durante
  desarrollo):
  `xcrun simctl openurl booted https://elmundotebusca.com/persona/123/gestion?token=abc`

---

## 4. Configuración del lado Flutter (`go_router`)

### 4.1 Rutas — mapeo directo de los paths web actuales

`go_router` no necesita "traducir" las URLs de la web a otro esquema: puede
usar **los mismos paths** (`/persona/:id/gestion`, `/ayuda/:id/gestion`,
`/caravanas/:id/gestion`), y tanto un `Uri` recibido por deep link como una
navegación interna dentro de la app pasan por el mismo `GoRoute`.

```dart
final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const InicioScreen(),
    ),
    GoRoute(
      path: '/persona/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PersonaScreen(id: id);
      },
      routes: [
        GoRoute(
          // Ruta completa efectiva: /persona/:id/gestion
          path: 'gestion',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final token = state.uri.queryParameters['token'];
            if (token == null) {
              // Igual que la web: sin token no hay gestión — mostrar error,
              // no la pantalla de gestión.
              return const EnlaceInvalidoScreen();
            }
            return PersonaGestionScreen(id: id, token: token);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/ayuda/:id/gestion',
      builder: (context, state) => AyudaGestionScreen(
        id: state.pathParameters['id']!,
        token: state.uri.queryParameters['token'],
      ),
    ),
    GoRoute(
      path: '/caravanas/:id/gestion',
      builder: (context, state) => CaravanaGestionScreen(
        id: state.pathParameters['id']!,
        token: state.uri.queryParameters['token'],
      ),
    ),
    // ... resto de rutas de solo lectura (se-busca, mapa, ayuda, etc.)
  ],
);
```

`state.uri.queryParameters['token']` es la forma correcta de leer
`?token=...` — el token no forma parte del patrón de la ruta, así que no se
declara en el `path`, se lee del query string igual que hace hoy
`ManageLinkBox.tsx` en la web al construirlo
(`${origin}${basePath}/${id}/gestion?token=${token}`).

Conectar el router a la app:

```dart
MaterialApp.router(
  routerConfig: goRouter,
  // ...
)
```

### 4.2 AndroidManifest.xml — completo (repo Flutter)

Ver snippet completo en §2.5. Va en
`android/app/src/main/AndroidManifest.xml`, dentro de la actividad
principal generada por `flutter create`.

### 4.3 Info.plist / entitlements iOS — completo (repo Flutter)

Ver snippets en §3.4. El archivo `.entitlements` normalmente se llama
`Runner.entitlements` dentro de `ios/Runner/`, y Xcode lo enlaza solo al
usar la UI de "Signing & Capabilities" (más confiable que editarlo a mano,
porque Xcode también actualiza el `.pbxproj` para referenciarlo).

### 4.4 Nota sobre esquemas personalizados y `go_router`

Un detalle real encontrado en la investigación: la clase `Uri` de Dart
expone `origin` (usado internamente por algunas utilidades de parsing) solo
para esquemas `http`/`https` — con un scheme custom como
`elmundotebusca://` puede lanzar si algo del código intenta leer
`uri.origin`. En la práctica esto rara vez es un problema con `go_router`
directo (usa `path` y `queryParameters`, no `origin`), pero si se agrega
lógica propia que inspeccione `state.uri`, conviene probarla explícitamente
con ambos tipos de URI (custom scheme y https) antes de asumir que se
comportan igual.

---

## 5. Caso "no está instalada" — confirmación

Este comportamiento **no hay que construirlo**: es la definición misma de
App Links / Universal Links, ambos catalogados oficialmente por
Google/Apple como mecanismos de "mejor esfuerzo" (best effort):

- **Android**: si la verificación de `assetlinks.json` nunca se completó
  (app no instalada, o instalada pero sin verificar, o el dominio nunca
  pasó la verificación), el intent-filter con `autoVerify` simplemente no
  se activa como App Link — Android trata la URL como un enlace HTTPS
  normal y la abre en el navegador por defecto. No hace falta código de
  respaldo del lado Android.
- **iOS**: idéntico — si la app no está instalada, o Associated Domains no
  se verificó, o el path no matchea ningún `components`, Safari (o
  cualquier app que abra el link, ej. WhatsApp) simplemente carga la URL
  como página web normal.
- **La web actual no cambia en nada.** `/persona/[id]/gestion?token=...`
  sigue funcionando exactamente igual que hoy para cualquiera que reciba el
  enlace y no tenga la app — que es, además, la mayoría de los casos
  mientras la app esté en fase de pruebas con instalación manual (no hay
  publicación en tiendas todavía, según `plan-app-movil/README.md`).

Cómo confirmarlo en pruebas manuales sin necesidad de tener ya la app
firmada/verificada: desinstalar la app del dispositivo/simulador de prueba
y tocar el mismo enlace desde WhatsApp o Notas — debe abrir el navegador
con la web actual, sin ningún cambio de comportamiento.

---

## 6. Bono — ¿el equipo ya tiene certificado Android / Team ID de Apple?

**No lo puedo confirmar** (no tengo acceso a las cuentas de Google
Play/Apple Developer del equipo). Lo que sí puedo confirmar leyendo los
documentos del plan:

- `plan-app-movil/README.md` dice explícitamente, en "Decisiones abiertas":
  > "Nombre final, bundle ID / application ID, ícono de la app — nada de
  > esto se decidió porque no hay publicación planeada todavía."

  Esto es un **blocker directo** para generar los archivos `.well-known/*`
  reales: sin `package_name`/Bundle ID definitivos, cualquier archivo que
  se publique hoy tendría que reemplazarse después (no es grave — son
  archivos de texto sin costo de "migración" — pero sí significa que no
  vale la pena escribirlos como definitivos todavía).
- El **certificado de firma Android** (aunque sea el de debug, que se
  genera automáticamente en la primera compilación) tampoco se mencionó
  como ya obtenido en ningún documento del plan — probablemente porque
  **todavía no existe el repo Flutter ni se ha compilado nada** (el
  `README.md` dice "no se construyó código todavía").
- El **Team ID de Apple** requiere una cuenta de Apple Developer activa. El
  plan aclara que por ahora la app se instala por depuración desde Xcode
  (un Mac del equipo) sin cuenta de pago — una cuenta **gratuita** de Apple
  Developer alcanza para obtener un Team ID y compilar/probar en
  dispositivo propio, no hace falta la cuenta de $99/año todavía (esa
  cuenta paga es necesaria más adelante solo para *publicar* en App Store,
  fase 5 del roadmap).

### Qué hacer mientras tanto (hoy, sin esperar esos datos)

Usar el **custom scheme `elmundotebusca://`** como deep link de prueba,
sin verificación de dominio:

- No requiere `assetlinks.json` ni `apple-app-site-association` — Android e
  iOS confían en el scheme declarado localmente en el manifest/plist (ver
  intent-filter de fallback en §2.5 y `CFBundleURLTypes` en §3.4).
- Permite probar **hoy mismo** que `go_router` recibe y rutea correctamente
  un enlace tipo `elmundotebusca://persona/123/gestion?token=abc` a la
  pantalla `PersonaGestionScreen`, sin bloquear el trabajo de Fase 0/2 del
  roadmap por la falta de certificado/Team ID.
- **Limitación real (no solo teórica)**: un custom scheme puede ser
  registrado por *cualquier* app instalada — no hay garantía de que
  `elmundotebusca://` lo abra específicamente la app oficial si hay otra
  app en el dispositivo que declaró el mismo scheme. Aceptable para
  desarrollo/pruebas internas; **no es sustituto de producción** de App
  Links/Universal Links, que si están verificados por dominio no tienen
  ese problema (el dominio es único).
- En la práctica de WhatsApp (canal real por el que hoy se comparten los
  enlaces de gestión, según `ManageLinkBox.tsx`): WhatsApp no
  reconoce/abre custom schemes al tocarlos dentro del chat, solo URLs
  `http(s)`. Esto significa que el custom scheme sirve para **probar el
  ruteo interno de `go_router`** (vía `adb shell am start` /
  `xcrun simctl openurl` con el scheme custom, o un link de prueba fuera de
  WhatsApp), pero **no reemplaza** el flujo real de "recibo el enlace por
  WhatsApp y se abre la app": ese flujo específico sí necesita App
  Links/Universal Links funcionando de verdad, es decir, sí necesita
  esperar al certificado/Team ID reales antes de poder probarse
  end-to-end.

Comandos de prueba del custom scheme:

```bash
# Android
adb shell am start -a android.intent.action.VIEW \
  -d "elmundotebusca://persona/123/gestion?token=abc" \
  com.elmundotebusca.app

# iOS (simulador)
xcrun simctl openurl booted "elmundotebusca://persona/123/gestion?token=abc"
```

---

## 7. Quién tiene que tocar qué repo

| Qué | Repo | Ruta exacta |
|---|---|---|
| `assetlinks.json` (Android) | **`Elmundotebusca` (web, Next.js)** | `src/app/.well-known/assetlinks.json/route.ts` (recomendado) o `public/.well-known/assetlinks.json` |
| `apple-app-site-association` (iOS) | **`Elmundotebusca` (web, Next.js)** | `src/app/.well-known/apple-app-site-association/route.ts` |
| `AndroidManifest.xml` (intent-filters) | **Repo Flutter nuevo** | `android/app/src/main/AndroidManifest.xml` |
| `Runner.entitlements` / Associated Domains | **Repo Flutter nuevo** | `ios/Runner/Runner.entitlements` (vía Xcode, no a mano) |
| `Info.plist` (custom scheme fallback) | **Repo Flutter nuevo** | `ios/Runner/Info.plist` |
| Configuración de `go_router` (rutas, parseo de `:id` y `token`) | **Repo Flutter nuevo** | donde se defina el `GoRouter` (ej. `lib/router/app_router.dart`) |

**Punto que vale la pena remarcar al equipo**: es fácil perder tiempo
buscando `assetlinks.json` o `apple-app-site-association` dentro del repo
Flutter (por instinto, "es cosa de la app") — pero por definición del
mecanismo, ambos archivos son una declaración que hace el **dueño del
dominio**, así que **solo pueden vivir en el servidor que responde por
`elmundotebusca.com`**, es decir, en `Elmundotebusca`. Quien tenga acceso
de escritura a ese repo (y al despliegue del VPS) es quien puede publicarlos
— no es una tarea que el desarrollador Flutter pueda completar solo.

---

## 8. Checklist de próximos pasos (en orden de dependencia)

1. Decidir `applicationId` Android y Bundle ID iOS definitivos (bloquea
   todo lo demás de forma real, no solo cosmética).
2. Compañero con Mac: crear cuenta Apple Developer (gratis alcanza para
   desarrollo) → anotar Team ID.
3. Generar keystore de debug (automático al compilar) → sacar SHA-256 con
   `keytool` (§2.2).
4. Con esos 4 datos (package name, Team ID, Bundle ID, SHA-256 debug),
   completar los `TODO` de los dos Route Handlers de §2.3 y §3.3 y
   desplegarlos en `Elmundotebusca`.
5. Añadir intent-filter (§2.5) y Associated Domains (§3.4) en el repo
   Flutter.
6. Verificar con `adb shell pm get-app-links` (Android) y
   `xcrun simctl openurl` (iOS simulador).
7. Mientras 1-6 no estén listos: usar el fallback de custom scheme (§6)
   para no bloquear el desarrollo de las pantallas de gestión en sí.
8. Cuando exista keystore de **release** (más adelante, cerca de Fase 5):
   repetir §2.2 con Play App Signing y añadir ese fingerprint también.

---

## Fuentes

- [Getting Started | Google Digital Asset Links](https://developers.google.com/digital-asset-links/v1/getting-started)
- [Configure website associations and dynamic rules | Android Developers](https://developer.android.com/training/app-links/configure-assetlinks)
- [Add Intent filters for App Links | Android Developers](https://developer.android.com/training/app-links/add-applinks)
- [Digital Asset Links: Setup and Verification Guide - Tolinku](https://tolinku.com/blog/digital-asset-links-setup/)
- [How to Generate and Validate assetlinks.json (2026) - Tolinku](https://tolinku.com/blog/assetlinks-json-generator/)
- [Use Play App Signing - Play Console Help](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en)
- [Android App Links autoVerify Failed — debug checklist | WarpLink](https://warplink.app/blog/android-app-links-autoverify-failed)
- [iOS Universal Links - Expo Documentation](https://docs.expo.dev/linking/ios-universal-links/)
- [apple-app-site-association — with examples (gist)](https://gist.github.com/mat/e35393e9dfd9d7fb0972)
- [Apple App Site Association File: Complete Setup Guide - Tolinku](https://tolinku.com/blog/aasa-file-setup/)
- [Apple App Site Association Not Working — debug checklist | WarpLink](https://warplink.app/blog/apple-app-site-association-not-working)
- [Fixing AASA File Problems — Branch.io](https://www.branch.io/resources/blog/fixing-aasa-file-problems-a-developers-guide-to-common-errors/)
- [App Search Programming Guide: Support Universal Links - Apple](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html)
- [Flutter Deep Linking: The Ultimate Guide - Code with Andrea](https://codewithandrea.com/articles/flutter-deep-links/)
- [Deep Linking in Flutter with go_router: A Complete Guide (Medium)](https://medium.com/@ImAmmarYasser/deep-linking-in-flutter-with-go-router-a-complete-guide-fda2be821fd1)
- [How to make deep linking play nicely with go_router · supabase-flutter#901](https://github.com/supabase/supabase-flutter/issues/901)
- [Are Your Android & iOS Deep Links Ready for 2025? - ProAndroidDev](https://proandroiddev.com/are-your-android-ios-deep-links-ready-for-2025-e822c1b650c8)
- [GitHub - ho-nl/next-assetlinks](https://github.com/ho-nl/next-assetlinks)
- [assetlinks.json file on root · vercel/next.js Discussion #13113](https://github.com/vercel/next.js/discussions/13113)
- [How to add apple-app-site-association and assetlinks.json in NextJs (Medium)](https://medium.com/@sshekhar336/how-to-add-apple-app-site-association-and-assetlinks-json-files-in-nextjs-and-reactjs-240efcc92d7f)
- [Getting Started: Route Handlers | Next.js Docs](https://nextjs.org/docs/app/getting-started/route-handlers)
- [Client authentication | Google Play services - obtaining SHA fingerprints](https://developers.google.com/android/guides/client-auth)
