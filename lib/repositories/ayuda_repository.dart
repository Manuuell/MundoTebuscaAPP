import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_providers.dart';
import '../core/util/freshness.dart';
import '../models/punto_ayuda.dart';

/// Puntos del mapa: ayuda, hospitales, refugios, rescates, zonas.
class AyudaRepository {
  const AyudaRepository(this._db);

  final SupabaseClient _db;

  static const _tabla = 'aid_points';

  /// `tipos` filtra en el cliente, no en el servidor: `aid_points.types` es
  /// un array de categorías del punto (comida/agua/medicina/...), un dominio
  /// de valores distinto al de las capas del mapa (`TipoPunto`). Toda fila de
  /// esta tabla es capa `ayuda` (ver nota en `PuntoAyuda`) — si se pide un
  /// set de capas que no incluye `ayuda`, no hay nada que devolver todavía.
  Future<Fresh<List<PuntoAyuda>>> listar({
    required String paisCodigo,
    Set<TipoPunto>? tipos,
  }) async {
    if (tipos != null && tipos.isNotEmpty && !tipos.contains(TipoPunto.ayuda)) {
      return Fresh.now(const <PuntoAyuda>[]);
    }

    final rows = await _db
        .from(_tabla)
        .select()
        .eq('country', paisCodigo)
        .order('updated_at', ascending: false);

    return Fresh.now(rows.map(PuntoAyuda.fromMap).toList(growable: false));
  }

  Stream<List<PuntoAyuda>> observar({required String paisCodigo}) {
    return _db
        .from(_tabla)
        .stream(primaryKey: ['id'])
        .eq('country', paisCodigo)
        .map((rows) => rows.map(PuntoAyuda.fromMap).toList(growable: false));
  }
}

final ayudaRepositoryProvider = Provider<AyudaRepository>((ref) {
  return AyudaRepository(ref.watch(supabaseClientProvider));
});
