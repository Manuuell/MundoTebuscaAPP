import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_providers.dart';
import '../core/util/freshness.dart';
import '../models/persona.dart';

/// Acceso a personas.
///
/// Espeja las funciones de `src/lib/data.ts` del repo web, menos la rama de
/// memoria/demo (no aplica a produccion movil). La UI nunca toca el cliente de
/// Supabase directo: siempre pasa por aqui, igual que la web nunca habla con
/// la base desde un componente.
class PersonasRepository {
  const PersonasRepository(this._db);

  final SupabaseClient _db;

  static const _tabla = 'personas';

  /// Listado con filtros. `Fresh` obliga a que la antiguedad llegue a la UI.
  Future<Fresh<List<Persona>>> listar({
    required String paisCodigo,
    EstadoPersona? estado,
    bool soloMenores = false,
    String? busqueda,
    int limite = 50,
  }) async {
    var q = _db.from(_tabla).select().eq('pais', paisCodigo);

    if (estado != null) q = q.eq('estado', estado.wire);
    if (soloMenores) q = q.lte('edad', 11);
    if (busqueda != null && busqueda.trim().isNotEmpty) {
      final t = busqueda.trim();
      q = q.or('nombre.ilike.%$t%,documento.ilike.%$t%,ubicacion.ilike.%$t%');
    }

    final rows = await q.order('updated_at', ascending: false).limit(limite);

    return Fresh.now(
      rows.map((r) => Persona.fromMap(r)).toList(growable: false),
    );
  }

  Future<Fresh<Persona?>> porId(String id) async {
    final row =
        await _db.from(_tabla).select().eq('id', id).maybeSingle();
    return Fresh.now(row == null ? null : Persona.fromMap(row));
  }

  /// Realtime en vez del `revalidatePath` de Next: la lista se actualiza sola
  /// cuando alguien cambia el estado de una persona, sin que el usuario haga
  /// nada. Es lo que motiva tener app y no solo la web.
  Stream<List<Persona>> observar({required String paisCodigo}) {
    return _db
        .from(_tabla)
        .stream(primaryKey: ['id'])
        .eq('pais', paisCodigo)
        .order('updated_at')
        .map((rows) => rows.map(Persona.fromMap).toList(growable: false));
  }
}

final personasRepositoryProvider = Provider<PersonasRepository>((ref) {
  return PersonasRepository(ref.watch(supabaseClientProvider));
});
