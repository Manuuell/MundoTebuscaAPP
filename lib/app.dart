import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/state/pais_provider.dart';
import 'core/theme/app_theme.dart';
import 'repositories/safety_repository.dart';

class MundoTeBuscaApp extends ConsumerStatefulWidget {
  const MundoTeBuscaApp({super.key});

  @override
  ConsumerState<MundoTeBuscaApp> createState() => _MundoTeBuscaAppState();
}

class _MundoTeBuscaAppState extends ConsumerState<MundoTeBuscaApp>
    with WidgetsBindingObserver {
  late final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // El pais guardado se lee despues del primer frame: la app abre de
    // inmediato con la emergencia mas reciente y corrige si el usuario tenia
    // otra elegida. Bloquear el arranque por una lectura de disco no vale la
    // pena en una app que se abre con urgencia.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paisProvider.notifier).cargarGuardado();
      _refrescarUbicacionRedAuxilio();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "Cada vez que la app vuelve a foreground" (§3 de
    // 10-alerta-sismo-checkin.md) en vez de tracking en segundo plano: es
    // oportunista, barato en bateria, y suficiente porque el radio de un
    // sismo relevante es de kilometros, no de metros.
    if (state == AppLifecycleState.resumed) {
      _refrescarUbicacionRedAuxilio();
    }
  }

  void _refrescarUbicacionRedAuxilio() {
    ref.read(safetyRepositoryProvider).actualizarUbicacionSiActiva();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'El Mundo Te Busca',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
