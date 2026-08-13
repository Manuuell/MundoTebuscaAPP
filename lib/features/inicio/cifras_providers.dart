import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/pais_provider.dart';
import '../../core/util/freshness.dart';
import '../../models/pais.dart';
import '../../repositories/cifras_repository.dart';

/// Cifras del panel, atadas al pais activo: cambiar de pais las recarga solas.
final cifrasPanelProvider = FutureProvider<Fresh<CifrasPanel>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref.watch(cifrasRepositoryProvider).panel(paisCodigo: pais.codigo);
});

final cifrasSismoProvider = FutureProvider<Fresh<CifrasSismo?>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref.watch(cifrasRepositoryProvider).sismo(paisCodigo: pais.codigo);
});
