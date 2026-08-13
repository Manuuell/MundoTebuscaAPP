# 09 — Diseño tipo iOS: tab bar flotante, profundidad, bordes, transiciones y guía rápida

Profundiza donde `06-visual-accesibilidad.md` se quedó corto. Ese documento ya
cubre `--ease-ios`, `.tap-card`, bottom sheets (`showModalBottomSheet` vs
`wolt_modal_sheet`), `SafeArea`, `prefers-reduced-motion` → `disableAnimations`,
la transición hero tarjeta→ficha y accesibilidad (`Semantics`, contraste,
tamaño táctil). **No se repite nada de eso aquí.** Este documento cubre lo que
falta: tab bar flotante estilo iOS 26 (que la web **no tiene**, es una mejora
nueva para la app), el sistema de elevación completo (niveles 0/1/2, no solo
`.tap-card`), el patrón de tarjeta con borde reutilizable, animaciones de
entrada/cascada (`.animate-rise`, `.stagger`), botones con feedback de presión
fuera de tarjetas, y la guía rápida empaquetada offline.

Todo lo citado del repo web es real, con `archivo:línea`. No se tocó ningún
archivo de `C:\Users\angel\Desktop\Elmundotebusca` ni de
`C:\Users\angel\Desktop\MundoTebuscaAPP` — solo lectura.

---

## Tabla resumen: elemento web → traducción Flutter

| Elemento web (archivo:línea) | Qué es | Traducción Flutter | Estado |
|---|---|---|---|
| `MobileNav.tsx:150-153` (`fixed inset-x-0 bottom-0`, `border-t`) | Barra inferior pegada al borde, sin flotar, sin blur | Tab bar flotante con margen + `BackdropFilter` (glass) | **Mejora nueva**, la web no flota (ver §1) |
| `globals.css:83-87` (`--shadow-widget`, `--shadow-widget-hover`) | Sombra en capas ("lenguaje widget de iOS") | `BoxShadow` en capas, 3 niveles (0/1/2) como constantes Dart | Traducción directa (§2) |
| `Card.tsx` + `.tap-card` (`globals.css:235-253`, ya en doc 06) | Tarjeta con borde sutil + sombra difusa | `MTCard` reutilizable con `BoxDecoration` (borde XOR sombra dominante, no ambos fuertes) | Nuevo widget, mismo criterio visual (§3) |
| `globals.css:78-81` (`--ease-ios`) | Curva spring de UIKit | `Cubic(0.32, 0.72, 0, 1)` — ya definida en doc 06 §1 | Ya cubierto, se reusa (§4) |
| `.animate-rise`, `.stagger` (`globals.css:163-189`) | Entrada hacia arriba + cascada hasta 8 hijos | `flutter_animate` `.animate().fadeIn().slideY()` con `interval` | Traducción directa (§4) |
| `.hint-swipe` (`globals.css:191-208`) | Vaivén de 6px, insinúa fila deslizable | `AnimationController(repeat(reverse: true))` con `Tween` de ±6px | Traducción directa (§4) |
| `.press` (`globals.css:354-360`) | `scale(0.96)` al `:active` en botones sueltos (no tarjetas) | `AnimatedScale`/`GestureDetector` con `onTapDown/Up/Cancel` | Traducción directa (§5) |
| `src/lib/emergency.ts:23-33` (`COMMUNITY_GUIDE`) + `getEmergency(country)` | 9 pasos de guía + teléfonos por país | Asset JSON local embebido + bottom sheet accesible desde cualquier pantalla | Traducción directa (§6) |
| `SafetyBanner.tsx:77-84`, `MobileNav.tsx:38` (acceso a `/emergencias`) | Guía accesible vía banner y tab "SOS", no hay botón flotante persistente | Ícono fijo en la tab bar flotante (mismo patrón "SOS" que ya usa la web) | Confirmado: la web no tiene FAB persistente, usa la tab (§6) |

---

## 1. Tab bar flotante estilo iOS 26 (Liquid Glass)

### Qué dice Apple

Con iOS 26, Apple introdujo el material "Liquid Glass": la tab bar dejó de
estar pegada al borde inferior de la pantalla y ahora **flota** sobre el
contenido, dentro de una cápsula semitransparente con inset a los lados. La
guía oficial es explícita sobre el propósito: "Liquid Glass is best reserved
for the navigation layer that floats above the content of your app" — forma
una capa funcional separada (controles y navegación) que flota sobre la capa
de contenido, estableciendo jerarquía visual clara. El contenido puede
desplazarse y "asomarse" por debajo de esos elementos, dando sensación de
profundidad, sin perder legibilidad de los controles [Apple HIG / cobertura
de WWDC25 — ver fuentes]. En términos prácticos: los botones de Liquid Glass
en nav bars y toolbars quedan fijos mientras el contenido de la página se
desplaza por debajo; la tab bar concretamente pasó a ser una cápsula
horizontal separada del borde, no una franja pegada al fondo.

### Estado real en la web (confirmado, no flota)

`MobileNav.tsx:150-153` — la barra inferior de la web es:

```
className="pb-safe-nav fixed inset-x-0 bottom-0 z-40 border-t border-zinc-200 bg-white/95 backdrop-blur ..."
```

Es decir: ancho completo, pegada al borde (`inset-x-0 bottom-0`, sin margen),
con un simple `border-t` y `backdrop-blur` (blur del fondo, no glassmorphism
completo con reflejo/tinte). **No flota** — es la barra de navegación web
convencional, aunque ya tiene el detalle correcto de seguir el
`visualViewport` para no quedar tapada por el teclado (`MobileNav.tsx:89-104`)
y un indicador deslizante de sección activa con `--ease-ios`
(`MobileNav.tsx:158-166`). El pedido del usuario de una tab bar "flotante" es,
por tanto, una **mejora nueva para la app** respecto a lo que ya existe en la
web, no una migración 1:1 — aprovechando que en una app nativa sí se puede
seguir el lenguaje visual actual de iOS sin las limitaciones de CSS `fixed`
que documenta el propio comentario del código (`MobileNav.tsx:82-88`, sobre
el bug de Chrome Android con `fixed` y la barra de direcciones).

### Cómo lograrlo en Flutter

Dos caminos, igual que en la comparación de bottom sheets del doc 06 §3:

**A. `CupertinoTabBar` nativo** — da semántica iOS estándar (SF Symbols,
comportamiento de "tap en tab activo para volver arriba"), pero **no flota**
por defecto: se renderiza pegado al borde igual que `BottomNavigationBar` de
Material. Para flotar hay que envolverlo manualmente en un `Container` con
margen y clip — pierde parte de la ventaja de "usar el widget nativo tal
cual".

**B. Widget custom flotante con `BackdropFilter`** — la ruta recomendada,
porque replica el patrón real de iOS 26 (cápsula con inset + blur + tinte) y
es la que usan los paquetes de comunidad que ya implementan Liquid Glass en
Flutter (`liquid_glass_widgets`, `cupertino_liquid_glass`,
`glass_liquid_navbar` — ver Fuentes). El patrón base de todos ellos es el
mismo: `Positioned` con margen desde los bordes (no `bottom: 0`) → `ClipRRect`
con `borderRadius` grande (cápsula) → `BackdropFilter` con `ImageFilter.blur`
→ `Container` semitransparente encima con los ítems de navegación. Ojo con el
costo: `BackdropFilter` con blur es un filtro "no local" (repinta todo lo que
hay debajo cada frame que cambia), documentado como relativamente costoso —
para una tab bar que no se anima constantemente el costo es aceptable, pero
no debe combinarse con contenido que se desplaza muy rápido detrás si el
dispositivo es de gama baja.

```dart
// lib/widgets/floating_tab_bar.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Tab bar flotante estilo iOS 26 (Liquid Glass). A diferencia de
/// MobileNav.tsx (web), que va pegada al borde inferior sin margen
/// (`inset-x-0 bottom-0`, MobileNav.tsx:150-153), esta flota con inset
/// lateral e inferior — mejora nueva para la app, la web no la tiene.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<({IconData icon, String label})> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 12 + bottomInset, // flota, no toca el borde (a diferencia de MobileNav.tsx)
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28), // cápsula, no franja recta
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72), // tinte translúcido
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              boxShadow: const [
                // mismo espíritu que --shadow-widget-hover (globals.css:86):
                // sombra difusa y baja, no un shadow-2xl plano.
                BoxShadow(
                  color: Color(0x1E101828), // rgba(16,24,40,.12)
                  blurRadius: 32,
                  offset: Offset(0, 16),
                  spreadRadius: -12,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < items.length; i++)
                  _TabItem(
                    icon: items[i].icon,
                    label: items[i].label,
                    active: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Nota de diseño: Apple reserva Liquid Glass **para la capa de navegación**, no
para botones de acción dentro del contenido — "no la uses para separar
elementos dentro de la misma capa funcional" es la advertencia repetida en
las guías (ver artículo "Don't Design Junk in the New iOS 26 Tab Bar" en
Fuentes). Aplicado a esta app: el efecto glass va en la tab bar y quizás en
un `AppBar` que flote sobre un mapa o una foto grande (como el header de la
ficha de persona), **no** en cada `MTCard` de una lista — eso sería
sobrecargar el mismo lenguaje visual en dos capas distintas y perdería la
jerarquía que el propio material está diseñado para comunicar.

Dónde va el ícono de "SOS"/guía rápida dentro de esta tab bar: igual que en
`MobileNav.tsx:38` (`{ href: "/emergencias", label: "SOS", icon: LifeBuoy }`),
como un ítem fijo más — no un FAB aparte. Ver §6 para el detalle de la guía.

---

## 2. Sistema de profundidad/elevación (niveles 0/1/2)

La web define solo dos sombras con nombre (`--shadow-widget`,
`--shadow-widget-hover`, `globals.css:83-86`) más una tercera para hojas
(`--shadow-sheet`, `globals.css:87`, usada en `Modal.tsx:151`). Para Flutter
conviene declarar esto como un sistema explícito de 3 niveles en vez de dos
constantes sueltas, porque una app nativa tiene más superficies que la web
(tab bar flotante, `AppBar`, sheets, cards, botones) y conviene que cada una
sepa a qué nivel pertenece sin reinventar valores.

```dart
// lib/theme/elevation.dart
import 'package:flutter/material.dart';

/// Traducción 1:1 de los valores de sombra de globals.css:83-87.
/// Los valores rgba/px se mantienen idénticos (no se "redondea" a un
/// valor de Material Design genérico) para que la sensación de profundidad
/// sea la misma que en la web.
abstract final class MTElevation {
  /// Nivel 0 — plano. Fondos de pantalla, separadores, texto. Sin sombra.
  static const List<BoxShadow> flat = [];

  /// Nivel 1 — card en reposo. Igual que --shadow-widget (globals.css:85):
  /// 0 1px 2px rgba(16,24,40,.04), 0 8px 24px -8px rgba(16,24,40,.12)
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x1E101828),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -8,
    ),
  ];

  /// Nivel 1-hover — tarjeta elevada (hover desktop / prensa). Igual que
  /// --shadow-widget-hover (globals.css:86).
  static const List<BoxShadow> cardHover = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(
      color: Color(0x2E101828),
      blurRadius: 32,
      offset: Offset(0, 16),
      spreadRadius: -12,
    ),
  ];

  /// Nivel 2 — modal/sheet/tab bar flotante. Igual que --shadow-sheet
  /// (globals.css:87), sombra hacia arriba (offset negativo en Y) porque
  /// la hoja sube desde abajo. Para la tab bar flotante (§1, offset
  /// positivo) se reusa cardHover en vez de este.
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, -4)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, -1)),
  ];
}
```

Confirmación del criterio "sombra en capas, no un `shadow-2xl` plano": el
comentario del propio CSS lo dice explícito (`globals.css:83-84`, "más suaves
que un shadow-2xl plano — el lenguaje 'widget' de iOS"), y coincide con la
práctica documentada de diseño de sombras: un objeto flotante en la vida real
proyecta una sombra de contacto cercana y nítida **más** una sombra ambiental
suave y difusa — no una sola sombra uniforme. Material Design codifica esto
mismo con dos capas por nivel de elevación (ver Fuentes). Por eso cada
constante de arriba tiene dos `BoxShadow`, no una.

Regla de uso: nivel 0 para el `Scaffold`/fondo, nivel 1 para `MTCard` en
reposo (§3), `cardHover`/scale al presionar para el feedback táctil (igual
que `.tap-card:hover`/`:active`, ya en doc 06 §2), nivel 2 para
`showModalBottomSheet` y la tab bar flotante.

---

## 3. Widget de tarjeta con bordes (`MTCard`)

El error visual típico al portar "bordes + sombra" de CSS a Flutter sin
cuidado es aplicar **ambos con la misma intensidad**: un borde marcado (1-2px
sólido) más una sombra fuerte se ve recargado — "muchos efectos encima" en
vez de un widget limpio. La web evita esto con un borde muy sutil
(`border-zinc-200`, gris casi imperceptible) que solo define el límite del
widget en fondos claros, y deja que la **sombra** sea la que comunica
profundidad (`.tap-card`, `globals.css:237-238`, ya documentado en doc 06 §2).
El mismo criterio debe mantenerse en Flutter: un borde de 1px muy claro
(`zinc-200` ≈ `#E4E4E7`, ya usado en el `TapCard` de doc 06 §2) nunca a la vez
que una sombra de nivel 2 — si el widget necesita una sombra fuerte (nivel 2,
p. ej. un sheet), se quita el borde; si necesita borde marcado (p. ej. un
estado de error), se baja la sombra a nivel 0.

```dart
// lib/widgets/mt_card.dart
import 'package:flutter/material.dart';
import '../theme/elevation.dart';

/// Tarjeta base reutilizable. Radio de 24px (rounded-3xl, mismo valor que
/// Card.tsx y el TapCard de doc 06 §2) — consistente en todo el sistema:
/// no mezclar rounded-2xl (16px) y rounded-3xl (24px) según el componente,
/// la web ya estandarizó en 24 para tarjetas de contenido.
class MTCard extends StatelessWidget {
  const MTCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.elevated = false, // true = cardHover (nivel 1 alto), no combinar con borde marcado
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool elevated;
  final Color? borderColor;

  static const _radius = 24.0;
  static const _borderSubtle = Color(0xFFE4E4E7); // zinc-200

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: borderColor ?? _borderSubtle, width: 1),
        boxShadow: elevated ? MTElevation.cardHover : MTElevation.card,
      ),
      child: child,
    );
  }
}
```

`MTPersonCard`, `MTAidPointCard`, etc. componen sobre `MTCard` (no la
reimplementan) — mismo patrón que la web, donde `PersonCard.tsx` envuelve el
`.tap-card` genérico en vez de declarar su propio `box-shadow`.

---

## 4. Transiciones y animaciones

### Curva `--ease-ios`

Ya definida en doc 06 §1 (`const Curve easeIOS = Cubic(0.32, 0.72, 0, 1)`,
`lib/theme/motion.dart`) — se reusa aquí para las animaciones de hoja/página,
no se repite la explicación técnica.

### Entrada `.animate-rise` y cascada `.stagger`

`globals.css:163-189` — entrada de tarjetas hacia arriba
(`fade-in-up`, `translateY(10px)` → `0`, 0.4s, curva
`cubic-bezier(0.22, 1, 0.36, 1)`, **no** `--ease-ios` — la web separa
"entrada de contenido" de "hojas/navegación", mismo criterio que ya notó doc
06 §1 para `.press`) con retrasos escalonados de 0.02s a 0.3s para hasta 8
hijos (`.stagger > *:nth-child(1..8)`).

El paquete `flutter_animate` (ya recomendado en doc 06 §8, tabla de
paquetes) resuelve esto de forma declarativa con `.animate()` encadenado, y
soporta `interval` en `AnimateList` para escalonar automáticamente una lista
completa sin escribir el `nth-child` a mano:

```dart
import 'package:flutter_animate/flutter_animate.dart';

// Una tarjeta suelta — equivalente a .animate-rise (globals.css:175-177)
MTCard(child: content)
    .animate()
    .fadeIn(duration: 400.ms, curve: const Cubic(0.22, 1, 0.36, 1))
    .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: const Cubic(0.22, 1, 0.36, 1));

// Una grilla/lista — equivalente a .stagger (globals.css:178-189):
// AnimateList aplica el mismo efecto a cada hijo con un retraso creciente.
AnimateList(
  interval: 40.ms, // ~ el paso de 0.02s-0.04s entre nth-child en la web
  effects: [
    FadeEffect(duration: 400.ms, curve: const Cubic(0.22, 1, 0.36, 1)),
    SlideEffect(begin: const Offset(0, 0.1), end: Offset.zero, duration: 400.ms),
  ],
  children: [for (final p in personas) MTPersonCard(person: p)],
)
```

Diferencia a tener en cuenta: la web tope explícitamente en 8 elementos
(`.stagger` solo define `nth-child(1)` a `nth-child(8)`; del noveno en
adelante no hay retraso, aparecen todos a la vez) — con `AnimateList` el
`interval` se aplica a **todos** los hijos por defecto, así que si la lista
puede tener más de 8-10 elementos conviene capar el `interval` a 0 pasado
cierto índice (o limitar el efecto a los primeros N con
`ListView.builder` + una condición), para no terminar con la última tarjeta
de una lista de 40 apareciendo casi un segundo después que la primera.

### `.hint-swipe`

`globals.css:191-208` — vaivén constante de ±6px (no un carrusel que recorre
toda la fila, el comentario del código explica por qué: para no pelear con el
scroll manual del usuario, `globals.css:191-198`) para insinuar que una fila
es deslizable. Traducción con un `AnimationController` en loop:

```dart
class HintSwipe extends StatefulWidget {
  const HintSwipe({super.key, required this.child});
  final Widget child;
  @override
  State<HintSwipe> createState() => _HintSwipeState();
}

class _HintSwipeState extends State<HintSwipe> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600), // mismo 2.6s que hint-swipe
  );
  late final _offset = Tween<double>(begin: 0, end: -6).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    // Igual que doc 06 §5: si el usuario pidió menos movimiento, NO arrancar
    // el loop infinito en absoluto (no solo acortarlo) — mismo criterio que
    // .zone-pulse/.rescue-marker.
    if (!MediaQuery.disableAnimationsOf(context)) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(
        offset: Offset(_offset.value, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}
```

### `.reveal-up` (`animation-timeline: view()`)

`globals.css:210-233` — es una animación **guiada por scroll** nativa de CSS,
sin JS, soportada solo en navegadores Chromium recientes (`@supports
(animation-timeline: view())`, con fallback silencioso a contenido visible
normal donde no hay soporte). Flutter no tiene un equivalente de un solo
widget para "animar según la posición de scroll de forma declarativa" — el
camino es `NotificationListener<ScrollNotification>` o
`VisibilityDetector` (paquete) combinado con un `AnimationController` que se
adelanta/retrocede según qué tan visible está el widget. Es más código que en
CSS porque ahí es una feature de plataforma; en Flutter hay que construirla a
mano. Dado que es un efecto puramente decorativo (revelado al hacer scroll en
listas largas del inicio web) y no crítico para la función humanitaria de la
app, se recomienda **no priorizarlo** en las primeras fases — no aparece en
ninguno de los flujos críticos (publicar persona, ver ficha, contactar
ayuda), es solo pulido visual de la página de inicio web.

---

## 5. Botones con profundidad y feedback táctil (fuera de tarjetas)

`.press` (`globals.css:354-360`) es distinto de `.tap-card` (doc 06 §2): se
aplica a botones sueltos (íconos, chips, ítems de la tab bar —
`MobileNav.tsx:177`, `:196` usan la clase `press` en los `<Link>`/`<button>`
de cada tab), no a tarjetas con sombra. Es más simple: solo
`scale(0.96)` al `:active`, sin elevación ni cambio de sombra.

```dart
// lib/widgets/press.dart
import 'package:flutter/material.dart';

/// Equivalente a .press (globals.css:354-360): feedback de "presión" para
/// controles sueltos (íconos, ítems de tab bar, chips) — más simple que
/// TapCard (doc 06 §2), sin sombra ni elevación, solo escala.
class Press extends StatefulWidget {
  const Press({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0, // mismo valor que .press:active
        duration: const Duration(milliseconds: 120), // ~0.12s de globals.css:356
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
```

Alternativa con `flutter_animate` si se prefiere no mantener un
`StatefulWidget` propio por control: el paquete expone `.animate(
onPlay: ...)` con `TapEffect`/gestos combinables, pero para un caso tan
puntual como este (un solo `AnimatedScale` con dos estados) el widget manual
de arriba es más simple y no añade una dependencia solo para esto — criterio
igual al que ya usó doc 06 §2 sobre no adoptar dependencias "por si acaso".

Dónde aplicarlo en la tab bar flotante de §1: cada `_TabItem` de
`FloatingTabBar` debe envolver su ícono+label en `Press`, igual que
`MobileNav.tsx:176-183` aplica `className="press ..."` a cada `<Link>` de
tab — mantiene la paridad de feedback táctil entre web y app en el mismo
control.

---

## 6. Guía rápida empaquetada (offline, multi-país)

### Contenido real de la web

`src/lib/emergency.ts:23-33` — `COMMUNITY_GUIDE` es un array de **9 strings**
(no genérico, contenido real de emergencia: ponerse a salvo, revisar heridas,
gas/electricidad, no usar ascensores, avisar sin llamar, tener agua/linterna/
medicinas/documentos, punto de encuentro familiar, no difundir rumores,
ayudar a vecinos vulnerables). `getEmergency(country)` (`emergency.ts:18-20`)
delega en `getCountry(country)` (`src/lib/countries.ts`, no citado aquí en
detalle porque ya lo cubre `08-multi-pais.md`) para devolver `nationalLine` y
`groups` (líneas de bomberos, cruz roja, etc.) específicos de cada país. La
guía se renderiza en `src/app/emergencias/page.tsx:187` (`COMMUNITY_GUIDE.map`).

### Cómo se accede hoy (confirmado: no hay FAB persistente)

No existe un botón flotante persistente dedicado a la guía en ninguna
pantalla. El acceso es vía:
- Tab "SOS" en la barra inferior móvil (`MobileNav.tsx:38`,
  `{ href: "/emergencias", label: "SOS", icon: LifeBuoy }`).
- Ítem "Emergencias" en la barra superior de escritorio (`SiteHeader.tsx:31`).
- Banner de seguridad en el layout raíz, que enlaza a `/emergencias` con el
  teléfono nacional visible (`SafetyBanner.tsx:77-84`).
- `OnboardingTour.tsx:31` la menciona explícitamente en el primer paso del
  recorrido guiado ("Una guía rápida para que sepas dónde está todo...").

Para Flutter esto se traduce naturalmente: el ítem "SOS" ya forma parte de la
`FloatingTabBar` de §1 (mismo lugar que ya usa la web), así que **no hace
falta inventar un FAB adicional** — sería redundante con la tab bar flotante
y competiría visualmente con ella (dos elementos "flotantes" distintos en la
misma pantalla). Si se quiere refuerzo adicional, un banner tipo
`SafetyBanner` (arriba de la lista, no flotante) es más fiel al patrón web
que un FAB nuevo.

### Empaquetado offline

Crítico para una app de emergencia: la guía **no debe depender de red**. La
web ya la sirve como código estático (un array TS compilado en el bundle,
sin fetch a ninguna API), así que el equivalente correcto en Flutter es un
asset embebido en el paquete de la app (no una llamada a Supabase), para que
funcione incluso sin señal — el escenario más probable justo cuando se
necesita esta pantalla.

```json
// assets/guides/community_guide.json
{
  "steps": [
    "Ponte a salvo: aléjate de estructuras dañadas, vidrios y postes. Pueden venir réplicas.",
    "Revisa si tú y los tuyos están heridos. Da primeros auxilios básicos.",
    "Si hueles gas, cierra la llave y no enciendas nada. Corta la electricidad si ves cables sueltos.",
    "No uses ascensores. Baja por las escaleras con cuidado.",
    "Avisa que estás a salvo con un solo mensaje (no llames: satura la red). Puedes hacerlo aquí mismo.",
    "Ten a mano agua, linterna, medicinas y tus documentos.",
    "Acuerda un punto de encuentro con tu familia por si se separan.",
    "No difundas rumores: verifica antes de compartir.",
    "Ayuda a vecinos vulnerables: adultos mayores, niños y personas con discapacidad."
  ]
}
```

```json
// assets/guides/emergency_lines/ve.json (un archivo por país, mismo criterio
// que 08-multi-pais.md — un país = un archivo/registro, no un switch gigante)
{
  "country": "VE",
  "nationalLine": { "number": "911", "label": "Línea única de emergencia" },
  "groups": [
    { "label": "Bomberos", "number": "0212-5411111" },
    { "label": "Cruz Roja", "number": "0212-5715555" }
  ]
}
```

```dart
// lib/features/guide/guide_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Repositorio 100% local — nunca hace fetch. Coincide con el criterio de
/// la web (COMMUNITY_GUIDE es código estático, no un endpoint,
/// emergency.ts:23-33), reforzado aquí porque en la app la conectividad
/// puede faltar justo cuando esta pantalla es más necesaria.
class GuideRepository {
  Future<List<String>> loadCommunityGuide() async {
    final raw = await rootBundle.loadString('assets/guides/community_guide.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return (data['steps'] as List).cast<String>();
  }

  /// Equivalente a getEmergency(country) (emergency.ts:18-20): un archivo
  /// por código de país, mismo patrón ya usado por 08-multi-pais.md.
  Future<EmergencyInfo> loadEmergency(String countryCode) async {
    final raw = await rootBundle
        .loadString('assets/guides/emergency_lines/${countryCode.toLowerCase()}.json');
    return EmergencyInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
```

Declarar los assets en `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/guides/community_guide.json
    - assets/guides/emergency_lines/
```

### Presentación: bottom sheet, no pantalla nueva

Dado que ya existe el patrón de sheet de doc 06 §3
(`showModalBottomSheet` + `showDragHandle: true` + `easeIOS`), la guía rápida
encaja mejor como sheet que como una ruta de pantalla completa nueva — es
contenido corto (9 pasos + un teléfono), y un sheet se puede invocar desde
**cualquier** pantalla (el criterio explícito del pedido del usuario:
"accesible desde cualquier pantalla") sin salir del contexto donde el usuario
estaba. Se abre desde el ítem "SOS" de la `FloatingTabBar` (§1) usando el
mismo `showIOSSheet` ya definido en doc 06 §3:

```dart
void openQuickGuide(BuildContext context) {
  showIOSSheet(
    context,
    FutureBuilder(
      future: GuideRepository().loadCommunityGuide(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        final steps = snapshot.data!;
        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          itemCount: steps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 12, child: Text('${i + 1}')),
              const SizedBox(width: 12),
              Expanded(child: Text(steps[i])),
            ],
          ),
        );
      },
    ),
  );
}
```

---

## Fuentes

- [Liquid Glass — Apple Human Interface Guidelines / cobertura de WWDC25](https://developer.apple.com/videos/play/wwdc2025/284/)
- [Don't Design Junk in the New iOS 26 Tab Bar — Medium/Bootcamp](https://medium.com/design-bootcamp/dont-design-junk-in-the-new-ios-26-tab-bar-4de8e842da89)
- [iOS 26 Liquid Glass UI Guide: SwiftUI glassEffect API — Medium](https://vikramios.medium.com/the-liquid-glass-ui-revolution-everything-ios-developers-need-to-know-right-now-e29144a5e88a)
- [iOS 26 Design Guidelines: Illustrated Patterns — LearnUI](https://www.learnui.design/blog/ios-design-guidelines-templates.html)
- [liquid_glass_widgets — pub.dev](https://pub.dev/packages/liquid_glass_widgets)
- [liquid_glass_widgets — repo GitHub, sdegenaar](https://github.com/sdegenaar/liquid_glass_widgets)
- [cupertino_liquid_glass — pub.dev](https://pub.dev/packages/cupertino_liquid_glass)
- [glass_liquid_navbar — pub.dev](https://pub.dev/packages/glass_liquid_navbar)
- [liquid_glass_floating_nav — pub.dev](https://pub.dev/packages/liquid_glass_floating_nav)
- [We Shipped Liquid Glass in Our Flutter Fintech App — Medium](https://medium.com/@furkanacardev/we-shipped-liquid-glass-in-our-flutter-fintech-app-heres-what-we-learned-ba381c13e3cc)
- [Flutter NavigationBar vs TabBar vs BottomNavigationBar: The 2026 Production Guide — GetWidget](https://www.getwidget.dev/blog/flutter-navigation-bar/)
- [bottom_cupertino_tabbar — pub.dev](https://pub.dev/packages/bottom_cupertino_tabbar)
- [BackdropFilter class — widgets library, Dart API](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)
- [A Comprehensive Guide to Flutter's BackdropFilter — DhiWise](https://www.dhiwise.com/post/how-to-use-flutter-backdropfilter-for-stunning-ui-backgrounds)
- [`BackdropFilter` samples outside clip bounds — Issue #173530, flutter/flutter](https://github.com/flutter/flutter/issues/173530)
- [flutter_animate — pub.dev](https://pub.dev/packages/flutter_animate)
- [flutter_staggered_animations — Dart API docs](https://pub.dev/documentation/flutter_staggered_animations/latest/)
- [Staggered animations — docs.flutter.dev](https://docs.flutter.dev/ui/animations/staggered-animations)
- [Shadows and Neumorphism in Flutter — Medium/Flutter Community](https://medium.com/flutter-community/shadows-and-neumorphism-in-flutter-703a3e500503)
- [Depth → Shadow Tokens — Shopify Polaris (referencia de sistema de sombras en capas)](https://polaris.shopify.com/design/depth/shadow-tokens)
- Archivos del repo web citados (solo lectura, no modificados):
  `src/app/globals.css`, `src/components/MobileNav.tsx`,
  `src/components/SafetyBanner.tsx`, `src/components/Modal.tsx`,
  `src/components/OnboardingTour.tsx`, `src/components/SiteHeader.tsx`,
  `src/lib/emergency.ts`, `src/app/emergencias/page.tsx`
