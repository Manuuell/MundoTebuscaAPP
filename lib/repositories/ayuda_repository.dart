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
  static const _tablaHospitales = 'hospitals';

  /// `tipos` filtra en el cliente, no en el servidor: `aid_points.types` es
  /// un array de categorías del punto (comida/agua/medicina/...), un dominio
  /// de valores distinto al de las capas del mapa (`TipoPunto`). Toda fila de
  /// `aid_points` es capa `ayuda`; la capa `hospital` sale de su propia tabla.
  Future<Fresh<List<PuntoAyuda>>> listar({
    required String paisCodigo,
    Set<TipoPunto>? tipos,
  }) async {
    final quiere = tipos == null || tipos.isEmpty ? TipoPunto.values.toSet() : tipos;

    // En paralelo: son dos tablas sin relación, encadenarlas solo suma espera.
    // Cada una se pide únicamente si su capa está encendida.
    final (ayuda, hospitales) = await (
      quiere.contains(TipoPunto.ayuda)
          ? _leer(_tabla, paisCodigo, PuntoAyuda.fromMap)
          : Future.value(const <PuntoAyuda>[]),
      quiere.contains(TipoPunto.hospital)
          ? _leer(_tablaHospitales, paisCodigo, PuntoAyuda.desdeHospital)
          : Future.value(const <PuntoAyuda>[]),
    ).wait;

    return Fresh.now([...ayuda, ...hospitales]);
  }

  /// Una capa caída no vacía el mapa entero: si `hospitals` falla, los puntos
  /// de ayuda se siguen viendo. En una emergencia media respuesta correcta
  /// vale más que una pantalla en blanco.
  Future<List<PuntoAyuda>> _leer(
    String tabla,
    String paisCodigo,
    PuntoAyuda Function(Map<String, dynamic>) construir,
  ) async {
    try {
      final rows = await _db
          .from(tabla)
          .select()
          .eq('country', paisCodigo)
          .order('updated_at', ascending: false);
      return rows.map(construir).toList(growable: false);
    } catch (_) {
      return const [];
    }
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
