# 4. Tema visual

Valores reales tomados de `src/app/globals.css:3-76` en el repo web — no son
aproximados, son los mismos hex que ya usa la marca.

- **Marca (terracota)**: `brand-500 #d3824a` (CTAs, focos, enlaces),
  `brand-700 #9c552e` (texto/ícono activo), `brand-50 #fdf3ec` (fondos suaves
  de estado activo).
- **Navy**: `navy-700 #1d1b40` (texto de marca, fondos oscuros).
- **Semánticos**: `success-500 #10b981`, `warning-500 #f59e0b`,
  `danger-500 #f43f5e`, `info-500 #0ea5e9` — mismos que usan las insignias de
  consenso ("sí hay"/"se acabó") y estados en la web.
- **Fondo/texto base**: `#f8fafc` / `#18181b`.
- **Tipografías**: Signika para encabezados (`--font-heading`), Figtree para
  cuerpo (`--font-sans`) — ambas cargables en Flutter vía el paquete
  `google_fonts`, sin tener que empaquetar los archivos a mano.

## Punto de partida para `ThemeData` (Flutter)

Sin verificar en un proyecto real todavía — es el mapeo directo de los valores
de arriba, para no arrancar con una paleta inventada el primer día:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const brand500 = Color(0xFFD3824A);
const brand700 = Color(0xFF9C552E);
const brand50 = Color(0xFFFDF3EC);
const navy700 = Color(0xFF1D1B40);
const success500 = Color(0xFF10B981);
const warning500 = Color(0xFFF59E0B);
const danger500 = Color(0xFFF43F5E);
const info500 = Color(0xFF0EA5E9);
const bgBase = Color(0xFFF8FAFC);
const fgBase = Color(0xFF18181B);

ThemeData buildAppTheme() {
  final headingStyle = GoogleFonts.signika(color: navy700, fontWeight: FontWeight.w600);
  final bodyStyle = GoogleFonts.figtree(color: fgBase);

  return ThemeData(
    scaffoldBackgroundColor: bgBase,
    colorScheme: ColorScheme.light(
      primary: brand500,
      onPrimary: Colors.white,
      secondary: navy700,
      onSecondary: Colors.white,
      error: danger500,
      surface: Colors.white,
      onSurface: fgBase,
    ),
    textTheme: GoogleFonts.figtreeTextTheme().copyWith(
      headlineLarge: headingStyle.copyWith(fontSize: 28),
      headlineMedium: headingStyle.copyWith(fontSize: 22),
      titleLarge: headingStyle.copyWith(fontSize: 18),
      bodyLarge: bodyStyle,
      bodyMedium: bodyStyle,
    ),
    // "sí hay" / "se acabó", estados de persona, etc. — no son parte del
    // ColorScheme estándar de Material, se referencian aparte como
    // constantes (brand50/success500/warning500/danger500/info500) donde
    // haga falta, igual que la web declara sus propios --color-success-*, etc.
  );
}
```

Mockups de referencia (pantalla Inicio + barra inferior de 5 tabs, con estos
colores/tipografías reales) se generaron durante la sesión de planeación —
sirven de punto de partida visual, no de diseño final aprobado.
