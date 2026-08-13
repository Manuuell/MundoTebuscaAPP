import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
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

  /// La misma noticia con el titular traducido. `idioma` se conserva a
  /// proposito: la nota enlazada sigue en su idioma original y la insignia
  /// debe seguir avisandolo aunque el titular ya se lea en espanol.
  Noticia conTitulo(String nuevo) => Noticia(
        titulo: nuevo,
        fuente: fuente,
        url: url,
        fotoUrl: fotoUrl,
        resumen: resumen,
        fecha: fecha,
        curada: curada,
        idioma: idioma,
      );
}

/// Lo que se pudo reunir, y si alguna fuente se quedo fuera.
class Noticias {
  const Noticias(this.lista, {this.agregadorFallo = false});

  final List<Noticia> lista;

  /// El agregador no contesto y tampoco habia nada guardado de antes. Existe
  /// para no afirmar "no hay noticias" cuando lo cierto es "no pudimos
  /// consultar": son dos cosas muy distintas, igual que un 0 en las cifras.
  final bool agregadorFallo;
}

/// Noticias verificadas.
///
/// Dos fuentes, sin ningun secreto en el cliente:
///
/// 1. `news_items` de Supabase — contenido curado por el equipo.
/// 2. El **sitio web** (`/api/noticias/verificadas`): la misma lista que su
///    carrusel, ya cocinada por su servidor — cache de 6h sobre GDELT, caida
///    a GNews si GDELT falla y titulares traducidos con OpenAI. Todo eso
///    necesita llaves y estado que no pueden viajar en un binario que
///    cualquiera descomprime, y por eso se lee hecho en vez de rehacerse
///    aqui.
///
/// Si el sitio no responde, se degrada a **GDELT directo** (API publica y
/// gratuita, sin llave) con la traduccion via el proxy del asistente. Es el
/// camino de emergencia, no el normal: pegarle a GDELT desde cada telefono
/// hereda su limite por IP (429 con una peticion cada 5 segundos) y sus
/// 12-25 s de respuesta.
class NoticiasRepository {
  const NoticiasRepository(this._db);

  final SupabaseClient _db;

  /// Misma consulta por pais que la web.
  static const _consultas = {
    'co': 'Colombia (terremoto OR sismo OR temblor)',
    've': 'Venezuela (terremoto OR sismo OR temblor)',
  };

  Future<Fresh<Noticias>> recientes({
    required String paisCodigo,
    int limite = 12,
  }) async {
    // En paralelo: si el agregador tarda, la parte curada no espera por el.
    final (curadas, (prensa, fallo)) = await (
      _curadas(paisCodigo),
      _agregadas(paisCodigo, limite),
    ).wait;

    // Orden: curadas, luego espanol, luego el resto. Del sitio ya llega todo
    // en espanol; el criterio solo muerde en el camino de emergencia (GDELT
    // directo), donde puede quedar algun titular sin traducir.
    final agregadas = [...prensa]
      ..sort((a, b) {
        if (a.enEspanol != b.enEspanol) return a.enEspanol ? -1 : 1;
        return (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0));
      });
    final todas = [...curadas, ...agregadas];

    // GDELT devuelve la misma nota replicada por varios medios (teletipos de
    // agencia sobre todo). Sin deduplicar, el carrusel muestra cuatro veces
    // "AP News in Brief".
    final vistos = <String>{};
    final unicas = <Noticia>[];
    for (final n in todas) {
      final clave = n.titulo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (clave.isEmpty || vistos.add(clave)) unicas.add(n);
    }

    return Fresh.now(Noticias(
      unicas.take(limite).toList(growable: false),
      agregadorFallo: fallo,
    ));
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

  /// Prensa del pais: el sitio primero, GDELT directo de emergencia.
  Future<(List<Noticia>, bool)> _agregadas(
      String paisCodigo, int limite) async {
    final guardado = _cache[paisCodigo];
    if (guardado != null &&
        DateTime.now().difference(guardado.$1) < _vidaCache) {
      return (guardado.$2, false);
    }

    final delSitio = await _delSitio(paisCodigo, limite);
    if (delSitio != null) {
      _cache[paisCodigo] = (DateTime.now(), delSitio);
      return (delSitio, false);
    }

    return _gdelt(paisCodigo, limite);
  }

  /// La lista del carrusel del sitio, ya con fotos y titulares en espanol.
  ///
  /// `null` significa "no se pudo consultar" (sin red, sitio caido) y activa
  /// el camino de emergencia. Una lista vacia con 200 es una respuesta real
  /// —el servidor consulto sus fuentes y no habia nada— y se respeta.
  Future<List<Noticia>?> _delSitio(String paisCodigo, int limite) async {
    try {
      final uri = Uri.parse('${Env.webBaseUrl}/api/noticias/verificadas')
          .replace(queryParameters: {
        'country': paisCodigo,
        'limit': '$limite',
      });

      // Con la cache del servidor caliente esto responde al instante; fria,
      // el servidor puede tardar lo que tarde GDELT (~15 s medidos). El monto
      // cubre ese peor caso — si el sitio esta caido de verdad, la conexion
      // falla sola mucho antes.
      final res = await http.get(uri).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;

      final cuerpo = jsonDecode(res.body) as Map<String, dynamic>;
      final articulos =
          ((cuerpo['articles'] as List?) ?? const []).cast<Map<String, dynamic>>();

      return articulos
          .map((a) => Noticia(
                titulo: '${a['title'] ?? ''}'.trim(),
                fuente: '${a['source'] ?? 'Prensa'}',
                url: a['url'] as String?,
                fotoUrl: _imagenValida('${a['image'] ?? ''}'),
                fecha: DateTime.tryParse('${a['publishedAt'] ?? ''}'),
                // El servidor ya tradujo el titular; sin `idioma` no se pinta
                // insignia. La nota enlazada puede seguir en otro idioma, pero
                // eso ya lo avisa el dialogo de salida.
              ))
          .where((n) => n.titulo.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<(List<Noticia>, bool)> _gdelt(String paisCodigo, int limite) async {
    final consulta = _consultas[paisCodigo];
    // Un pais sin consulta definida no es un fallo: simplemente no tiene
    // agregador, y lo curado se muestra igual.
    if (consulta == null) return (const <Noticia>[], false);

    try {
      final uri = Uri.parse(
        'https://api.gdeltproject.org/api/v2/doc/doc'
        '?query=${Uri.encodeComponent(consulta)}'
        '&mode=artlist&maxrecords=$limite&format=json&sort=datedesc',
      );

      Future<http.Response> pedir() => http.get(uri, headers: {
            // GDELT rechaza peticiones sin user-agent identificable.
            'user-agent': 'Mozilla/5.0 (compatible; ElMundoTeBusca/1.0)',
          })
              // Medido contra la API real: tarda entre 12 y 15 segundos en
              // contestar, tanto si responde bien como si responde 429. Con el
              // limite justo en 15 s la peticion se cortaba sola casi siempre,
              // antes de llegar a leer la respuesta.
              .timeout(const Duration(seconds: 25));

      var res = await pedir();

      // 429 ("una peticion cada 5 segundos") es su respuesta mas frecuente,
      // no un caso raro, y el arranque tipico lo provoca solo: la app abre
      // con el pais semilla, dispara esta consulta, y medio segundo despues
      // `cargarGuardado()` cambia al pais guardado — la segunda consulta cae
      // dentro de la ventana y GDELT la rechaza siempre. Esperar a que pase
      // la ventana y reintentar UNA vez convierte ese fallo seguro en una
      // espera de unos segundos.
      if (res.statusCode == 429) {
        await Future<void>.delayed(const Duration(seconds: 6));
        res = await pedir();
      }

      // Tratar cualquier otro fallo como "no hay noticias" tiraba una lista
      // buena que seguia sirviendo.
      if (res.statusCode != 200) return _respaldo(paisCodigo);

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

      // Se traduce ANTES de cachear: asi las traducciones viajan con la
      // lista durante los 10 minutos de vida del cache en vez de pagarse en
      // cada refresco.
      final traducida = await _traducirTitulos(lista);

      _cache[paisCodigo] = (DateTime.now(), traducida);
      return (traducida, false);
    } catch (_) {
      // Sin red, o si la peticion se corta, se queda con lo ultimo que se
      // pudo traer; y si no hay nada, con las curadas.
      return _respaldo(paisCodigo);
    }
  }

  /// Titulares en espanol via el proxy del asistente (`server/asistente`,
  /// POST /traducir) — el equivalente movil de `translateTitles` en
  /// `src/lib/news.ts` de la web, y por la misma razon en un servidor: la
  /// llave de OpenAI no puede viajar en el binario.
  ///
  /// Nunca bloquea el carrusel: sin proxy configurado, o si la llamada falla,
  /// los titulares se quedan en su idioma original (con su insignia EN/PT/...
  /// avisando, como hasta ahora).
  Future<List<Noticia>> _traducirTitulos(List<Noticia> lista) async {
    if (Env.asistenteUrl.isEmpty) return lista;

    final indices = [
      for (var i = 0; i < lista.length; i++)
        if (!lista[i].enEspanol) i,
    ];
    if (indices.isEmpty) return lista;

    try {
      final uri = Uri.parse(Env.asistenteUrl).resolve('/traducir');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'titulares': [
                for (final i in indices) {'id': '$i', 'title': lista[i].titulo},
              ],
            }),
          )
          // Un lote de ~10 titulares tarda varios segundos; la web ya
          // aprendio que un limite corto corta la respuesta a mitad.
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) return lista;

      final cuerpo = jsonDecode(res.body) as Map<String, dynamic>;
      final traducciones =
          (cuerpo['traducciones'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (traducciones.isEmpty) return lista;

      final copia = [...lista];
      for (final i in indices) {
        final t = traducciones['$i'];
        if (t is String && t.trim().isNotEmpty) {
          copia[i] = copia[i].conTitulo(t.trim());
        }
      }
      return copia;
    } catch (_) {
      return lista;
    }
  }

  /// La ultima lista buena aunque este vencida — una noticia de hace unas
  /// horas sigue siendo cierta —, y si nunca hubo ninguna, el aviso de que la
  /// consulta fallo para que la UI no lo cuente como "no hay noticias".
  (List<Noticia>, bool) _respaldo(String paisCodigo) {
    final guardado = _cache[paisCodigo];
    return guardado == null ? (const <Noticia>[], true) : (guardado.$2, false);
  }

  /// GDELT devuelve los titulos tokenizados: "AP News in Brief at 6 : 04 a . m".
  ///
  /// Con `replaceAll` el `$1` NO es el grupo capturado —eso es de JavaScript;
  /// Dart mete esos dos caracteres tal cual— y el titular terminaba peor de lo
  /// que entro: "at 6$1 04 a$1 m$1 EDT". Para leer un grupo hace falta
  /// `replaceAllMapped`.
  static String _limpiarTitulo(String t) {
    return t
        .replaceAllMapped(RegExp(r'\s+([,.:;!?])'), (m) => m[1]!)
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

final noticiasProvider = FutureProvider<Fresh<Noticias>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref.watch(noticiasRepositoryProvider).recientes(paisCodigo: pais.codigo);
});
