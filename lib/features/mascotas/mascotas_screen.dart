import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Mascotas perdidas y encontradas. Cuelga de la hoja "Mas".
class MascotasScreen extends StatelessWidget {
  const MascotasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mascotas')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pendiente: mascotas perdidas y encontradas (Fase 1).',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}
