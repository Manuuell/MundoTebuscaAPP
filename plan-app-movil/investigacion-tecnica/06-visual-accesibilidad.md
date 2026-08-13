# 06 — Sistema visual: los huecos de `05-fuente-web-existente.md` §5, traducidos a Flutter

Complementa `04-tema-visual.md` (que ya cubre paleta/tipografía/`ThemeData`) y
cierra la lista explícita de pendientes de `05-fuente-web-existente.md` §5
("Elementos que `04-tema-visual.md` aún no cubre"). Todo lo citado del repo
web es real, con `archivo:línea`:

- `src/app/globals.css:81` — `--ease-ios: cubic-bezier(0.32, 0.72, 0, 1);`
- `src/app/globals.css:237-253` — `.tap-card`
- `src/app/globals.css:255-337` — animaciones de hoja (`animate-sheet`,
  `animate-backdrop`, `.sheet-handle`, `.pb-safe`)
- `src/app/globals.css:125-138` — `prefers-reduced-motion`
- `src/app/globals.css:281-294` + `src/lib/viewTransition.ts` +
  `src/components/Card.tsx` + `src/components/PersonCard.tsx:21-24` —
  transición "hero" tarjeta→ficha
- `src/components/PersonPhoto.tsx:33` — alt text solo con nombre, nunca
  descripción física
- `docs/investigacion/08-accesibilidad-performance.md` M1 — `brand-600` NO
  pasa AA como texto normal

No se tocó ningún archivo de `C:\Users\angel\Desktop\Elmundotebusca` ni de
`C:\Users\angel\Desktop\MundoTebuscaAPP` — solo lectura.

---

## 1. Curva de animación iOS (`cubic-bezier(0.32, 0.72, 0, 1)`)

La web la declara una sola vez como variable CSS y la reusa en hojas modales
y en las View Transitions (`globals.css:81`, `:267`, `:287`). En Flutter el
equivalente exacto es la clase `Cubic`, que toma los mismos 4 números que un
`cubic-bezier()` de CSS — no hay conversión, es literalmente el mismo tipo de
curva (Bézier cúbica con puntos de control fijos en x=0 y x=1) que ya usa
UIKit y que Tailwind/CSS también modelan así.

```dart
// lib/theme/motion.dart
import 'package:flutter/animation.dart';

/// Misma curva que --ease-ios en src/app/globals.css:81
/// (cubic-bezier(0.32, 0.72, 0, 1) — la curva "spring" de hojas de UIKit).
/// Los 4 argumentos posicionales de Cubic son EXACTAMENTE los 4 números de
/// cubic-bezier(a, b, c, d): no hay conversión de unidades, es el mismo
/// polinomio de Bézier cúbico.
const Curve easeIOS = Cubic(0.32, 0.72, 0, 1);
```

Dónde aplicarla para que se sienta igual que en la web:

- **Bottom sheets** (equivalente a `.animate-sheet`, `globals.css:266-268`,
  `animation: slide-up 0.32s var(--ease-ios)`):

```dart
showModalBottomSheet(
  context: context,
  transitionAnimationController: AnimationController(
    duration: const Duration(milliseconds: 320), // mismo 0.32s que animate-sheet
    reverseDuration: const Duration(milliseconds: 220), // mismo 0.22s que animate-sheet-out
    vsync: this,
  ),
  builder: (context) => const MySheet(),
);
```

  `showModalBottomSheet` no acepta una `Curve` directamente en sus parámetros
  — controla la curva pasando un `AnimationController` propio y envolviendo
  el contenido en un `CurvedAnimation`, o (más simple y recomendado, ver §3)
  usando un paquete como `wolt_modal_sheet` que expone `Curve` como
  parámetro de configuración.

- **Transiciones de página** (para que la navegación entre pantallas se
  sienta como la web, aunque la web solo tiene la transición hero puntual
  para persona→ficha — ver §6): un `PageRouteBuilder` custom con
  `CurvedAnimation(parent: animation, curve: easeIOS)`:

```dart
class IOSCurvedRoute<T> extends PageRouteBuilder<T> {
  IOSCurvedRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: easeIOS);
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        );
}
```

- **`AnimatedContainer`/`AnimatedScale` genéricos** (usados en `.tap-card`,
  §2): pasan `curve: easeIOS` o `Curves.easeOut` directo — para el "press"
  táctil de 0.18s la web usa `ease` genérico (`globals.css:239-243`), no
  `--ease-ios` (esa curva se reserva para hojas/transiciones grandes, no
  para el micro-feedback de presión). Mantener esa misma separación en
  Flutter: `easeIOS` para hojas/navegación, `Curves.easeOut` simple para el
  "press" de una tarjeta.

**Confirmación:** `Cubic` es la clase oficial de Flutter para curvas Bézier
cúbicas arbitrarias — "third-order Bézier curve", recomendada solo si
ninguna de las predefinidas en `Curves` sirve (que es el caso aquí, porque
se quiere el valor exacto de la marca) [Dart API — Cubic class](https://api.flutter.dev/flutter/animation/Cubic-class.html).

---

## 2. Patrón `.tap-card`

La versión web (`globals.css:235-253`) tiene tres partes: sombra en reposo
(`--shadow-widget`), elevación al pasar el mouse (`hover: hover`, para no
disparar en táctil) y "presión" (`scale(0.99)`) al tocar/hacer click. El
equivalente Flutter no necesita distinguir hover en móvil (no hay cursor),
pero sí replica la presión táctil con feedback inmediato, y puede añadir el
hover en la rama de escritorio/web de Flutter si aplica.

```dart
// lib/widgets/tap_card.dart
import 'package:flutter/material.dart';
import '../theme/motion.dart';

/// Equivalente a .tap-card (src/app/globals.css:235-253): tarjeta con
/// sombra "widget" en capas y "presión" al tocar. La versión web separa
/// hover (solo mouse, media query `hover: hover`) de active (scale 0.99);
/// en Flutter no hay "hover" real en táctil, así que solo se replica el
/// press — MouseRegion cubre el caso desktop/web si aplica.
class TapCard extends StatefulWidget {
  const TapCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<TapCard> createState() => _TapCardState();
}

class _TapCardState extends State<TapCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // scale(0.99) al presionar, igual que .tap-card:active (globals.css:251-253)
    final scale = _pressed ? 0.99 : (_hovered ? 1.0 : 1.0);
    final elevation = _hovered ? 16.0 : 8.0; // widget vs widget-hover

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120), // ~.press (globals.css:355-360)
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180), // mismo 0.18s de .tap-card
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24), // rounded-3xl (Card.tsx:27)
              border: Border.all(color: const Color(0xFFE4E4E7)), // zinc-200
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0A101828), // rgba(16,24,40,.04)
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, _hovered ? 0.18 : 0.12),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                  spreadRadius: -8,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
```

Nota de fidelidad: `Material` + `InkWell` da el "ripple" nativo de Android
gratis (que la web no tiene), pero cambia la sensación respecto a la web
(que no tiene ripple, solo escala+sombra). Si se quiere fidelidad visual
estricta con la web, usar `GestureDetector` puro como arriba (sin `InkWell`)
en iOS y considerar si vale la pena diferenciar Android con `InkWell` para
que se sienta "nativo" ahí — es una decisión de producto, no técnica.

---

## 3. Bottom sheets estilo iOS

### `showModalBottomSheet` nativo de Flutter

Ya cubre: aparece desde abajo, se puede arrastrar para cerrar
(`enableDrag: true`, default), fondo con barrier. Lo que **no** da gratis
comparado con `Modal.tsx` (`src/components/Modal.tsx`):

- **Barra de arrastre visual** (`.sheet-handle`, `globals.css:321-328`):
  Flutter no dibuja ninguna por defecto — hay que agregar el widget a mano
  (trivial, ver snippet abajo) o usar
  `showModalBottomSheet(showDragHandle: true)` (disponible desde Flutter
  3.13+, dibuja una barra gris centrada automáticamente, ya con el estilo
  Material 3 — muy cercana visualmente al `.sheet-handle` de la web).
- **Pila de modales** (`Modal.tsx:13`, `modalStack`, para que Escape/back
  cierre solo el de encima): Flutter maneja esto de forma nativa vía el
  `Navigator` — cada `showModalBottomSheet` empuja una ruta, y el botón
  "atrás" de Android / gesto de swipe-back de iOS ya cierra solo la hoja de
  encima sin código adicional (a diferencia de la web, que tuvo que
  reconstruir manualmente el comportamiento de "atrás" con
  `history.pushState`/`popstate`, `Modal.tsx:97-134`, precisamente porque el
  navegador no ofrece pila nativa para overlays).
- **Curva iOS exacta y timings**: como en §1, controlable con
  `transitionAnimationController`.

```dart
Future<T?> showIOSSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true, // deja que el contenido defina su alto, como max-h-[85dvh]
    showDragHandle: true,     // barra de arrastre nativa ~ .sheet-handle
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)), // rounded-t-3xl
    ),
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    ),
    builder: (context) => SafeArea(child: child), // ver §4
  );
}
```

### `wolt_modal_sheet` (paquete especializado)

Diseñado específicamente para look "iOS real": multi-página con transición
animada entre páginas dentro de la misma hoja, contenido scrollable por
página, y se adapta automáticamente a diálogo centrado en pantallas anchas
vs. hoja inferior en móvil — algo que la web no necesita resolver (siempre
es la misma ventana) pero que en una app nativa multi-tamaño (teléfono vs.
tablet) sí importa [wolt_modal_sheet en pub.dev](https://pub.dev/packages/wolt_modal_sheet).
Repo oficial de Wolt (la empresa de delivery finlandesa, no relacionado con
este proyecto) — mantenido activamente, con guía de diseño incluida.

### Comparación y recomendación

| | `showModalBottomSheet` nativo | `wolt_modal_sheet` |
|---|---|---|
| Barra de arrastre | Con `showDragHandle: true` (Flutter 3.13+) | Config propia, look "Wolt" (redondeado, sombra suave) |
| Curva/timing custom | Sí, vía `transitionAnimationController` (manual) | Parámetro directo de configuración |
| Multi-página dentro de una hoja | No (habría que anidar `Navigator`) | Sí, nativo del paquete (`WoltModalSheetPage`) |
| Adaptación diálogo↔hoja por tamaño de pantalla | Manual | Automática |
| Curva de aprendizaje / dependencia extra | Ninguna (SDK) | Una dependencia más que mantener actualizada |
| Pila de modales (uno encima de otro) | Nativa vía `Navigator` | Nativa vía `Navigator` (compatible) |

**Recomendación para este proyecto**: empezar con `showModalBottomSheet`
nativo + `showDragHandle: true` + `AnimationController` con `easeIOS` — el
90% del look de `Modal.tsx` se logra sin dependencia nueva, y los modales de
la web (`Modal.tsx`) son de una sola "página" (no hay wizard multi-paso
dentro de un mismo modal en el código actual). Si más adelante aparece un
flujo real multi-paso dentro de una hoja (p. ej. el "¿Qué quieres hacer?" de
`RegisterPersonButton` con pasos encadenados), reconsiderar
`wolt_modal_sheet` en ese punto concreto, no como base general — evita
adoptar una dependencia grande "por si acaso" en Fase 0.

---

## 4. Safe area

`SafeArea` es un widget del SDK de Flutter (no un paquete) que envuelve
contenido y le agrega padding automático para evitar notch, Dynamic Island,
barra de estado, home indicator (iOS) y barra de gestos/navegación
(Android) — lee esos valores del sistema operativo vía
`MediaQuery.of(context).padding` (o `viewPadding`/`viewInsets` para casos
con teclado abierto), sin que el desarrollador tenga que calcular nada a
mano.

```dart
Scaffold(
  body: SafeArea(
    child: MySheetContent(),
  ),
)
```

Confirmación de la diferencia con la web: en CSS, `env(safe-area-inset-*)`
(`globals.css:332-337`, `.pb-safe`/`.pb-safe-nav`) es un valor que **el
propio desarrollador tiene que acordarse de aplicar** en cada contenedor que
toque el borde de la pantalla (footer del modal, barra de navegación
inferior) — si se olvida en un componente nuevo, ese componente queda tapado
por el home indicator y nadie avisa. En Flutter, `SafeArea` es un widget
explícito que se coloca una vez alrededor de la pantalla/hoja entera (o del
`Scaffold` completo con `Scaffold(...)` ya respeta el safe area en su
`bottomNavigationBar` por defecto) — el mismo cuidado que en la web requirió
una convención documentada y disciplina en cada componente, en Flutter es
una sola envoltura por pantalla. Para casos parciales (solo el padding
inferior, como `.pb-safe`), `SafeArea(top: false, left: false, right: false,
child: ...)` replica exactamente ese matiz.

---

## 5. `prefers-reduced-motion`

Equivalente de sistema operativo (iOS: "Reduce Motion" en Ajustes >
Accesibilidad; Android: "Eliminar animaciones" en Ajustes > Accesibilidad):
Flutter lo expone en `MediaQueryData.disableAnimations`, accesible con
`MediaQuery.of(context).disableAnimations` o (forma más eficiente,
recomendada por el propio equipo de Flutter porque no reconstruye todo el
widget al cambiar cualquier otro dato de `MediaQuery`)
`MediaQuery.disableAnimationsOf(context)`
[`disableAnimations` — Dart API](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html).

Patrón para respetarlo globalmente, en vez de chequearlo animación por
animación (que es fácil de olvidar, como ya casi pasa en la web —
`globals.css:125-138` tuvo que aplicar el `!important` global precisamente
porque ya existían animaciones sueltas sin ese cuidado):

```dart
// lib/theme/reduced_motion.dart
import 'package:flutter/material.dart';

/// Envuelve toda la app (en MaterialApp.builder) y expone la preferencia
/// vía un InheritedWidget propio, para no repetir
/// MediaQuery.disableAnimationsOf(context) en cada widget de animación.
class ReducedMotionScope extends InheritedWidget {
  const ReducedMotionScope({
    super.key,
    required this.reduced,
    required super.child,
  });

  final bool reduced;

  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ReducedMotionScope>();
    return scope?.reduced ?? false;
  }

  @override
  bool updateShouldNotify(ReducedMotionScope oldWidget) => reduced != oldWidget.reduced;
}

// En MaterialApp:
MaterialApp(
  builder: (context, child) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ReducedMotionScope(reduced: reduced, child: child!);
  },
  // ...
)

/// Duración "consciente": 0 si el usuario pidió menos movimiento, igual que
/// animation-duration: 0.001ms !important en globals.css:131 (no se pone
/// Duration.zero literal para evitar que algún AnimationController se queje
/// de una duración de cero en casos borde; 1ms es el equivalente práctico).
Duration motionDuration(BuildContext context, Duration normal) {
  return ReducedMotionScope.of(context)
      ? const Duration(milliseconds: 1)
      : normal;
}
```

Uso concreto en el `TapCard` de §2 o en el sheet de §3:

```dart
AnimatedScale(
  scale: scale,
  duration: motionDuration(context, const Duration(milliseconds: 120)),
  curve: Curves.easeOut,
  child: ...,
)
```

Caso particular de los marcadores de mapa con pulso (`.zone-pulse`,
`.rescue-marker`, `.epi-ring` — `globals.css:409-551`, animaciones
`infinite`): en Flutter esos son `AnimationController(repeat())`; el patrón
correcto es no arrancar el `repeat()` en absoluto si `disableAnimations` es
true (dejar el marcador estático), no solo acortar la duración — igual que
la web, donde `animation-iteration-count: 1 !important` corta el loop
infinito por completo (`globals.css:130`).

**Nota adicional 2025-2026**: el motor de Flutter para **web** empezó a
escuchar el propio `prefers-reduced-motion` del navegador y a reflejarlo en
`AccessibilityFeatures`/`disableAnimations` (cambio reciente del equipo de
Flutter) — relevante solo si en algún momento se compila esta misma base de
Flutter también a web; no aplica a día de hoy porque el plan es
Android/iOS nativo [PR #180041 — flutter/flutter](https://github.com/flutter/flutter/pull/180041).

---

## 6. Transición "hero" tarjeta→ficha

Confirmado: es el equivalente directo. El widget se llama literalmente
`Hero` y resuelve exactamente el mismo problema que la View Transitions API
que usa la web (`src/lib/viewTransition.ts` + `view-transition-name` en
`PersonCard.tsx:24`) — animar una foto que cambia de tamaño/posición al
navegar entre dos pantallas, en vez de cortar en seco. Mismo concepto, dos
implementaciones nativas de cada plataforma: la web usa la API del
navegador (`document.startViewTransition`), Flutter usa `Navigator` +
`Hero` con matching por `tag` [Hero animations — docs.flutter.dev](https://docs.flutter.dev/ui/animations/hero-animations).

Cómo funciona: al hacer `Navigator.push`/`pop`, Flutter busca en la ruta de
origen y en la de destino un `Hero` con el mismo `tag`; si los encuentra,
calcula un tween que interpola tamaño y posición entre ambos y anima ese
widget en un `Overlay` por encima de la transición de rutas — la foto "vuela"
de la posición de la tarjeta a la posición en la ficha.

```dart
// Tarjeta (lista "Se busca") — equivalente a PersonCard.tsx:21-24, donde el
// viewTransitionName es `person-photo-${person.id}` (mismo patrón: un tag
// único por persona, no un tag genérico "photo" que colisionaría entre
// tarjetas visibles a la vez).
class PersonCard extends StatelessWidget {
  const PersonCard({super.key, required this.person});
  final Person person;

  @override
  Widget build(BuildContext context) {
    return TapCard(
      onTap: () => Navigator.of(context).push(
        IOSCurvedRoute(builder: (_) => PersonDetailScreen(person: person)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Hero(
              tag: 'person-photo-${person.id}', // mismo id que view-transition-name
              child: PersonPhoto(person: person), // ver PersonPhoto en §7 (alt text)
            ),
          ),
          // ... nombre, meta, ubicación (igual que PersonCard.tsx:63-97)
        ],
      ),
    );
  }
}

// Ficha (PersonDetailScreen) — el MISMO tag reaparece aquí; Flutter enlaza
// origen y destino automáticamente por coincidencia de tag durante el push.
class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({super.key, required this.person});
  final Person person;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Hero(
              tag: 'person-photo-${person.id}',
              child: PersonPhoto(person: person, large: true),
            ),
          ),
          // ... resto de la ficha
        ],
      ),
    );
  }
}
```

Detalles de fidelidad frente a la web:

- **Reduced motion**: `viewTransition.ts:20-24` cae a navegación normal si
  `prefers-reduced-motion: reduce`. `Hero` de Flutter **no respeta
  automáticamente** `disableAnimations` — hay que envolver el `Navigator`
  con un `PageTransitionsBuilder` custom o, más simple, chequear la
  preferencia antes de decidir si el `Hero` anima con duración normal o casi
  cero (mismo patrón `motionDuration` de §5, pero aplicado a
  `Hero(flightShuttleBuilder: ...)` si se necesita control fino, o
  simplemente asumiendo que `Hero` seguirá la duración de la ruta que lo
  contiene — que si se calcula con `motionDuration(context, ...)` ya hereda
  el recorte).
- **Curva**: por defecto `Hero` anima con `Curves.fastOutSlowIn`, no con
  `easeIOS`. Para que la foto "vuele" con la misma sensación que en la web,
  personalizar con `createRectTween` y una `Hero(flightShuttleBuilder:)` que
  use `easeIOS`, o aceptar la curva default de Material (`fastOutSlowIn` es
  razonablemente parecida, pero no idéntica al valor exacto de la marca).
- **Un solo `Hero` por pantalla con el mismo tag**: igual que la web, que
  usa un `viewTransitionName` único por persona para no colisionar cuando
  hay varias tarjetas visibles a la vez (`PersonCard.tsx:24`) — en Flutter
  el `tag` debe ser único por instancia visible simultáneamente en el árbol,
  mismo cuidado, mismo motivo.

---

## 7. Accesibilidad Flutter (equivalente a WCAG)

### `Semantics` — el "alt text sensible" en fotos de personas

La web ya resolvió esto con una regla explícita y ya implementada:
`PersonPhoto.tsx:33` construye el `alt` **solo con el nombre**
(`` `${firstName} ${lastName}`.trim() || "Persona" ``) — nunca describe rasgos
físicos, ropa, o estado de la persona. El comentario del propio componente
(`PersonPhoto.tsx:8-11`) también documenta el fallback elegante a iniciales
si la imagen falla, para que un lector de pantalla nunca reciba "imagen
rota" en un contexto tan sensible.

En Flutter, `Image` no tiene un atributo `alt` — la forma correcta es
envolver la imagen con `Semantics(label: ..., image: true)`, replicando
exactamente la misma regla de contenido (nombre, nunca descripción física):

```dart
class PersonPhoto extends StatelessWidget {
  const PersonPhoto({
    super.key,
    required this.photoUrl,
    required this.firstName,
    required this.lastName,
    required this.isUnidentified,
    this.large = false,
  });

  final String? photoUrl;
  final String firstName;
  final String lastName;
  final bool isUnidentified;
  final bool large;

  @override
  Widget build(BuildContext context) {
    // Misma regla que PersonPhoto.tsx:33: SOLO el nombre, nunca apariencia
    // física — en "¿La reconoces?" describir rasgos sería justo el tipo de
    // dato sensible que no debe ir en un alt text leído en voz alta.
    final label = '$firstName $lastName'.trim().isEmpty
        ? 'Persona'
        : '$firstName $lastName'.trim();

    return Semantics(
      label: label,
      image: true,
      child: photoUrl == null
          ? _InitialsFallback(
              text: isUnidentified ? '?' : _initials(firstName, lastName),
            )
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              // ExcludeSemantics evita que Image.network agregue SU PROPIA
              // semántica genérica (a veces "Image") duplicando el label de
              // arriba a los lectores de pantalla.
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) => _InitialsFallback(
                text: isUnidentified ? '?' : _initials(firstName, lastName),
              ),
            ),
    );
  }
}
```

Para íconos puramente decorativos (equivalente a `aria-hidden` en web, p. ej.
el ícono `MapPin` al lado de una ubicación que ya se lee como texto):
`Semantics(excludeSemantics: true, child: Icon(...))` o, más simple,
`ExcludeSemantics(child: Icon(...))` — evita que el lector de pantalla anuncie
dos veces la misma información (ícono + texto).

### Tamaño mínimo de objetivo táctil

| Guía | Mínimo | Fuente |
|---|---|---|
| Apple Human Interface Guidelines (iOS) | 44×44 pt | HIG — layout |
| Material Design 3 (Android) | 48×48 dp | M3 — Accessibility |
| WCAG 2.2 — 2.5.8 Target Size Minimum (AA) | 24×24 px CSS | ya citado en `docs/investigacion/08-accesibilidad-performance.md` M2 |

La diferencia entre 44pt y 48dp es de solo 4 unidades y ambas guías permiten
que el **ícono visual** sea más chico mientras el **área táctil real** llegue
al mínimo (mismo principio que WCAG 2.5.8, ya verificado como pendiente de
auditoría puntual en la web — `08-accesibilidad-performance.md` M2, sobre
botones de "me gusta"/reacciones en `CommentSection`/`PersonReactions`).
Recomendación práctica para Flutter, que ya cubre el peor caso (Android
48dp) y por lo tanto también el de iOS: envolver cualquier control pequeño
con un `SizedBox`/`ConstrainedBox` de mínimo 48×48 antes del contenido
visual, o usar `IconButton` de Material (que ya respeta el mínimo por
defecto vía `visualDensity` estándar) en vez de un `GestureDetector` sin
padding alrededor de un ícono de 16px suelto — ese es justo el error que
`08-accesibilidad-performance.md` M2 detectó como riesgo en la web.

```dart
// Patrón para un botón de reacción pequeño (equivalente a los íconos de
// "me gusta" de CommentSection en la web) que garantiza 48x48 táctil aunque
// el ícono visual sea de 16-18px.
SizedBox(
  width: 48,
  height: 48,
  child: IconButton(
    icon: const Icon(Icons.favorite_border, size: 18),
    onPressed: onLike,
    tooltip: 'Me gusta', // también sirve como label de accesibilidad
  ),
)
```

### Contraste — `brand-600` NO pasa AA como texto (confirmado en el repo web)

`docs/investigacion/08-accesibilidad-performance.md` (hallazgo M1) ya
calculó, con la fórmula estándar WCAG de luminancia relativa, que
`brand-600` (`#b96a3a`) sobre blanco da un contraste de **≈4.05:1**, lo cual
**falla** el mínimo AA para texto normal (4.5:1) aunque sí pasa para texto
grande (≥18pt/≥14pt-negrita, mínimo 3:1) y para componentes de UI no
textuales (mínimo 3:1). El caso real encontrado en la web es un contador
`"1/6"` de 11px en `OnboardingTour.tsx:520`, que técnicamente incumple 1.4.3.

**Implicación directa para Flutter/Dart**, reusando la misma paleta ya
verificada (no hay que recalcular nada, los valores hex son idénticos):

```dart
const brand500 = Color(0xFFD3824A); // fondo/CTA — OK como fondo con texto blanco
const brand600 = Color(0xFFB96A3A); // NO usar como texto normal sobre blanco (4.05:1, falla AA)
const brand700 = Color(0xFF9C552E); // SÍ pasa AA como texto (más oscuro que brand600)
```

Regla práctica para el equipo Flutter, calcada del fix ya propuesto en la
web (`08-accesibilidad-performance.md` M1: *"usar `text-brand-700` en vez de
`brand-600`"*): en cualquier `TextStyle` que use un tono de `brand-*` sobre
fondo claro, usar `brand700` (`#9c552e`) para texto de cuerpo/etiquetas
pequeñas, y reservar `brand500`/`brand600` para fondos (botones, badges) con
texto blanco encima, o para elementos de UI no textuales (bordes, íconos
grandes, indicadores). Esto evita que la app Flutter reintroduzca el mismo
hallazgo M1 que ya se detectó y quedó documentado en la web — la paleta es
compartida, así que el error sería fácil de copiar sin darse cuenta.

Otros puntos de WCAG 2.2 AA ya relevados en `08-accesibilidad-performance.md`
M2 y directamente trasladables a Flutter:

- **2.4.13 Focus Appearance** — en Flutter, el foco de teclado/control
  remoto (relevante si se soporta navegación por teclado externo o Android
  TV/accesibilidad) se controla con `FocusableActionDetector` o el
  `focusColor`/`overlayColor` de los widgets Material; no es un problema en
  táctil puro pero vale replicarlo si se agrega soporte de teclado físico.
- **2.5.7 Dragging Movements** — ya verificado como "cumplido" en la web
  para el selector de mapa (alternativa de un toque al arrastre del pin).
  Si `LocationPickerMap` se traduce a Flutter con `flutter_map` (ver
  `09-app-movil-flutter.md`), replicar el mismo patrón: tocar el mapa
  reposiciona el pin, no depender solo de arrastrar el marcador.

Fuentes de esta sección: [Semantics widget — practical guide](https://dcm.dev/blog/2025/06/30/accessibility-flutter-practical-tips-tools-code-youll-actually-use/),
[Material Design 3 — accessible touch targets](https://tetralogical.com/blog/2022/12/20/foundations-target-size/),
[Apple HIG — Layout](https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/).

---

## 8. Paquetes finales recomendados (`pubspec.yaml`)

| Paquete | Para qué | Razón en una línea |
|---|---|---|
| `google_fonts` | Signika + Figtree (ya en `04-tema-visual.md`) | Carga las mismas tipografías de la marca sin empaquetar archivos a mano |
| `flutter_animate` (opcional) | Efectos declarativos (fade, slide, scale) sobre `.animate-fade-in`/`.animate-rise`/`.stagger` de `globals.css:149-189` | Azúcar sintáctica sobre `AnimationController`; evita escribir un controller manual por cada micro-animación repetida en listas |
| `wolt_modal_sheet` (evaluar más adelante, no en Fase 0-1) | Si aparece un modal multi-paso real dentro de una sola hoja | Da look "iOS" con multi-página nativo; no adoptar antes de tener un caso concreto que `showModalBottomSheet` no resuelva bien (ver §3) |
| `flutter_map` | Mapa de crisis (ya decidido en `09-app-movil-flutter.md`) | Equivalente a Leaflet, mismos tiles, sin atarse a Google Maps |
| `flutter_secure_storage` | Sesión de Supabase Auth, token de gestión de recursos si se guarda localmente | Guarda en Keychain (iOS) / Keystore (Android) en vez de `SharedPreferences` plano — igual de sensible que un token de gestión de persona |
| `shared_preferences` | UUID de dispositivo para deduplicar votos/likes (ya en `09-app-movil-flutter.md`) | Equivalente directo a `localStorage` del patrón de voto por dispositivo |
| `flutter_image_compress` | Comprimir fotos antes de subir a Supabase Storage (ya en `09-app-movil-flutter.md`) | Equivalente a `compressImage` (`src/lib/image.ts:14`), JS/Canvas-only en la web |
| `supabase_flutter` | Backend (ya decidido en `01-arquitectura.md`) | SDK oficial, mismo proyecto Supabase, mismas políticas RLS |
| `go_router` | Navegación + deep links (ya en `09-app-movil-flutter.md`) | Necesario desde el día 1 por los enlaces de gestión con token (App Links/Universal Links) |
| `flutter_riverpod` | Estado (ya en `09-app-movil-flutter.md`) | Ya decidido en el roadmap, no se repite justificación |
| — (sin paquete, es SDK) | `Cubic`, `Hero`, `SafeArea`, `Semantics`, `MediaQuery.disableAnimationsOf`, `showModalBottomSheet` | Todo lo cubierto en las secciones 1, 4, 5, 6, 7 (base) es Flutter SDK puro — cero dependencias nuevas necesarias para tener paridad visual básica con la web |

**Conclusión clave**: de los 6 huecos identificados en
`05-fuente-web-existente.md` §5, **5 de 6 se resuelven con el SDK de Flutter
sin ninguna dependencia nueva** (curva custom, tap-card, safe area, reduced
motion, hero transition, accesibilidad básica) — la única decisión de
paquete real es bottom sheets, y ahí la recomendación es no adoptar
`wolt_modal_sheet` todavía (empezar con `showModalBottomSheet` +
`showDragHandle: true`, que ya cubre el 90% del look de `Modal.tsx` sin
dependencia extra).

---

## Fuentes

- [Cubic class — animation library, Dart API](https://api.flutter.dev/flutter/animation/Cubic-class.html)
- [Cubic.new constructor — Dart API](https://api.flutter.dev/flutter/animation/Cubic/Cubic.html)
- [Curves class — animation library, Dart API](https://api.flutter.dev/flutter/animation/Curves-class.html)
- [wolt_modal_sheet — pub.dev](https://pub.dev/packages/wolt_modal_sheet)
- [wolt_modal_sheet — repo oficial de Wolt en GitHub](https://github.com/woltapp/wolt_modal_sheet)
- [disableAnimations property — MediaQueryData class, Dart API](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)
- [Add support for reduced motion/disable animations on the web — PR #180041, flutter/flutter](https://github.com/flutter/flutter/pull/180041)
- [Hero animations — docs.flutter.dev](https://docs.flutter.dev/ui/animations/hero-animations)
- [Practical Accessibility in Flutter — DCM blog (2025)](https://dcm.dev/blog/2025/06/30/accessibility-flutter-practical-tips-tools-code-youll-actually-use/)
- [Foundations: target sizes — TetraLogical](https://tetralogical.com/blog/2022/12/20/foundations-target-size/)
- [All accessible touch target sizes — LogRocket Blog](https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/)
- [flutter_animate — pub.dev](https://pub.dev/packages/flutter_animate)
- Archivos del repo web citados (solo lectura, no modificados):
  `src/app/globals.css`, `src/components/Modal.tsx`, `src/components/Card.tsx`,
  `src/components/PersonCard.tsx`, `src/components/PersonPhoto.tsx`,
  `src/lib/viewTransition.ts`, `docs/investigacion/08-accesibilidad-performance.md`
