import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/pais_provider.dart';
import '../../core/util/freshness.dart';
import '../../models/publicacion.dart';
import '../../repositories/comunidad_repository.dart';

/// Filtro de tipo del muro. `null` = todos.
final filtroTipoProvider = StateProvider<TipoPublicacion?>((ref) => null);

final muroProvider = FutureProvider<Fresh<List<Publicacion>>>((ref) async {
  final pais = ref.watch(paisProvider);
  final tipo = ref.watch(filtroTipoProvider);
  return ref
      .watch(comunidadRepositoryProvider)
      .muro(paisCodigo: pais.codigo, tipo: tipo);
});

final denunciasProvider = FutureProvider<Fresh<List<Denuncia>>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref.watch(comunidadRepositoryProvider).denuncias(paisCodigo: pais.codigo);
});

final voluntariosProvider = FutureProvider<Fresh<List<Voluntario>>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref
      .watch(comunidadRepositoryProvider)
      .voluntarios(paisCodigo: pais.codigo);
});

final caravanasProvider = FutureProvider<Fresh<List<Caravana>>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref.watch(comunidadRepositoryProvider).caravanas(paisCodigo: pais.codigo);
});
