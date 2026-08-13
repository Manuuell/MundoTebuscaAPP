import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/state/pais_provider.dart';
import 'core/theme/app_theme.dart';

class MundoTeBuscaApp extends ConsumerStatefulWidget {
  const MundoTeBuscaApp({super.key});

  @override
  ConsumerState<MundoTeBuscaApp> createState() => _MundoTeBuscaAppState();
}

class _MundoTeBuscaAppState extends ConsumerState<MundoTeBuscaApp> {
  late final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    // El pais guardado se lee despues del primer frame: la app abre de
    // inmediato con la emergencia mas reciente y corrige si el usuario tenia
    // otra elegida. Bloquear el arranque por una lectura de disco no vale la
    // pena en una app que se abre con urgencia.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paisProvider.notifier).cargarGuardado();
    });
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
