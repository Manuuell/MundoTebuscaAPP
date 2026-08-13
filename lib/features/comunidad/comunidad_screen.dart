import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Comunidad.
///
/// Agrupa voluntarios, caravanas y denuncias — no son tabs propios, son
/// subsecciones de aqui (`COMMUNITY_PATHS` en `MobileNav.tsx:30`).
class ComunidadScreen extends StatelessWidget {
  const ComunidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comunidad'),
          bottom: const TabBar(
            labelColor: AppColors.brand700,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.brand500,
            tabs: [
              Tab(text: 'Voluntarios'),
              Tab(text: 'Caravanas'),
              Tab(text: 'Denuncias'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _Pendiente('voluntarios'),
            _Pendiente('caravanas'),
            _Pendiente('denuncias'),
          ],
        ),
      ),
    );
  }
}

class _Pendiente extends StatelessWidget {
  const _Pendiente(this.que);

  final String que;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Pendiente: listado de $que desde Supabase (Fase 1, solo lectura).',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
