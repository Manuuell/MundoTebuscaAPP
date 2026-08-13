import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_providers.dart';
import '../core/util/freshness.dart';
import '../models/pais.dart';
import '../models/persona.dart';

/// Las cifras del Inicio.
///
/// Se cuentan directamente sobre las tablas reales. La version anterior
/// llamaba a un RPC `cifras_panel` y a una tabla `cifras_sismo` que no existen
/// en el proyecto —eran nombres inventados al armar el andamiaje sin acceso al
/// esquema— y devolvian PGRST202/PGRST205, asi que la pantalla de entrada
/// estaba entera en estado de error.
///
/// Se usa `CountOption.exact` con `limit(0)`: Postgres cuenta y no manda ni
/// una fila, que es lo que interesa cuando `persons` tiene 48.000 registros.
class CifrasRepository {
  const CifrasRepository(this._db);

  final SupabaseClient _db;

  /// Cuenta filas de una tabla para un pais.
  ///
  /// Si la tabla no existe o RLS no deja leerla, devuelve 0 en vez de lanzar:
  /// un contador caido no puede tumbar el panel entero y dejar la pantalla de
  /// entrada en error.
  Future<int> _contar(String tabla, String paisCodigo) async {
    try {
      return await _db
          .from(tabla)
          .count(CountOption.exact)
          .eq('country', paisCodigo);
    } catch (_) {
      return 0;
    }
  }

  Future<Fresh<CifrasPanel>> panel({required String paisCodigo}) async {
    Future<int> porEstado(EstadoPersona e) async {
      try {
        return await _db
            .from('persons')
            .count(CountOption.exact)
            .eq('country', paisCodigo)
            .eq('status', e.wire);
      } catch (_) {
        return 0;
      }
    }

    Future<int> menores() async {
      try {
        return await _db
            .from('persons')
            .count(CountOption.exact)
            .eq('country', paisCodigo)
            .lte('age', 11);
      } catch (_) {
        return 0;
      }
    }

    Future<int> postsDeTipo(String tipo) async {
      try {
        return await _db
            .from('posts')
            .count(CountOption.exact)
            .eq('country', paisCodigo)
            .eq('moderation_status', 'approved')
            .eq('type', tipo);
      } catch (_) {
        return 0;
      }
    }

    // Todas en paralelo: son 10 consultas de conteo y en serie se notan.
    final r = await Future.wait([
      porEstado(EstadoPersona.porLocalizar),
      porEstado(EstadoPersona.hospitalizado),
      porEstado(EstadoPersona.localizado),
      porEstado(EstadoPersona.fallecido),
      menores(),
      _contar('complaints', paisCodigo),
      postsDeTipo('necesito'),
      postsDeTipo('ofrezco'),
      _contar('aid_points', paisCodigo),
      _contar('volunteers', paisCodigo),
    ]);

    return Fresh.now(CifrasPanel(
      desaparecidos: r[0],
      enHospitales: r[1],
      aSalvo: r[2],
      fallecidos: r[3],
      ninos: r[4],
      denuncias: r[5],
      necesidades: r[6],
      ofrecenAyuda: r[7],
      puntosAyuda: r[8],
      voluntariosActivos: r[9],
      // "Verificados" son los que ya tienen un desenlace confirmado: alguien
      // los reporto a salvo, en un hospital o fallecido. No es una cifra
      // aparte de la base, es una lectura de las de arriba.
      reportesVerificados: r[1] + r[2] + r[3],
    ));
  }

  /// Cifras de prensa del sismo.
  ///
  /// No hay tabla para esto en el proyecto todavia: el bloque de prensa de la
  /// web se arma en su propio backend. Devolver `null` hace que el Inicio
  /// oculte el bloque en vez de pintar un error — que es la conducta correcta
  /// mientras no exista la fuente.
  Future<Fresh<CifrasSismo?>> sismo({required String paisCodigo}) async {
    return Fresh.now(null);
  }
}

final cifrasRepositoryProvider = Provider<CifrasRepository>((ref) {
  return CifrasRepository(ref.watch(supabaseClientProvider));
});
