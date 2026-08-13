import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_providers.dart';
import '../core/theme/app_colors.dart';
import '../core/util/freshness.dart';

/// Una novedad de la emergencia.
class Novedad {
  const Novedad({
    required this.id,
    required this.titulo,
    required this.detalle,
    required this.icono,
    required this.color,
    this.cuando,
  });

  final String id;
  final String titulo;
  final String detalle;
  final IconData icono;
  final Color color;
  final DateTime? cuando;
}

/// Novedades del país activo.
///
/// No son notificaciones por usuario: la app todavía no tiene sesión, así que
/// no existe "tus" notificaciones. Son los cambios recientes de la emergencia,
/// que es lo que de verdad quiere saber quien abre esto — y sale de datos
/// reales, no de una bandeja inventada.
class NovedadesRepository {
  const NovedadesRepository(this._db);

  final SupabaseClient _db;

  Future<Fresh<List<Novedad>>> recientes({
    required String paisCodigo,
    int limite = 25,
  }) async {
    final novedades = <Novedad>[];

    // Personas localizadas: la novedad que a la gente le importa de verdad.
    try {
      final rows = await _db
          .from('persons')
          .select('id, first_name, last_name, location_text, updated_at')
          .eq('country', paisCodigo)
          .eq('status', 'localizado')
          .order('updated_at', ascending: false)
          .limit(limite);

      for (final r in rows) {
        final nombre = [r['first_name'], r['last_name']]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .join(' ');
        novedades.add(Novedad(
          id: 'p_${r['id']}',
          titulo: nombre.isEmpty ? 'Una persona fue localizada' : nombre,
          detalle: 'Reportada a salvo'
              '${r['location_text'] != null ? ' · ${r['location_text']}' : ''}',
          icono: Icons.check_circle_rounded,
          color: AppColors.success500,
          cuando: DateTime.tryParse('${r['updated_at']}'),
        ));
      }
    } catch (_) {
      // Una fuente caída no vacía la bandeja entera.
    }

    // Publicaciones fijadas: lo que quien modera decidió destacar.
    try {
      final rows = await _db
          .from('posts')
          .select('id, body, created_at')
          .eq('country', paisCodigo)
          .eq('moderation_status', 'approved')
          .eq('pinned', true)
          .order('created_at', ascending: false)
          .limit(10);

      for (final r in rows) {
        novedades.add(Novedad(
          id: 'f_${r['id']}',
          titulo: 'Publicación destacada',
          detalle: '${r['body']}',
          icono: Icons.push_pin_rounded,
          color: AppColors.brand700,
          cuando: DateTime.tryParse('${r['created_at']}'),
        ));
      }
    } catch (_) {}

    novedades.sort((a, b) {
      final x = a.cuando, y = b.cuando;
      if (x == null || y == null) return 0;
      return y.compareTo(x);
    });

    return Fresh.now(novedades.take(limite).toList(growable: false));
  }
}

final novedadesRepositoryProvider = Provider<NovedadesRepository>((ref) {
  return NovedadesRepository(ref.watch(supabaseClientProvider));
});

/// Marca de la última vez que se abrió la bandeja, para poder decir cuántas
/// novedades hay sin ver. Sin sesión no hay forma de saberlo por usuario, así
/// que se guarda por dispositivo.
class UltimaVisita {
  const UltimaVisita._();

  static const _clave = 'novedades_vistas_en';

  static Future<DateTime?> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_clave);
    return v == null ? null : DateTime.tryParse(v);
  }

  static Future<void> marcar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, DateTime.now().toIso8601String());
  }
}
