import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ayuda/ayuda_screen.dart';
import '../../features/comunidad/comunidad_screen.dart';
import '../../features/inicio/inicio_screen.dart';
import '../../features/mapa/mapa_screen.dart';
import '../../features/mascotas/mascotas_screen.dart';
import '../../features/persona/persona_detalle_screen.dart';
import '../../features/persona/persona_gestion_screen.dart';
import '../../features/se_busca/se_busca_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../features/sos/sos_screen.dart';
import '../../models/persona.dart';

/// Rutas de la app.
///
/// Los paths son los MISMOS que los de la web a proposito: los enlaces de
/// gestion que llegan por correo (`/persona/{id}/gestion?token=`) tienen que
/// abrir la app si esta instalada, y caer al sitio web si no. Con App Links
/// (Android) y Universal Links (iOS) sobre el mismo dominio eso sale gratis
/// solo si las rutas coinciden; si aqui se inventan otras, el enlace se rompe.
abstract final class Rutas {
  static const inicio = '/';
  static const seBusca = '/se-busca';
  static const comunidad = '/comunidad';
  static const mapa = '/mapa';
  static const sos = '/emergencias';

  // Fuera de los tabs: se apilan encima.
  static const ayuda = '/ayuda';
  static const mascotas = '/mascotas';
  static const persona = '/persona';
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Rutas.inicio,
    routes: [
      // Los 5 tabs primarios, cada uno con su propia pila de navegacion para
      // que volver a un tab conserve donde estabas.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rutas.inicio,
              builder: (_, _) => const InicioScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rutas.seBusca,
              builder: (_, state) => SeBuscaScreen(
                // `/se-busca?status=hospitalizado` abre ya filtrado. Es lo que
                // usan los chips de cifras del Inicio y los enlaces de la web.
                estadoInicial: EstadoPersona.desdeWire(
                  state.uri.queryParameters['status'],
                ),
                soloMenores: state.uri.queryParameters['maxAge'] != null,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rutas.comunidad,
              builder: (_, _) => const ComunidadScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rutas.mapa,
              builder: (_, _) => const MapaScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rutas.sos,
              builder: (_, _) => const SosScreen(),
            ),
          ]),
        ],
      ),

      // Hoja "Mas".
      GoRoute(
        path: Rutas.ayuda,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AyudaScreen(),
      ),
      GoRoute(
        path: Rutas.mascotas,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const MascotasScreen(),
      ),

      // Ficha de una persona y su enlace de gestion con token.
      GoRoute(
        path: '${Rutas.persona}/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            PersonaDetalleScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'gestion',
            parentNavigatorKey: _rootKey,
            builder: (_, state) => PersonaGestionScreen(
              id: state.pathParameters['id']!,
              token: state.uri.queryParameters['token'],
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('No encontrado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No pudimos abrir ${state.uri}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
