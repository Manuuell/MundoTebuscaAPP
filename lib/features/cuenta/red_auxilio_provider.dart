import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/safety_repository.dart';

enum RedAuxilioFase { cargando, inactiva, activando, activa, desactivando }

class RedAuxilioEstado {
  const RedAuxilioEstado({required this.fase, this.error});

  final RedAuxilioFase fase;
  final SafetyError? error;

  bool get ocupado =>
      fase == RedAuxilioFase.activando || fase == RedAuxilioFase.desactivando;

  RedAuxilioEstado copyWith({RedAuxilioFase? fase, SafetyError? error}) =>
      RedAuxilioEstado(fase: fase ?? this.fase, error: error);
}

/// Estado del interruptor "Red de auxilio" en Ajustes.
///
/// Separado de [SafetyRepository] porque la pantalla necesita fases
/// intermedias (activando/desactivando) para no dejar al usuario tocando un
/// switch que tarda en responder sin ninguna senal.
class RedAuxilioNotifier extends Notifier<RedAuxilioEstado> {
  @override
  RedAuxilioEstado build() {
    _cargar();
    return const RedAuxilioEstado(fase: RedAuxilioFase.cargando);
  }

  Future<void> _cargar() async {
    final activa = await ref.read(safetyRepositoryProvider).activaLocalmente();
    state = RedAuxilioEstado(
      fase: activa ? RedAuxilioFase.activa : RedAuxilioFase.inactiva,
    );
  }

  Future<void> activar(String paisCodigo) async {
    state = const RedAuxilioEstado(fase: RedAuxilioFase.activando);
    try {
      await ref.read(safetyRepositoryProvider).activar(paisCodigo: paisCodigo);
      state = const RedAuxilioEstado(fase: RedAuxilioFase.activa);
    } on SafetyException catch (e) {
      state = RedAuxilioEstado(fase: RedAuxilioFase.inactiva, error: e.type);
    } catch (_) {
      state = const RedAuxilioEstado(
        fase: RedAuxilioFase.inactiva,
        error: SafetyError.network,
      );
    }
  }

  Future<void> desactivar() async {
    state = const RedAuxilioEstado(fase: RedAuxilioFase.desactivando);
    try {
      await ref.read(safetyRepositoryProvider).desactivar();
    } catch (_) {
      // Ya se apago local dentro del repo aunque falle la red; no bloquea.
    }
    state = const RedAuxilioEstado(fase: RedAuxilioFase.inactiva);
  }
}

final redAuxilioProvider =
    NotifierProvider<RedAuxilioNotifier, RedAuxilioEstado>(
        RedAuxilioNotifier.new);
