import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Ayuda y hospitales. Cuelga de la hoja "Mas" (`AYUDA_PATHS`).
class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y hospitales')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pendiente: puntos de ayuda y hospitales con su consenso de '
            'disponibilidad (Fase 1).',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}
