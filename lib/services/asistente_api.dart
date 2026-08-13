import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/env.dart';

/// Mensaje del chat.
class MensajeChat {
  const MensajeChat({required this.deUsuario, required this.texto});

  final bool deUsuario;
  final String texto;

  Map<String, String> get comoApi =>
      {'role': deUsuario ? 'user' : 'assistant', 'content': texto};
}

class AsistenteException implements Exception {
  const AsistenteException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Cliente del asistente.
///
/// Habla con un **proxy propio**, nunca con OpenAI directo: la API key vive en
/// el servidor y jamas viaja en la app. Es el mismo diseno que usa TransCar
/// (`chatbotProxy` en Cloud Functions), y la razon es la misma — un APK o un
/// IPA se descomprime y se le sacan las cadenas en segundos.
///
/// El prompt del sistema tambien vive en el servidor. El cliente solo manda el
/// historial y un bloque pequeno de contexto con la emergencia activa y sus
/// cifras, para que el asistente hable de datos de ahora y no de lo que
/// recuerde de su entrenamiento.
class AsistenteApi {
  const AsistenteApi();

  static const _tiempoLimite = Duration(seconds: 40);

  bool get disponible => Env.asistenteUrl.isNotEmpty;

  /// Respuesta en streaming, token a token.
  Stream<String> responder({
    required List<MensajeChat> historial,
    String? contexto,
  }) async* {
    if (!disponible) {
      throw const AsistenteException(
        'El asistente todavia no esta configurado en esta version.',
      );
    }

    final peticion = http.Request('POST', Uri.parse(Env.asistenteUrl))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        // Solo las ultimas: el historial largo encarece cada llamada y aporta
        // poco en un asistente de consulta puntual.
        'messages': historial.takeLast(12).map((m) => m.comoApi).toList(),
        'context': ?contexto,
        'stream': true,
      });

    try {
      final res = await http.Client().send(peticion).timeout(_tiempoLimite);

      if (res.statusCode == 429) {
        throw const AsistenteException(
          'Muchas consultas seguidas. Espera un momento e intentalo de nuevo.',
        );
      }
      if (res.statusCode != 200) {
        throw AsistenteException(
          'El asistente no pudo responder (${res.statusCode}).',
        );
      }

      final lineas = res.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final linea in lineas) {
        if (!linea.startsWith('data: ')) continue;
        final carga = linea.substring(6).trim();
        if (carga.isEmpty || carga == '[DONE]') continue;

        try {
          final json = jsonDecode(carga) as Map<String, dynamic>;
          if (json['error'] != null) {
            throw AsistenteException('${json['error']}');
          }
          final trozo = (json['choices'] as List?)?.firstOrNull;
          final delta = (trozo as Map?)?['delta'] as Map?;
          final texto = delta?['content'] as String?;
          if (texto != null && texto.isNotEmpty) yield texto;
        } on AsistenteException {
          rethrow;
        } catch (_) {
          // Una linea suelta mal formada no debe cortar la respuesta entera.
        }
      }
    } on AsistenteException {
      rethrow;
    } catch (_) {
      throw const AsistenteException(
        'No pudimos conectar con el asistente. Revisa tu conexion.',
      );
    }
  }
}

extension<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}

final asistenteApiProvider = Provider<AsistenteApi>((ref) {
  return const AsistenteApi();
});
