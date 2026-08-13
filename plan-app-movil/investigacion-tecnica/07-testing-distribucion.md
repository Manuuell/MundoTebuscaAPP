# 07 — Testing y distribución sin tienda (para HOY)

> Investigación de apoyo para el equipo de la app móvil (Flutter) de **El Mundo
> Te Busca**. No modifica ningún repo. Referencias: `plan-app-movil/README.md`
> (recursos confirmados: un compañero tiene Mac, instalación por depuración,
> sin publicación en tiendas planeada) y `plan-app-movil/03-roadmap.md`
> (Fase 5 = publicación, todavía no).

## Resumen ejecutivo (léelo primero)

Para probar la app **hoy, entre los 3**, sin tocar ninguna tienda:

- **Si los 3 tienen Android** (o la mayoría): compartir el APK de debug/release
  directo — por WhatsApp, Drive, o un link temporal de Diawi/Firebase App
  Distribution — es el camino más rápido, cero fricción, cero costo. Minutos,
  no horas.
- **Si hay algún iPhone en el equipo o en quien lo pidió**: ahí está el cuello
  de botella real. La única persona con Mac puede instalar directo por Xcode
  en **su propio** iPhone (gratis, Apple ID normal) y en los iPhones de otros
  compañeros **si tiene el cable/dispositivo físico en mano** (gratis también,
  vía "Personal Team"). Pero **no puede mandar un link para que un iPhone
  ajeno se instale la app remotamente sin pagar los $99/año de Apple
  Developer** — ni Firebase App Distribution ni TestFlight lo evitan en iOS.
  Esto confirma la sospecha del plan: es una contradicción real, no un mito.
- **Recomendación concreta**: hoy, usar **Firebase App Distribution** para
  Android (gratis, sin límite de tiempo, funciona igual de bien que un APK
  suelto pero con historial y grupos de testers — útil ya que van a repetir
  esto varias veces). Para iOS, hoy mismo la única opción sin pagar es
  instalar físicamente con el Mac en cada iPhone del equipo (build de debug,
  minutos por dispositivo). Si quien lo pidió con urgencia tiene iPhone y no
  va a estar físicamente con el Mac, la opción realista es **grabar pantalla /
  compartir por videollamada** el simulador de iOS o un Android físico, no
  prometer que va a poder instalarlo remotamente hoy.

---

## 1. Distribución interna sin tienda — comparación real 2025-2026

### 1.1 Firebase App Distribution

Gratis, dentro del plan Spark (el nivel gratuito de Firebase) — no requiere
pasar a Blaze (el plan de pago) solo por usar App Distribution.

**Límites del plan gratuito** (confirmados en documentación/fuentes 2026):
- Hasta 30 apps distribuidas por proyecto.
- Hasta 1000 versiones (builds) por app; al superar el límite se borran las
  más antiguas automáticamente.
- Los builds y sus metadatos se conservan ~150 días.
- Sin límite de testers relevante para un equipo de 3-10 personas.

**Pasos (Android)** — el camino corto de hoy:
1. Crear/usar un proyecto Firebase (puede ser el mismo que usan otros
   servicios de Google, si aplica, o uno nuevo).
2. `flutter build apk --debug` (o `--release` si ya hay firma configurada;
   para probar hoy, debug es suficiente y más rápido).
3. Subir el APK desde la consola de Firebase (arrastrar y soltar) **o** vía
   CLI: `firebase appdistribution:distribute build/app/outputs/flutter-apk/app-debug.apk --app <FIREBASE_APP_ID> --testers "correo1@x.com,correo2@x.com"`.
4. Los testers reciben un correo/enlace, instalan la app **Firebase App
   Tester** (o la app misma en Android moderno) y descargan el build.
   En Android no hace falta ninguna app intermedia real — es esencialmente un
   link de descarga directa del APK con seguimiento.

**Pasos (iOS)** — aquí está la parte que contradice el plan de "no pagar
Apple Developer todavía":
1. Igual que en Ad Hoc nativo de Apple, Firebase App Distribution para iOS
   **necesita una cuenta Apple Developer de pago** para generar el
   certificado de distribución y el *provisioning profile* ad hoc.
2. Ese *provisioning profile* debe listar los UDID de **cada** dispositivo
   iOS que va a instalar el build (máximo 100 dispositivos por año de
   membresía). Firebase automatiza la recolección de UDID (el tester abre un
   link, su UDID se captura y se notifica al desarrollador), pero de todas
   formas hay que regenerar el provisioning profile con ese UDID y volver a
   distribuir.
3. Sin cuenta de pago, no hay certificado de distribución ad hoc que firmar
   — Firebase App Distribution para iOS **no funciona sin ella**. No es un
   límite de Firebase, es una restricción de Apple sobre qué se puede firmar.

**Conclusión de esta sección**: Firebase App Distribution resuelve Android
hoy mismo, gratis. Para iOS no resuelve nada que Xcode directo no resuelva ya
— sigue exigiendo pagar Apple Developer en cuanto se quiera instalar en un
iPhone que **no** esté conectado físicamente por cable al Mac del equipo.

### 1.2 TestFlight (Apple)

Se confirma lo que sospechaba el plan: **TestFlight requiere de todas formas
una cuenta Apple Developer Program de pago ($99/año)**, sin excepción, para
distribuir a testers externos. No hay una versión gratuita de TestFlight.

- Con cuenta de pago, TestFlight soporta hasta 10 000 testers externos vía
  link público o invitación por correo.
- El **primer build** de cada versión mayor pasa por una revisión ligera de
  Apple antes de llegar a testers externos (normalmente 24 h, a veces
  4-48 h) — esto ya empieza a parecerse a "publicación", aunque no sea la
  App Store pública.
- Testers **internos** (miembros del equipo dentro del mismo Apple Developer
  account, hasta 100 personas, sin revisión) sí es más simple, pero de nuevo
  exige la cuenta de pago para existir.

**Conclusión**: TestFlight no es un atajo gratuito. Si el plan es "no pagar
Apple Developer todavía", TestFlight queda descartado para hoy, sea cual sea
la cantidad de testers.

### 1.3 APK directo (Android) — "cero fricción"

- Gratis, sin cuentas, sin límites de tiempo. Se comparte el archivo `.apk`
  por WhatsApp, Drive, Telegram, USB, lo que sea.
- Desde Android 8 (Oreo) no existe un interruptor global de "orígenes
  desconocidos": el permiso se otorga por app instaladora (ej. "permitir que
  Chrome instale apps"), y en Android 14/15 sigue funcionando igual — se
  concede una vez por app instaladora (Settings → Apps → Acceso especial →
  Instalar apps desconocidas), luego los siguientes APK desde esa misma app
  se instalan sin fricción.
- **No sirve para iOS de ninguna forma.** Apple no permite sideload real de
  un `.ipa` sin (a) un dispositivo conectado a Xcode con Apple ID (gratis
  pero manual, dispositivo por dispositivo, cada 7 días si es Apple ID
  gratis) o (b) jailbreak (fuera de cuestión para un proyecto serio) o
  (c) instaladores de terceros tipo AltStore/Sideloadly que igual dependen
  del mismo mecanismo de firma con Apple ID y expiran cada 7 días con cuenta
  gratuita.

### 1.4 Diawi y alternativas de distribución ad-hoc rápida

- **Diawi**: sube un `.apk`/`.ipa`, genera un link corto y un QR. En el plan
  gratuito: el link expira en ~24 h (o pocas descargas, límite de 2
  instalaciones), y hay tope de tamaño (~20 MB en algunas fuentes, puede
  variar). Sirve para una demo puntual de hoy mismo, no para un ciclo de
  pruebas recurrente.
- **Alternativas 2026** con más margen gratuito o mejor experiencia:
  TestApp.io, Loadly.io, BetaDrop (gratis, sin límites declarados), Apps On
  Air (links de hasta 90 días), Updraft (instalaciones ilimitadas, hosting en
  Suiza). Para Android, cualquiera de estas es intercambiable con "mandar el
  APK por WhatsApp" — la ventaja real es el QR y que no hay que mover un
  archivo de 40-80 MB por chat.
- **Importante**: todas estas herramientas, para **iOS**, siguen necesitando
  un `.ipa` firmado con un certificado de distribución ad hoc — es decir,
  siguen necesitando la cuenta Apple Developer de pago por debajo. Ninguna
  herramienta de terceros evita esa restricción de Apple.

### 1.5 Recomendación concreta para HOY

Antes que nada, una pregunta que el equipo tiene que responder ya:
**¿cuántos del equipo (y quien pidió la demo) tienen Android vs. iPhone?**
Eso determina todo lo demás.

- **Camino Android (rápido, gratis, funciona hoy sin excepciones)**:
  1. `flutter build apk --debug` en la máquina de quien esté programando.
  2. Compartir el `.apk` directo por WhatsApp/Drive **o**, si van a repetir
     esto varias veces en los próximos días, invertir 10 minutos en configurar
     Firebase App Distribution (mismo proyecto Firebase que usarán después
     para Crashlytics/Analytics si lo agregan) — así cada nuevo build llega
     por un link limpio a todo el equipo sin re-enviar archivos.
  3. En cada Android, habilitar "instalar apps desconocidas" para la app
     desde la que se abra el archivo (Chrome, Drive, WhatsApp) — una vez.

- **Camino iPhone (el cuello de botella real)**:
  1. **Hoy, sin pagar nada**: la persona con Mac conecta cada iPhone del
     equipo por cable a la Mac, abre el proyecto en Xcode, selecciona el
     dispositivo y da "Run". Con un Apple ID personal (gratis) esto funciona,
     pero el build expira a los 7 días y hay que reinstalar (límite de Apple
     ID gratis: máximo 3 apps activas por dispositivo a la vez). Esto es
     perfectamente viable para demostrar HOY frente a quien lo pidió, **si
     esa persona puede estar físicamente presente con su iPhone** o si se usa
     el simulador de iOS en la pantalla de la Mac (sin dispositivo físico
     alguno, cero restricciones, ideal para una demo por videollamada
     compartiendo pantalla).
  2. **Si alguien fuera del equipo (quien lo pidió) tiene iPhone y no va a
     estar presencialmente con el Mac hoy**: no hay atajo gratuito real. Las
     opciones son (a) pagar los $99/año de Apple Developer ahora mismo para
     habilitar Ad Hoc/TestFlight, o (b) hacer la demo por videollamada
     mostrando el simulador de iOS o un Android físico, y dejar la
     instalación remota en iPhone para cuando decidan pagar la cuenta
     (coherente con la Fase 5 del roadmap, que ya contempla esto).
  3. Esta es información que vale la pena decirle al equipo explícitamente
     hoy: **"mostrar funcionando" y "que la otra persona lo instale en su
     propio iPhone" son dos metas distintas**, y solo la primera es gratis y
     alcanzable en horas.

---

## 2. CI/CD mínimo para Flutter con GitHub Actions

El repo web (`Angelsistemas7/ElMundo-Te-Busca`) ya tiene
`.github/workflows/deploy.yml` con un estilo claro: comentarios largos en
español explicando el porqué de cada paso, `concurrency` para evitar carreras,
variables de entorno inyectadas desde `secrets`. El workflow de Flutter puede
seguir el mismo tono. Ejemplo completo para el repo móvil nuevo
(`.github/workflows/ci.yml`):

```yaml
name: CI Flutter

# Corre analisis + tests en cada push y PR. Opcionalmente sube un APK de
# debug como artifact descargable para probar builds sin pasar por
# distribucion externa (Firebase App Distribution, Diawi, etc).
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configurar Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Instalar dependencias
        run: flutter pub get

      - name: Verificar formato
        run: dart format --output=none --set-exit-if-changed .

      - name: Analizar (lints)
        run: flutter analyze

      - name: Tests (unit + widget)
        run: flutter test --coverage

      # Opcional: sube el reporte de cobertura como artifact para revisarlo
      - name: Subir cobertura
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/lcov.info
          retention-days: 14

  build-debug-apk:
    # Solo en push a main: no gastar minutos de build en cada PR.
    if: github.event_name == 'push'
    needs: analyze-and-test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - run: flutter pub get

      - name: Build APK de debug
        # Debug, no release: no requiere firma ni keystore todavia (eso llega
        # cuando se decida publicar, Fase 5 del roadmap). Las claves publicas
        # de Supabase se inyectan via --dart-define (ver seccion 4).
        run: |
          flutter build apk --debug \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}

      - name: Subir APK como artifact descargable
        uses: actions/upload-artifact@v4
        with:
          name: app-debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk
          retention-days: 14
```

Notas prácticas:
- `subosito/flutter-action@v2` es la acción de facto para instalar Flutter en
  runners de GitHub (miles de repos la usan); no hace falta instalar Java a
  mano en `ubuntu-latest`, ya trae JDK.
- El artifact de `actions/upload-artifact` se descarga desde la pestaña
  "Actions" de GitHub, sin publicar nada — sirve como distribución interna
  adicional (cualquiera del equipo con acceso al repo baja el `.apk` del
  último build verde), pero sigue siendo solo para Android.
- Cuando quieran automatizar Firebase App Distribution desde este mismo
  workflow, existe `wzieba/Firebase-Distribution-Github-Action` (acción de
  terceros ampliamente usada) que sube el APK directo a los grupos de
  testers configurados en Firebase, usando un `FIREBASE_APP_ID` y un
  `FIREBASE_SERVICE_ACCOUNT` (JSON) guardados como secrets — un paso natural
  para cuando quieran dejar de mandar APKs por WhatsApp.

---

## 3. Testing en Flutter — mínimo viable

Diferencias rápidas:

| Tipo | Qué prueba | Dónde corre | Paquete |
|---|---|---|---|
| **Unit test** | Lógica pura (funciones, repositories, parsers) sin UI ni framework de widgets | En la máquina/CI, muy rápido (ms) | `flutter_test` (incluido en el SDK) |
| **Widget test** | Un widget aislado en un entorno de prueba simulado (`WidgetTester`), sin dispositivo real | En la máquina/CI, rápido (segundos) | `flutter_test` |
| **Integration test** | La app completa corriendo en un dispositivo/emulador real, de punta a punta | Emulador/dispositivo físico, más lento (requiere build) | `integration_test` (paquete oficial de Flutter, vive en el SDK) |

Para el MVP de Fase 1 (solo lectura), un test de humo de integración
realista: **"abrir la app, ver la lista de Se busca, tocar una persona, ver
su ficha"**. Estructura de carpetas real:

```
mundo_te_busca_app/
  integration_test/
    app_smoke_test.dart
  test/
    widgets/
      person_card_test.dart      # widget test aislado, ejemplo aparte
  lib/
    main.dart
```

`pubspec.yaml` (fragmento relevante):

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

`integration_test/app_smoke_test.dart` (ejemplo concreto, con los `Key` que
habría que agregar a los widgets reales al implementarlos — `personListKey`
en la lista de "Se busca" y un `Key` por tarjeta con el id de la persona,
siguiendo el mismo patrón de datos de `data.ts` en el repo web):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mundo_te_busca_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Humo — Fase 1 (solo lectura)', () {
    testWidgets(
      'abrir la app, ver Se busca, tocar una persona, ver su ficha',
      (WidgetTester tester) async {
        // 1. Arranca la app real (mismo entry point que usa el usuario).
        app.main();
        await tester.pumpAndSettle();

        // 2. La pantalla inicial es "Se busca" (equivalente a app/page.tsx
        //    en la web): debe mostrar al menos una tarjeta de persona.
        final listaSeBusca = find.byKey(const Key('lista_se_busca'));
        expect(listaSeBusca, findsOneWidget);

        final primeraTarjeta = find.byKey(const Key('tarjeta_persona_0'));
        expect(primeraTarjeta, findsOneWidget);

        // 3. Tocar la primera persona navega a su ficha.
        await tester.tap(primeraTarjeta);
        await tester.pumpAndSettle();

        // 4. La ficha debe mostrar el nombre y no debe quedar en blanco.
        final fichaPersona = find.byKey(const Key('ficha_persona'));
        expect(fichaPersona, findsOneWidget);
        expect(find.text('Cargando...'), findsNothing);
      },
    );
  });
}
```

Cómo correrlo:
```bash
flutter test integration_test/app_smoke_test.dart -d <device_id>
# o, sobre un emulador/dispositivo conectado, con más control de logs:
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_smoke_test.dart
```

Este test **no** entra al workflow de CI de la sección 2 tal cual, porque
`ubuntu-latest` no trae un emulador Android/iOS listo por defecto (hace falta
una acción extra tipo `reactivecircus/android-emulator-runner` para Android,
o un runner `macos-latest` para iOS, ambos más lentos y con minutos de CI más
caros). Para el arranque de hoy, correr este test manualmente en el emulador
de cada quien es suficiente; agregarlo al CI es una mejora natural para
cuando el equipo tenga más margen.

---

## 4. Manejo de secretos (Supabase URL + anon key)

Contexto importante que vale la pena decirle al equipo para bajar la
ansiedad: **la `anon key` de Supabase está diseñada para ser pública** — no
es como una contraseña o una `service_role key`. La seguridad real vive en
las políticas RLS de `supabase/schema.sql` (mismo esquema que ya usa la web,
según `01-arquitectura.md` del plan). Aun así, no conviene commitearla
directo al repo público `Manuuell/MundoTebuscaAPP` por buena higiene (rotarla
después es innecesariamente costoso, y es fácil confundirla más adelante con
la `service_role key` si alguien la copia sin pensar) — y **ese descuido sí
sería grave**: la `service_role key` nunca debe salir del backend.

**Patrón recomendado: `--dart-define` (o `--dart-define-from-file`), NO
`flutter_dotenv`.**

Por qué no `flutter_dotenv` para este caso: el paquete empaqueta el archivo
`.env` como un asset dentro del propio APK/IPA final. Un `.apk` no es más que
un `.zip` — cualquiera que lo descomprima ve el `.env` en texto plano en
`assets/`. Como la anon key ya es pública por diseño, esto no sería un
incidente de seguridad grave hoy, pero sí es una costumbre peligrosa para el
día en que agreguen algo que sí deba quedar oculto (ej. una API key de un
servicio de terceros). Mejor no adoptar el hábito desde el principio.

**Cómo queda en la práctica:**

1. `.gitignore` en el repo Flutter nuevo:
   ```
   # Nunca commitear archivos con secretos locales, aunque hoy la anon key
   # sea publica por diseno -- costumbre para cuando dejen de serlo.
   *.env
   .env.local
   android/key.properties
   ```

2. Archivo local de cada desarrollador (no commiteado), por ejemplo
   `env/dev.json`, para usar `--dart-define-from-file` en vez de escribir el
   comando largo cada vez:
   ```json
   {
     "SUPABASE_URL": "https://xxxx.supabase.co",
     "SUPABASE_ANON_KEY": "eyJ..."
   }
   ```
   ```bash
   flutter run --dart-define-from-file=env/dev.json
   ```

3. Lectura en Dart (`lib/config/env.dart`):
   ```dart
   class Env {
     static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
     static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
   }
   ```

4. En GitHub Actions (ver sección 2), los mismos valores viven como
   **repository secrets** (`Settings → Secrets and variables → Actions`) y se
   pasan con `--dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}` —
   idéntico en espíritu a cómo `deploy.yml` del repo web ya inyecta
   `NEXT_PUBLIC_SUPABASE_URL`/`NEXT_PUBLIC_SUPABASE_ANON_KEY` como secrets del
   repositorio en el paso de build.

5. Para HOY, si no hay tiempo de montar `--dart-define-from-file`, un
   `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
   corrido a mano por quien tenga las credenciales es válido — lo único que
   hay que evitar es escribir esos valores directo dentro de un archivo
   `.dart` que se vaya a commitear.

---

## 5. Nombre del paquete / bundle ID temporal

El plan lo dejó abierto a propósito. Reglas duras que hay que respetar para
que la elección de hoy no comprometa el nombre final:

- **Formato válido (Android `applicationId` / iOS `bundle identifier`)**:
  notación de dominio inverso, mínimo dos segmentos separados por punto,
  solo letras/números/guion bajo/punto, sin guiones, cada segmento debe
  empezar con letra (no número). Ejemplo: `com.elmundotebusca.app`.
- **Reversible mientras no se publique**: el `applicationId`/bundle ID **se
  puede cambiar libremente** en `android/app/build.gradle` (`applicationId`)
  y en Xcode (`PRODUCT_BUNDLE_IDENTIFIER`) todas las veces que quieran,
  *siempre que no se haya publicado ya una versión con ese ID* en Play
  Store/App Store. Una vez publicado, cambiarlo equivale a crear una app
  nueva desde cero (se pierden reseñas, actualizaciones, usuarios). Como la
  Fase 5 (publicación) todavía no llegó, hoy no hay ningún riesgo en elegir
  un ID temporal.
- **Sugerencia concreta, para no bloquear el trabajo de hoy**:
  `com.elmundotebusca.app.dev` (tal como ya lo tenían en mente) es válido y
  deja claro que es de desarrollo. Alternativa igual de segura:
  `com.elmundotebusca.mobile.dev`. Cuando decidan el nombre final para
  publicar, basta con:
  1. Cambiar `applicationId` en Android y el bundle ID en Xcode.
  2. Regenerar cualquier configuración de Firebase (`google-services.json` /
     `GoogleService-Info.plist`) si para entonces ya están usando Firebase
     App Distribution — esos archivos están atados al bundle ID/applicationId
     exacto, así que si lo cambian después de configurarlo, hay que volver a
     descargarlos desde la consola de Firebase con el ID nuevo.
- **No hace falta tener dominio propio verificado para elegir el ID hoy** —
  eso solo importa para *App Links*/*Universal Links* (mencionados en
  `01-arquitectura.md` para los enlaces de gestión con token), que sí son
  Fase 2+ del roadmap, no de hoy.

---

## Fuentes

- [Firebase App Distribution — documentación oficial](https://firebase.google.com/docs/app-distribution)
- [Distribute iOS apps to testers using the Firebase console](https://firebase.google.com/docs/app-distribution/ios/distribute-console)
- [Register additional iOS devices | Firebase App Distribution](https://firebase.google.com/docs/app-distribution/register-additional-devices)
- [Firebase App Distribution: Benefits, Features, and Cost — iconflux](https://iconflux.com/blog/what-is-firebase-app-distribution)
- [TestFlight — Apple Developer](https://developer.apple.com/testflight/)
- [iOS Distribution Guide 2026: TestFlight, App Store & Enterprise — Foresight Mobile](https://foresightmobile.com/blog/ios-app-distribution-guide-2026)
- [TestFlight Distribution Guide — Tech Concepts](https://techconcepts.org/blog/testflight-guide)
- [Create an ad hoc provisioning profile — Apple Developer Help](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/)
- [iOS App Distribution: TestFlight, Ad Hoc, Enterprise & App Store — Appcircle](https://appcircle.io/guides/ios/ios-app-distribution)
- [Best Diawi Alternatives in 2026 — Appisto](https://appisto.app/blog/diawi-alternatives)
- [Diawi Alternative (2026) — TestApp.io](https://testapp.io/alternatives/diawi/)
- [Best Free Diawi Alternative in 2026 — BetaDrop](https://betadrop.app/blog/free-diawi-alternative/)
- [Allow Unknown Sources App Installation in All Android versions — Android Infotech](https://www.androidinfotech.com/unknown-sources-app-installation-android/)
- [Flutter action — GitHub Marketplace (subosito/flutter-action)](https://github.com/marketplace/actions/flutter-action)
- [Flutter CI/CD with GitHub Actions — Medium (Akash Vyas)](https://medium.com/@akashvyasce/automate-your-flutter-builds-with-ci-cd-using-github-actions-55a7790c3f74)
- [How to Automate Flutter Testing and Builds with GitHub Actions — freeCodeCamp](https://www.freecodecamp.org/news/how-to-automate-flutter-testing-and-builds-with-github-actions-for-android-and-ios/)
- [Check app functionality with an integration test — Flutter docs oficiales](https://docs.flutter.dev/testing/integration-tests)
- [Flutter: A deep dive into the integration_test library — gskinner blog](https://blog.gskinner.com/archives/2021/06/flutter-a-deep-dive-into-integration_test-library.html)
- [How to Store API Keys in Flutter: --dart-define vs .env files — Code with Andrea](https://codewithandrea.com/articles/flutter-api-keys-dart-define-env-files/)
- [Securing your data — Supabase Docs](https://supabase.com/docs/guides/database/secure-data)
- [Is it safe to expose the Supabase anon key? — GuardLayer](https://www.guardlayer.io/blog/is-supabase-anon-key-safe)
- [Android Package Name Conventions — w3tutorials](https://www.w3tutorials.net/blog/android-package-name-convention/)
- [Reverse domain name notation — Wikipedia](https://en.wikipedia.org/wiki/Reverse_domain_name_notation)
