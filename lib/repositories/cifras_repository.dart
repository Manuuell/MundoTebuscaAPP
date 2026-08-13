import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_providers.dart';
import '../core/util/freshness.dart';
import '../models/pais.dart';

/// Las cifras del Inicio.
///
/// Se leen de una vista/RPC agregada y no contando filas desde el cliente: son
/// tres bloques distintos de la pantalla (hero, cifras de prensa, fila de 8) y
/// hacer ocho consultas para pintar ocho numeros es justo lo que hace lenta
/// una pantalla de arranque.
class CifrasRepository {
  const CifrasRepository(this._db);

  final SupabaseClient _db;

  Future<Fresh<CifrasPanel>> panel({required String paisCodigo}) async {
    final row = await _db
        .rpc('cifras_panel', params: {'pais_codigo': paisCodigo})
        .maybeSingle();

    return Fresh.now(
      row == null
          ? const CifrasPanel()
          : CifrasPanel.fromMap(Map<String, dynamic>.from(row)),
    );
  }

  /// Cifras de prensa del sismo, con fuente y fecha. Si la mas reciente pasa
  /// de 30 dias, `CifrasSismo.esReciente` da false y la UI muestra el bloque
  /// curado en vez de una cifra vieja disfrazada de actual.
  Future<Fresh<CifrasSismo?>> sismo({required String paisCodigo}) async {
    final row = await _db
        .from('cifras_sismo')
        .select()
        .eq('pais', paisCodigo)
        .order('fecha', ascending: false)
        .limit(1)
        .maybeSingle();

    return Fresh.now(row == null ? null : CifrasSismo.fromMap(row));
  }
}

final cifrasRepositoryProvider = Provider<CifrasRepository>((ref) {
  return CifrasRepository(ref.watch(supabaseClientProvider));
});
