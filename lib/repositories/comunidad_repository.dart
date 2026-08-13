import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_providers.dart';
import '../core/util/freshness.dart';
import '../models/publicacion.dart';

/// Comunidad: muro, denuncias, voluntarios y caravanas.
class ComunidadRepository {
  const ComunidadRepository(this._db);

  final SupabaseClient _db;

  /// Muro principal.
  ///
  /// El filtro por `moderation_status` NO es opcional: los posts que se
  /// ingieren de Bluesky y Mastodon nacen en `pending` y no han pasado por
  /// nadie. Sin este filtro la app publicaria contenido sin moderar de una red
  /// abierta, en una emergencia — que es justo el escenario donde circulan
  /// bulos y fotos de cadaveres.
  Future<Fresh<List<Publicacion>>> muro({
    required String paisCodigo,
    TipoPublicacion? tipo,
    int limite = 40,
    int desde = 0,
  }) async {
    var q = _db
        .from('posts')
        .select()
        .eq('country', paisCodigo)
        .eq('moderation_status', 'approved');

    if (tipo != null) q = q.eq('type', tipo.wire);

    // Los fijados primero, y dentro de cada grupo lo mas reciente arriba.
    final rows = await q
        .order('pinned', ascending: false)
        .order('created_at', ascending: false)
        .range(desde, desde + limite - 1);

    return Fresh.now(rows.map(Publicacion.fromMap).toList(growable: false));
  }

  /// Comentarios de una publicacion, hilo completo.
  ///
  /// `comments` es polimorfica (`entity_type` + `entity_id`), asi que hay que
  /// filtrar por tipo: sin eso salen tambien los comentarios de personas y de
  /// puntos de ayuda mezclados con los del post.
  Future<Fresh<List<Comentario>>> comentarios(String publicacionId) async {
    final rows = await _db
        .from('comments')
        .select()
        .eq('entity_type', 'post')
        .eq('entity_id', publicacionId)
        .order('created_at', ascending: true);

    return Fresh.now(rows.map(Comentario.fromMap).toList(growable: false));
  }

  /// Cuantos comentarios tiene una publicacion.
  Future<int> contarComentarios(String publicacionId) async {
    try {
      return await _db
          .from('comments')
          .count(CountOption.exact)
          .eq('entity_type', 'post')
          .eq('entity_id', publicacionId);
    } catch (_) {
      return 0;
    }
  }

  Future<Fresh<List<Denuncia>>> denuncias({
    required String paisCodigo,
    int limite = 40,
  }) async {
    final rows = await _db
        .from('complaints')
        .select()
        .eq('country', paisCodigo)
        .order('created_at', ascending: false)
        .limit(limite);

    return Fresh.now(rows.map(Denuncia.fromMap).toList(growable: false));
  }

  Future<Fresh<List<Voluntario>>> voluntarios({
    required String paisCodigo,
    int limite = 60,
  }) async {
    final rows = await _db
        .from('volunteers')
        .select()
        .eq('country', paisCodigo)
        .limit(limite);

    return Fresh.now(rows.map(Voluntario.fromMap).toList(growable: false));
  }

  Future<Fresh<List<Caravana>>> caravanas({
    required String paisCodigo,
    int limite = 40,
  }) async {
    final rows = await _db
        .from('marches')
        .select()
        .eq('country', paisCodigo)
        .order('depart_at', ascending: true)
        .limit(limite);

    return Fresh.now(rows.map(Caravana.fromMap).toList(growable: false));
  }
}

final comunidadRepositoryProvider = Provider<ComunidadRepository>((ref) {
  return ComunidadRepository(ref.watch(supabaseClientProvider));
});
