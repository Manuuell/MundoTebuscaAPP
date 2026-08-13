import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/state/pais_provider.dart';
import '../core/supabase/supabase_providers.dart';
import '../core/util/freshness.dart';

/// Noticia del carrusel del Inicio.
class Noticia {
  const Noticia({
    required this.titulo,
    required this.fuente,
    this.url,
    this.fotoUrl,
    this.resumen,
    this.fecha,
    this.curada = false,
    this.idioma,
  });

  final String titulo;
  final String fuente;
  final String? url;
  final String? fotoUrl;
  final String? resumen;
  final DateTime? fecha;

  /// Escrita o revisada por el equipo, no traida de un agregador.
  final bool curada;

  /// Idioma que reporta GDELT ("Spanish", "English"...). Se ensena cuando no
  /// es espanol: el lector merece saber que va a abrir una nota en otro idioma
  /// antes de tocarla.
  final String? idioma;

  bool get enEspanol => idioma == null || idioma == 'Spanish';
}

/// Noticias verificadas.
///
/// Dos fuentes, sin ningun secreto en el cliente:
///
/// 1. `news_items` de Supabase — contenido curado por el equipo.
/// 2. **GDELT**, la misma consulta que usa la web. Es una API publica y
///    gratuita que NO pide llave, asi que la app puede llamarla directo.
///
/// GNews, la otra fuente de la web, se queda fuera a proposito: exige
/// `GNEWS_API_KEY`, y esa llave no puede viajar en un binario que cualquiera
/// descomprime. Si algun dia hace falta, va detras de una Edge Function.
class NoticiasRepository {
  const NoticiasRepository(this._db);

  final SupabaseClient _db;

  /// Misma consulta por pais que la web.
  static const _consultas = {
    'co': 'Colombia (terremoto OR sismo OR temblor)',
    've': 'Venezuela (terremoto OR sismo OR temblor)',
  };

  Future<Fresh<List<Noticia>>> recientes({
    required String paisCodigo,
    int limite = 12,
  }) async {
    // En paralelo: si el agregador tarda, la parte curada no espera por el.
    final resultados = await Future.wait([
      _curadas(paisCodigo),
      _gdelt(paisCodigo, limite),
    ]);

    // Orden: curadas, luego espanol, luego el resto. GDELT hoy devuelve casi
    // todo en ingles para estas consultas —la web resuelve eso con GNews, que
    // pide API key y por eso no puede vivir en el cliente— asi que lo poco que
    // llegue en espanol debe ir delante.
    final agregadas = [...resultados[1]]
      ..sort((a, b) {
        if (a.enEspanol != b.enEspanol) return a.enEspanol ? -1 : 1;
        return (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0));
      });
    final todas = [...resultados[0], ...agregadas];

    // GDELT devuelve la misma nota replicada por varios medios (teletipos de
    // agencia sobre todo). Sin deduplicar, el carrusel muestra cuatro veces
    // "AP News in Brief".
    final vistos = <String>{};
    final unicas = <Noticia>[];
    for (final n in todas) {
      final clave = n.titulo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (clave.isEmpty || vistos.add(clave)) unicas.add(n);
    }

    return Fresh.now(unicas.take(limite).toList(growable: false));
  }

  Future<List<Noticia>> _curadas(String paisCodigo) async {
    try {
      final filas = await _db
          .from('news_items')
          .select()
          .eq('country', paisCodigo)
          .order('created_at', ascending: false)
          .limit(8);

      return filas
          .map((r) => Noticia(
                titulo: (r['title'] ?? '') as String,
                fuente: (r['source_name'] ?? 'El Mundo Te Busca') as String,
                url: r['source_url'] as String?,
                fotoUrl: r['photo_url'] as String?,
                resumen: r['body'] as String?,
                fecha: DateTime.tryParse('${r['created_at']}'),
                curada: true,
              ))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// GDELT limita a UNA peticion cada 5 segundos y responde 429 si se pasa.
  /// Sin este cache, tirar de la lista dos veces seguidas deja el carrusel
  /// vacio.
  static final _cache = <String, (DateTime, List<Noticia>)>{};
  static const _vidaCache = Duration(minutes: 10);

  Future<List<Noticia>> _gdelt(String paisCodigo, int limite) async {
    final consulta = _consultas[paisCodigo];
    if (consulta == null) return const [];

    final guardado = _cache[paisCodigo];
    if (guardado != null &&
        DateTime.now().difference(guardado.$1) < _vidaCache) {
      return guardado.$2;
    }

    try {
      final uri = Uri.parse(
        'https://api.gdeltproject.org/api/v2/doc/doc'
        '?query=${Uri.encodeComponent(consulta)}'
        '&mode=artlist&maxrecords=$limite&format=json&sort=datedesc',
      );

      final res = await http.get(uri, headers: {
        // GDELT rechaza peticiones sin user-agent identificable.
        'user-agent': 'Mozilla/5.0 (compatible; ElMundoTeBusca/1.0)',
      }).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return const [];

      final datos = jsonDecode(res.body) as Map<String, dynamic>;
      final articulos = (datos['articles'] as List?) ?? const [];

      final lista = articulos
          .cast<Map<String, dynamic>>()
          .map((a) => Noticia(
                titulo: _limpiarTitulo('${a['title'] ?? ''}'),
                fuente: '${a['domain'] ?? ''}',
                url: a['url'] as String?,
                // Misma validacion que la web: si `socialimage` no es una URL
                // http(s), se descarta en vez de intentar cargarla.
                fotoUrl: _imagenValida('${a['socialimage'] ?? ''}'),
                fecha: _fechaGdelt('${a['seendate'] ?? ''}'),
                idioma: a['language'] as String?,
              ))
          .where((n) => n.titulo.isNotEmpty)
          .toList(growable: false);

      _cache[paisCodigo] = (DateTime.now(), lista);
      return lista;
    } catch (_) {
      // Sin red, o con 429 del agregador, se queda con lo ultimo que se pudo
      // traer; y si no hay nada, con las curadas.
      return _cache[paisCodigo]?.$2 ?? const [];
    }
  }

  /// GDELT devuelve los titulos tokenizados: "AP News in Brief at 6 : 04 a . m".
  static String _limpiarTitulo(String t) {
    return t
        .replaceAll(RegExp(r'\s+([,.:;!?])'), r'$1')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static String? _imagenValida(String u) =>
      RegExp(r'^https?://').hasMatch(u) ? u : null;

  /// Formato `20260813T113000Z`.
  static DateTime? _fechaGdelt(String s) {
    if (s.length < 15) return null;
    return DateTime.tryParse(
      '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}'
      'T${s.substring(9, 11)}:${s.substring(11, 13)}:${s.substring(13, 15)}Z',
    );
  }
}

final noticiasRepositoryProvider = Provider<NoticiasRepository>((ref) {
  return NoticiasRepository(ref.watch(supabaseClientProvider));
});

final noticiasProvider = FutureProvider<Fresh<List<Noticia>>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref.watch(noticiasRepositoryProvider).recientes(paisCodigo: pais.codigo);
});
