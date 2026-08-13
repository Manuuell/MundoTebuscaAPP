import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state/pais_provider.dart';

/// Linea de emergencia.
class LineaEmergencia {
  const LineaEmergencia({required this.numero, required this.etiqueta});

  final String numero;
  final String etiqueta;

  factory LineaEmergencia.fromMap(Map<String, dynamic> m) => LineaEmergencia(
        numero: '${m['number']}',
        etiqueta: '${m['label']}',
      );
}

/// Telefonos de emergencia de un pais.
class InfoEmergencia {
  const InfoEmergencia({
    required this.pais,
    required this.lineaNacional,
    this.grupos = const [],
  });

  final String pais;
  final LineaEmergencia lineaNacional;
  final List<LineaEmergencia> grupos;

  factory InfoEmergencia.fromMap(Map<String, dynamic> m) => InfoEmergencia(
        pais: '${m['country']}',
        lineaNacional: LineaEmergencia.fromMap(
            Map<String, dynamic>.from(m['nationalLine'] as Map)),
        grupos: ((m['groups'] as List?) ?? const [])
            .map((g) =>
                LineaEmergencia.fromMap(Map<String, dynamic>.from(g as Map)))
            .toList(growable: false),
      );
}

/// Guia rapida y telefonos de emergencia.
///
/// **Nunca hace red.** Todo sale de assets empaquetados en la app. La web
/// tambien lo tiene como codigo estatico, y aqui el criterio pesa mas todavia:
/// esta es exactamente la pantalla que se necesita cuando no hay senal.
class GuiaRepository {
  const GuiaRepository();

  Future<List<String>> pasos() async {
    final crudo =
        await rootBundle.loadString('assets/guides/community_guide.json');
    final datos = jsonDecode(crudo) as Map<String, dynamic>;
    return (datos['steps'] as List).cast<String>();
  }

  /// Un archivo por pais, en vez de un switch que crece con cada emergencia
  /// nueva.
  Future<InfoEmergencia?> emergencia(String codigoPais) async {
    try {
      final crudo = await rootBundle.loadString(
          'assets/guides/emergency_lines/${codigoPais.toLowerCase()}.json');
      return InfoEmergencia.fromMap(
          jsonDecode(crudo) as Map<String, dynamic>);
    } catch (_) {
      // Un pais sin archivo no rompe la guia: se muestran los pasos y se
      // omiten los telefonos.
      return null;
    }
  }
}

final guiaRepositoryProvider =
    Provider<GuiaRepository>((ref) => const GuiaRepository());

final pasosGuiaProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(guiaRepositoryProvider).pasos();
});

final emergenciaProvider = FutureProvider<InfoEmergencia?>((ref) {
  final pais = ref.watch(paisProvider);
  return ref.watch(guiaRepositoryProvider).emergencia(pais.codigo);
});
