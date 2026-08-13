# Handoff — app móvil El Mundo Te Busca

Estado a **13 de agosto de 2026**. Escrito para retomar el trabajo desde cero
en otra sesión.

---

## Lo primero, en orden

```bash
git pull                                        # sincronizar antes de tocar nada
flutter pub get
flutter analyze && flutter test                 # deben salir limpios
flutter run --dart-define-from-file=env.local.json
```

**`env.local.json` no está en el repo** (está en `.gitignore` y el repo es
público). Copia `env.example.json` y rellena con estos valores, que salen del
`.env` del sitio en el VPS:

| Clave | De dónde sale |
|---|---|
| `SUPABASE_URL` | `NEXT_PUBLIC_SUPABASE_URL` del VPS |
| `SUPABASE_ANON_KEY` | `NEXT_PUBLIC_SUPABASE_ANON_KEY` del VPS |
| `ASISTENTE_URL` | `https://elmundotebusca.com/api/asistente` |
| `AUTH_URL` | `https://elmundotebusca.com/api/app-auth` |

**Del `.env` del VPS solo se copian esas dos `NEXT_PUBLIC_*`.** Las otras once
son secretos de servidor. `SUPABASE_SERVICE_ROLE_KEY` en particular se salta
todas las políticas RLS: filtrarla equivale a entregar la base entera —con
48.000 personas desaparecidas dentro— a quien instale la app.

---

## Trampa que cuesta una hora si no se sabe

El repo vive en **iCloud Drive**. iCloud pega atributos extendidos
(`com.apple.FinderInfo`) a los archivos y `codesign` se niega a firmar
binarios que los lleven. El build de iOS falla con *"resource fork, Finder
information, or similar detritus not allowed"*, que no tiene nada que ver con
el código.

```bash
rm -rf build && mkdir -p ~/FlutterBuilds/MundoTeBusca && ln -s ~/FlutterBuilds/MundoTeBusca build
```

Si ya falló antes, limpiar el estado a medias o el enlazador se queja de
`Undefined symbol: _OBJC_CLASS_$_FlutterAppDelegate`:

```bash
flutter clean && rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
```

**Lo correcto sería mover el proyecto fuera de iCloud.** No se hizo por no
interrumpir el trabajo, pero es la solución de fondo.

---

## Arquitectura

Flutter + Supabase directo, sin API intermedia — salvo lo que **no puede** ir
por ahí, que va por un proxy propio (siguiente sección).

```text
lib/
├── core/          config · router · state · supabase · theme · util
├── models/        Persona · Publicacion · PuntoAyuda · Pais · cifras
├── repositories/  única capa que toca Supabase
├── features/      una carpeta por pantalla
└── widgets/       MTCard · FloatingTabBar · MTHeader · hojas compartidas
```

63 archivos Dart, ~11.300 líneas. Riverpod para estado, `go_router` con las
**mismas rutas que la web** (`/se-busca`, `/persona/:id`) para que los enlaces
de gestión abran la app por App Links / Universal Links.

### Reglas que el código hace cumplir

Estas no son estilo, son decisiones con motivo. Si alguien las deshace sin
saber por qué existen, reintroduce el fallo:

- **`Fresh<T>`** — los repositorios devuelven el dato con el momento en que se
  trajo. `StaleDataBanner` avisa de la antigüedad. Servir un estado viejo como
  actual en una app de desaparecidos es peligroso.
- **Ninguna cifra negativa llega a pantalla** — `CifraChip` corta en cero, con
  test. Es el defecto que la web tiene al cambiar de país (`-25 personas
  buscadas`).
- **Cuando falla la consulta se dice**, no se pinta `0`. Un cero se lee como
  "no hay desaparecidos".
- **El muro filtra `moderation_status = 'approved'`** — los posts de Bluesky y
  Mastodon nacen en `pending` y no ha pasado nadie por ellos.

---

## El proxy del VPS

`193.122.159.98`, servicio pm2 **`asistente-emtb`** en `127.0.0.1:3210`,
código en `server/asistente/index.js` (versionado aquí, desplegado en
`~/asistente-emtb/index.js`).

Existe porque hay tres cosas que la app **no puede** hacer sola:

| Ruta | Qué resuelve | Por qué no puede ir en el cliente |
|---|---|---|
| `/api/asistente` | Chat con OpenAI (SSE) | La API key es facturable y un IPA se descomprime |
| `/api/app-auth` | Login por nombre de usuario | RLS no deja leer `profiles` para resolver el `login_email` |
| `/api/app-auth/profile` | Perfil del usuario | Misma política RLS |
| `/api/app-auth/publicar` | Crear post o ficha | La web quitó la escritura pública con `anon` tras sufrir abuso |

Reusa las llaves del `.env` del sitio. **Ojo con `pm2 restart --update-env`**:
relee el entorno del shell actual, y una sesión SSH nueva no tiene esas
variables. Si el proxy deja de funcionar tras un reinicio, es eso.

```bash
pm2 logs asistente-emtb --lines 40    # diagnóstico
sudo nginx -t && sudo systemctl reload nginx
```

Respaldo de la config de nginx en `/tmp/elmundotebusca.nginx.bak`.

---

## Lo que funciona hoy

| Pantalla | Estado |
|---|---|
| Inicio | Cifras reales, noticias (GDELT), donaciones, selector de país |
| Se busca | 5.291 fichas de Colombia con scroll infinito, filtros, búsqueda |
| Ficha de persona | Completa: foto, datos, contacto, reacciones, procedencia |
| ¿La reconoces? | Baraja deslizable con sellos |
| Comunidad | Muro (575 posts), voluntarios, caravanas, denuncias, comentarios |
| Mapa | 63 puntos de ayuda con capas |
| Asistente | OpenAI real con streaming y contexto de la emergencia |
| Ajustes | Perfil, cuenta, red de auxilio, secciones |
| **Publicar** | Post y ficha **desde la app**, escribiendo de verdad |
| Guía de emergencia | 9 pasos + teléfonos, **funciona sin conexión** |

Sesión con nombre de usuario, igual que la web.

---

## Roto / pendiente

### 1. El perfil no carga (lo único roto)

Muestra `estebanmanuel600` en vez de `Manuu` y sin foto.

**Lo verificado:** la app **sí llama** al endpoint (llegaron dos
`GET /auth/profile` al log), la foto existe y es pública (HTTP 200, webp,
1,5 MB), y las URLs están compiladas en el binario.

**Lo que falta:** leer el log tras abrir la pantalla. Dejé registro detallado
en `manejarPerfil` que distingue tres causas — token rechazado, consulta
fallida, o cero filas:

```bash
pm2 logs asistente-emtb --lines 30 | grep perfil
```

Basta abrir Ajustes o Mi perfil una vez y mirar. **Es lo primero que haría.**

### 2. Datos que no existen

Verificado contra la base — no son bugs, pero sorprenden en una demo:

| | Colombia | Venezuela |
|---|---|---|
| Hospitales | **0** | 19 |
| Denuncias | **0** | 4 |
| Voluntarios · Caravanas · Mascotas | 0 | 0 |
| `persons` con `is_unidentified` | **0** de 48.073 | 0 |

Ningún país luce completo solo. Para el pitch conviene **cambiar de país en
vivo**: Colombia para el muro (575 posts), Venezuela para hospitales y
denuncias.

### 3. Noticias en inglés

GDELT devuelve 0 resultados en español para la consulta del sitio (medido: 53
inglés, 7 urdu, 0 español). Los medios en español de la web vienen de **GNews
con `lang=es`**, que exige API key.

**Solución correcta:** una ruta pública en el repo web que sirva las noticias
ya calentadas por su cron. Son ~20 líneas en su Next y la app pasa a leer de
ahí. Es del repo `Angelsistemas7/ElMundo-Te-Busca`.

### 4. Fotos al publicar

Los formularios funcionan sin foto. Subirlas necesita permisos de Storage que
no verifiqué. Es aditivo.

### 5. Emergencia a tres toques

El 123 está en Ajustes → Emergencia, y a dos por el "?" de la cabecera. En una
app de desastres sigue pareciendo lejos. Decisión de producto pendiente.

---

## Reparto del equipo

Ver `plan-app-movil/06-correcciones-y-reparto.md`.

- **Manuu** — Personas y Comunidad *(esta sesión)*
- **jerdiaz** — Ayuda, hospitales, mascotas, mapa completo
- **Angel** — Backend, Edge Function, deep linking, cuentas, red de auxilio

### Avisos para el equipo

- **`anonymous_users` está en `false`** en Supabase. El plan de Angel se apoya
  en `signInAnonymously`; no va a funcionar hasta que se habilite en el panel.
- **El dominio del correo sintético es `users.venezuelatebusca.org`**, no
  `elmundotebusca`. Parece un descuido y da tentación de corregirlo: cambiarlo
  rompe el login de todas las cuentas existentes.
- **Los teléfonos de emergencia de Colombia** (123/119/132/144) los puse yo;
  el documento solo traía los de Venezuela. **Que alguien los verifique.**
- **El hueco bajo la tab bar flotante** se inyecta desde el shell vía
  `MediaQuery`. Una pantalla nueva con un `ListView` que ignore
  `padding.bottom` tendrá su última tarjeta tapada.
- **Hay tres elementos flotantes** en Comunidad (tab bar, asistente, publicar).
  El propio documento de Angel §6 argumenta contra el FAB del asistente por
  competir con la tab bar. Sin resolver.

---

## Compilar e instalar en iPhone

El panel de simulador no sirve para dispositivos físicos. `flutter run` a veces
no engancha el depurador (`Dart VM Service was not discovered`), pero el build
sí termina:

```bash
flutter build ios --release --dart-define-from-file=env.local.json
xcrun devicectl device install app --device <UDID> ~/FlutterBuilds/MundoTeBusca/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <UDID> --terminate-existing com.mundotebusca.mundoTeBusca
```

Android compila sin nada especial: `flutter build apk --debug`.

---

## Al terminar

```bash
git fetch origin && git rebase origin/main    # el equipo empuja seguido
flutter analyze && flutter test
git push origin main
```

Antes de cada commit, comprobar que no se cuela nada:

```bash
git diff --cached --name-only | grep -iE "env\.local|\.key$"
```
