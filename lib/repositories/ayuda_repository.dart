import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_providers.dart';
import '../core/util/freshness.dart';
import '../models/punto_ayuda.dart';

/// Puntos del mapa: ayuda, hospitales, refugios, rescates, zonas.
class AyudaRepository {
  const AyudaRepository(this._db);

  final SupabaseClient _db;

  static const _tabla = 'puntos_ayuda';

  Future<Fresh<List<PuntoAyuda>>> listar({
    required String paisCodigo,
    Set<TipoPunto>? tipos,
  }) async {
    var q = _db.from(_tabla).select().eq('pais', paisCodigo);

    if (tipos != null && tipos.isNotEmpty) {
      q = q.inFilter('tipo', tipos.map((t) => t.wire).toList());
    }

    final rows = await q.order('updated_at', ascending: false);
    return Fresh.now(rows.map(PuntoAyuda.fromMap).toList(growable: false));
  }

  Stream<List<PuntoAyuda>> observar({required String paisCodigo}) {
    return _db
        .from(_tabla)
        .stream(primaryKey: ['id'])
        .eq('pais', paisCodigo)
        .map((rows) => rows.map(PuntoAyuda.fromMap).toList(growable: false));
  }
}

final ayudaRepositoryProvider = Provider<AyudaRepository>((ref) {
  return AyudaRepository(ref.watch(supabaseClientProvider));
});
