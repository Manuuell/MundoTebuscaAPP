# El Mundo Te Busca — app móvil

App Flutter (Android + iOS + web) de la plataforma ciudadana de búsqueda de
personas y ayuda ante emergencias. Implementa la arquitectura acordada en
[`plan-app-movil/`](plan-app-movil/).

## Arrancar

Copia `env.example.json` a `env.local.json` y rellena los dos valores.
`env.local.json` está en `.gitignore` y **nunca** se versiona — este repo es
público.

```bash
cp env.example.json env.local.json   # y editar
flutter run --dart-define-from-file=env.local.json
```

### De dónde salen esas credenciales

Del `.env` del sitio web, en el VPS: `/var/www/elmundotebusca/.env`.

**Solo se copian las dos `NEXT_PUBLIC_*`** (`NEXT_PUBLIC_SUPABASE_URL` y
`NEXT_PUBLIC_SUPABASE_ANON_KEY`). Son públicas por diseño: ya viajan en el
bundle del sitio y van protegidas por las políticas RLS.

Todo lo demás de ese archivo es secreto de servidor y **no puede entrar en la
app bajo ningún concepto** — un APK o un IPA son archivos que cualquiera
descomprime y de los que se extraen cadenas en segundos. En particular
`SUPABASE_SERVICE_ROLE_KEY` **se salta todas las políticas RLS**: filtrarla
equivale a entregar la base de datos completa, con permiso de escritura y
borrado, a quien instale la app. Los otros seis (`TURNSTILE_SECRET_KEY`,
`ADMIN_TOKEN`, `BLUESKY_APP_PASSWORD`, `OPENAI_API_KEY`, `CRON_SECRET`,
`GNEWS_API_KEY`) tampoco.

Si la app llega a necesitar algo que hoy requiere un secreto, la salida es la
Edge Function de escritura segura, no meter la llave en el cliente.

Sin llaves la app **arranca igual**, con las pantallas en su estado de error.
Es a propósito: se puede navegar toda la UI sin backend, y en producción un
fallo de configuración se ve en vez de esconderse tras una pantalla negra.

Verificación rápida:

```bash
flutter analyze && flutter test
```

### Si el repo vive dentro de iCloud Drive (iOS)

iCloud le pega atributos extendidos (`com.apple.FinderInfo`) a los archivos, y
`codesign` se niega a firmar binarios que los lleven. El build de iOS falla con
*"resource fork, Finder information, or similar detritus not allowed"* — que no
tiene nada que ver con el código.

Solución: sacar los artefactos de build fuera de iCloud, una sola vez.

```bash
rm -rf build && mkdir -p ~/FlutterBuilds/MundoTeBusca && ln -s ~/FlutterBuilds/MundoTeBusca build
```

Si ya falló antes, hay que limpiar el estado a medias o el enlazador se queja de
`Undefined symbol: _OBJC_CLASS_$_FlutterAppDelegate`:

```bash
flutter clean && rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
```

## Decisiones que ya están tomadas

- **Flutter habla directo con Supabase**, sin API intermedia: mismas políticas
  RLS que la web, sin duplicar reglas de negocio en dos lenguajes.
- **Riverpod** para estado, **go_router** para navegación y deep links.
- **`flutter_map`** en vez de Google Maps, para no atarse a su facturación.
- Las rutas son **las mismas que las de la web** (`/se-busca`, `/persona/:id`,
  `/persona/:id/gestion?token=`). No es cosmético: los enlaces de gestión que
  llegan por correo tienen que abrir la app vía App Links / Universal Links, y
  eso solo funciona si los paths coinciden.

## Estructura

```text
lib/
├── main.dart                  # arranque + init de Supabase
├── app.dart                   # MaterialApp.router + tema
├── core/
│   ├── config/env.dart        # llaves y tiles por --dart-define
│   ├── router/app_router.dart # rutas y shell de 5 tabs
│   ├── state/                 # país activo (persistido)
│   ├── supabase/              # cliente y sesión
│   ├── theme/                 # paleta y ThemeData de la marca
│   └── util/                  # Fresh<T>, UUID de dispositivo
├── models/                    # Persona, PuntoAyuda, Pais, cifras
├── repositories/              # única capa que toca Supabase
├── features/                  # una carpeta por pantalla
└── widgets/                   # componentes compartidos
```

La UI **nunca** habla con Supabase directo: siempre pasa por un repositorio,
igual que en la web ningún componente toca la base sin pasar por `data.ts`.

## Dos reglas que el código hace cumplir

**1. Nada se muestra como actual si no lo es.** Los repositorios no devuelven
datos pelados: devuelven `Fresh<T>`, que lleva pegado el momento en que se
trajo de la red. `StaleDataBanner` pinta *"última actualización hace X"* solo
cuando hace falta. En una app de personas desaparecidas, servir un estado
viejo como si fuera de ahora es peligroso — así la antigüedad no depende de
que alguien se acuerde de mostrarla.

**2. Ninguna cifra negativa llega a pantalla.** `CifraChip` corta en cero y hay
un test que lo fija. Es el defecto que la web tiene hoy al cambiar de país
(muestra `-25 personas buscadas`): una cifra negativa es siempre un error de
cálculo, y en el tablero principal destruye la credibilidad de todo lo demás.

Relacionado: cuando falla la consulta, la pantalla dice que **no pudo
consultar** — no pinta `0`. Un cero se lee como "no hay desaparecidos", que es
una afirmación muy distinta.

## Estado actual

Fase 0 completa (cimientos) y parte de la Fase 1. Lo que ya corre:

- Los 5 tabs de `MobileNav.tsx` con hoja "Más", tema y tipografías reales.
- Selector de país persistido, con línea de emergencia por país (123 / 911).
- Inicio con hero, cifras del sismo con fuente y fecha, y los 8 chips
  enlazados a su filtro.
- "Se busca" con búsqueda, filtros por estado y filtro desde la URL.
- Mapa con capas conmutables.
- Repositorios de personas, ayuda y cifras, con Realtime listo.

Pendiente, marcado con `TODO` en el código: feed de noticias, listados de
comunidad, ayuda y hospitales, y la validación del token de gestión — que va
en el servidor, no en el cliente.

**Antes de conectar contra el proyecto Supabase real** hay que contrastar los
nombres de columna de `lib/models/` con `supabase/schema.sql` del repo web.
Están puestos según lo que expone la web hoy, no verificados contra el esquema.
