import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/state/pais_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/sos/checkin_alerta_screen.dart';
import 'repositories/safety_repository.dart';

class MundoTeBuscaApp extends ConsumerStatefulWidget {
  const MundoTeBuscaApp({super.key});

  @override
  ConsumerState<MundoTeBuscaApp> createState() => _MundoTeBuscaAppState();
}

class _MundoTeBuscaAppState extends ConsumerState<MundoTeBuscaApp>
    with WidgetsBindingObserver {
  late final _router = buildRouter();
  Timer? _sondeoCheckin;
  String? _quakeIdMostrado;

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
    _iniciarSondeoCheckin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sondeoCheckin?.cancel();
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
      _sondearCheckin();
    }
  }

  void _refrescarUbicacionRedAuxilio() {
    ref.read(safetyRepositoryProvider).actualizarUbicacionSiActiva();
  }

  /// Sondea cada pocos segundos si hay un check-in pendiente.
  ///
  /// Sustituye a un push real (no hay FCM/APNs configurado todavia — ver
  /// §7 de 10-alerta-sismo-checkin.md), pero para la app abierta en primer
  /// plano el resultado es el mismo: la alerta aparece en segundos.
  void _iniciarSondeoCheckin() {
    _sondeoCheckin =
        Timer.periodic(const Duration(seconds: 6), (_) => _sondearCheckin());
  }

  Future<void> _sondearCheckin() async {
    final checkin = await ref.read(safetyRepositoryProvider).sondear();
    if (checkin == null || checkin.status != 'pending') return;
    if (_quakeIdMostrado == checkin.quakeId) return;

    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    _quakeIdMostrado = checkin.quakeId;
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => CheckinAlertaScreen(quakeId: checkin.quakeId),
      fullscreenDialog: true,
    ));
    _quakeIdMostrado = null;
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
