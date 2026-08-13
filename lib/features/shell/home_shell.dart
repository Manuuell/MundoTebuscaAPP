import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';

/// Cascaron de la app: 5 tabs primarios + hoja "Mas".
///
/// La jerarquia no se invento aqui — es la misma que `MobileNav.tsx` ya
/// resolvio para la PWA (Inicio, Se busca, Comunidad, Mapa, SOS; y en "Mas",
/// Ayuda y hospitales + Mascotas). Quien ya usa la web no reaprende nada al
/// pasar a la app.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = <_Tab>[
    _Tab('Inicio', Icons.home_outlined, Icons.home_rounded),
    _Tab('Se busca', Icons.search_outlined, Icons.search_rounded),
    _Tab('Comunidad', Icons.people_outline, Icons.people_rounded),
    _Tab('Mapa', Icons.map_outlined, Icons.map_rounded),
    _Tab('Ajustes', Icons.settings_outlined, Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(
          i,
          // Volver a tocar el tab activo regresa a su raiz, que es lo que
          // espera cualquiera que venga de una app nativa.
          initialLocation: i == shell.currentIndex,
        ),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.iconActivo),
              label: t.etiqueta,
            ),
        ],
      ),
    );
  }
}

/// Hoja "Mas": lo que en la web cuelga de `MobileNav.tsx:41-44`.
Future<void> mostrarHojaMas(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.local_hospital_outlined,
                color: AppColors.brand700),
            title: const Text('Ayuda y hospitales'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push(Rutas.ayuda);
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.pets_outlined, color: AppColors.brand700),
            title: const Text('Mascotas'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push(Rutas.mascotas);
            },
          ),
          ListTile(
            leading: const Icon(Icons.emergency_outlined,
                color: AppColors.danger500),
            title: const Text('Emergencia y seguridad'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push(Rutas.sos);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _Tab {
  const _Tab(this.etiqueta, this.icon, this.iconActivo);
  final String etiqueta;
  final IconData icon;
  final IconData iconActivo;
}
