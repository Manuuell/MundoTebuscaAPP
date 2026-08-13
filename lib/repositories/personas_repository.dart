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

  static const _tabla = 'persons';

  /// Listado con filtros. `Fresh` obliga a que la antiguedad llegue a la UI.
  Future<Fresh<List<Persona>>> listar({
    required String paisCodigo,
    EstadoPersona? estado,
    bool soloMenores = false,
    String? busqueda,
    int limite = 50,
    int desde = 0,
    bool? soloNoIdentificadas,
  }) async {
    var q = _db.from(_tabla).select().eq('country', paisCodigo);

    // `is_unidentified` es lo que separa "Se busca" (alguien con nombre a
    // quien se busca) de "La reconoces?" (alguien encontrado sin identificar).
    // Misma tabla, dos pantallas.
    if (soloNoIdentificadas != null) {
      q = q.eq('is_unidentified', soloNoIdentificadas);
    }

    // `status` es el estado de búsqueda; `estado` en esta tabla es la región
    // geográfica — no confundir (ver 06-correcciones-y-reparto.md §Parte 1).
    if (estado != null) q = q.eq('status', estado.wire);
    if (soloMenores) q = q.lte('age', 11);
    if (busqueda != null && busqueda.trim().isNotEmpty) {
      final t = busqueda.trim();
      q = q.or(
        'first_name.ilike.%$t%,last_name.ilike.%$t%,cedula.ilike.%$t%,'
        'location_text.ilike.%$t%',
      );
    }

    // `range` en vez de `limit` para poder pedir la siguiente tanda al hacer
    // scroll sin volver a traer lo ya cargado.
    final rows = await q
        .order('updated_at', ascending: false)
        .range(desde, desde + limite - 1);

    return Fresh.now(
      rows.map((r) => Persona.fromMap(r)).toList(growable: false),
    );
  }

  /// Personas con coordenada exacta, para el mapa. Solo `por_localizar`: el
  /// mapa pinta desaparecidos en rojo, no el listado completo — ver nota en
  /// `MapaScreen`.
  ///
  /// Si `lat`/`lng` no existen todavia en el esquema (base sin migrar), no se
  /// rompe el mapa: se degrada a "sin personas" en vez de tumbar la pantalla.
  Future<Fresh<List<Persona>>> conUbicacion({
    required String paisCodigo,
    int limite = 200,
  }) async {
    try {
      final rows = await _db
          .from(_tabla)
          .select()
          .eq('country', paisCodigo)
          .eq('status', EstadoPersona.porLocalizar.wire)
          .not('lat', 'is', null)
          .not('lng', 'is', null)
          .order('updated_at', ascending: false)
          .limit(limite);

      return Fresh.now(
          rows.map((r) => Persona.fromMap(r)).toList(growable: false));
    } catch (_) {
      return Fresh.now(const <Persona>[]);
    }
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
        .eq('country', paisCodigo)
        .order('updated_at')
        .map((rows) => rows.map(Persona.fromMap).toList(growable: false));
  }
}

final personasRepositoryProvider = Provider<PersonasRepository>((ref) {
  return PersonasRepository(ref.watch(supabaseClientProvider));
});
