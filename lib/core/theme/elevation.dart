import 'package:flutter/material.dart';

/// Sistema de profundidad en 3 niveles.
///
/// Traduccion 1:1 de las sombras de `globals.css:83-87` del repo web. Los
/// valores rgba/px se mantienen identicos en vez de redondearse a una
/// elevacion generica de Material, para que la sensacion de profundidad sea la
/// misma que en el sitio.
///
/// Cada nivel lleva DOS sombras, no una: un objeto flotante proyecta una
/// sombra de contacto cercana y nitida mas una ambiental suave y difusa. El
/// propio CSS lo dice — "mas suaves que un shadow-2xl plano, el lenguaje
/// widget de iOS".
abstract final class MTElevation {
  /// Nivel 0 — plano. Fondos, separadores, texto.
  static const List<BoxShadow> flat = [];

  /// Nivel 1 — tarjeta en reposo (`--shadow-widget`).
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x1E101828),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -8,
    ),
  ];

  /// Nivel 1 alto — tarjeta elevada o presionada (`--shadow-widget-hover`).
  static const List<BoxShadow> cardHover = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(
      color: Color(0x2E101828),
      blurRadius: 32,
      offset: Offset(0, 16),
      spreadRadius: -12,
    ),
  ];

  /// Nivel 2 — hoja modal (`--shadow-sheet`). La sombra va hacia ARRIBA
  /// (offset negativo en Y) porque la hoja sube desde abajo. La tab bar
  /// flotante NO usa esta: reusa `cardHover`, que proyecta hacia abajo.
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, -4)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, -1)),
  ];
}

/// Curvas de animacion.
abstract final class MTMotion {
  /// `--ease-ios` (`globals.css:78-81`): la curva spring de UIKit. Para hojas
  /// y navegacion.
  static const easeIOS = Cubic(0.32, 0.72, 0, 1);

  /// Curva de entrada de contenido (`.animate-rise`, `globals.css:163-189`).
  /// La web separa a proposito "entrada de contenido" de "hojas/navegacion" y
  /// usa una curva distinta para cada cosa.
  static const entrada = Cubic(0.22, 1, 0.36, 1);

  static const duracionEntrada = Duration(milliseconds: 400);

  /// Paso entre hijos de una cascada. La web escalona hasta 8 hijos y del
  /// noveno en adelante entran todos a la vez, para que el ultimo de una lista
  /// larga no aparezca un segundo despues que el primero.
  static const pasoCascada = Duration(milliseconds: 40);
  static const maxCascada = 8;
}
