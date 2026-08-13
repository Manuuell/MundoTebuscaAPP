import 'package:flutter/material.dart';

/// Paleta de la marca.
///
/// Los hex salen tal cual de `src/app/globals.css:3-76` del repo web — no son
/// aproximaciones. Si cambian alla, cambian aqui.
class AppColors {
  const AppColors._();

  // Marca (terracota)
  static const brand500 = Color(0xFFD3824A); // CTAs, focos, enlaces
  static const brand700 = Color(0xFF9C552E); // texto/icono activo
  static const brand50 = Color(0xFFFDF3EC); // fondo suave de estado activo

  // Navy
  static const navy700 = Color(0xFF1D1B40); // texto de marca, fondos oscuros

  // Semanticos: los mismos que usan las insignias de consenso en la web
  // ("si hay" / "se acabo") y los estados de persona.
  static const success500 = Color(0xFF10B981);
  static const warning500 = Color(0xFFF59E0B);
  static const danger500 = Color(0xFFF43F5E);
  static const info500 = Color(0xFF0EA5E9);

  // Base
  static const bgBase = Color(0xFFF8FAFC);
  static const fgBase = Color(0xFF18181B);

  /// Gris de apoyo para textos secundarios y bordes. No viene de globals.css;
  /// es un derivado local para no repetir `withValues` por toda la UI.
  static const muted = Color(0xFF71717A);
  static const border = Color(0xFFE4E4E7);
}
