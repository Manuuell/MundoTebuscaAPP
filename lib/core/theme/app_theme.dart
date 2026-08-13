import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tema de la app: Signika para encabezados, Figtree para cuerpo — las mismas
/// dos familias que la web (`--font-heading` / `--font-sans`), cargadas por
/// `google_fonts` para no empaquetar los ttf a mano.
ThemeData buildAppTheme() {
  final heading = GoogleFonts.signika(
    color: AppColors.navy700,
    fontWeight: FontWeight.w600,
  );
  final body = GoogleFonts.figtree(color: AppColors.fgBase);

  final colorScheme = const ColorScheme.light(
    primary: AppColors.brand500,
    onPrimary: Colors.white,
    secondary: AppColors.navy700,
    onSecondary: Colors.white,
    error: AppColors.danger500,
    surface: Colors.white,
    onSurface: AppColors.fgBase,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.bgBase,
    textTheme: GoogleFonts.figtreeTextTheme().copyWith(
      headlineLarge: heading.copyWith(fontSize: 28),
      headlineMedium: heading.copyWith(fontSize: 22),
      titleLarge: heading.copyWith(fontSize: 18),
      bodyLarge: body,
      bodyMedium: body,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgBase,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: heading.copyWith(fontSize: 20),
      iconTheme: const IconThemeData(color: AppColors.navy700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.brand50,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return GoogleFonts.figtree(
          fontSize: 11,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          color: active ? AppColors.brand700 : AppColors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
          color: active ? AppColors.brand700 : AppColors.muted,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand500,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy700,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
  );
}
