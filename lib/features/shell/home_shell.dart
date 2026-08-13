import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


import '../../widgets/floating_tab_bar.dart';

/// Cascaron de la app: 5 tabs primarios en una barra flotante.
///
/// La jerarquia viene de `MobileNav.tsx`, que ya la resolvio para la PWA, con
/// un cambio pedido: la quinta pestana es Ajustes en vez de SOS. Emergencias
/// no se pierde — sigue en la hoja "Mas" y arriba del todo en Ajustes.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = <ItemTab>[
    (
      icono: Icons.home_outlined,
      iconoActivo: Icons.home_rounded,
      etiqueta: 'Inicio'
    ),
    (
      icono: Icons.search_outlined,
      iconoActivo: Icons.search_rounded,
      etiqueta: 'Se busca'
    ),
    (
      icono: Icons.people_outline,
      iconoActivo: Icons.people_rounded,
      etiqueta: 'Comunidad'
    ),
    (
      icono: Icons.map_outlined,
      iconoActivo: Icons.map_rounded,
      etiqueta: 'Mapa'
    ),
    (
      icono: Icons.settings_outlined,
      iconoActivo: Icons.settings_rounded,
      etiqueta: 'Ajustes'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La barra flota sobre el contenido: el cuerpo llega hasta abajo del
      // todo y las listas se asoman por debajo del cristal. Ese "asomarse" es
      // lo que da la sensacion de profundidad.
      extendBody: true,
      body: Stack(
        children: [
          // El hueco al final de las listas lo aporta este MediaQuery en vez
          // de repetir un padding a mano en cada pantalla. Sin el, la ultima
          // tarjeta queda tapada por la barra.
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.paddingOf(context).copyWith(
                bottom: MediaQuery.paddingOf(context).bottom +
                    FloatingTabBar.alturaOcupada,
              ),
            ),
            child: shell,
          ),
          FloatingTabBar(
            items: _tabs,
            indiceActual: shell.currentIndex,
            alTocar: (i) => shell.goBranch(
              i,
              // Volver a tocar la pestana activa regresa a su raiz, que es lo
              // que espera cualquiera que venga de una app nativa.
              initialLocation: i == shell.currentIndex,
            ),
          ),
        ],
      ),
    );
  }
}
