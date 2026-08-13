import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_providers.dart';

/// Sesion contra el Supabase real del sitio web.
///
/// El proyecto tiene habilitado email+contrasena y el registro abierto; no hay
/// ningun proveedor OAuth activo, asi que no se ofrece "entrar con Google".
/// `signInAnonymously` tampoco: `anonymous_users` esta en false.
class AuthRepository {
  const AuthRepository(this._db);

  final SupabaseClient _db;

  User? get usuario => _db.auth.currentUser;
  bool get haySesion => usuario != null;

  /// Dominio del correo sintetico que usa el sitio.
  ///
  /// La web no pide correo: pide nombre de usuario y por dentro lo convierte
  /// con `${usuario.toLowerCase()}@users.venezuelatebusca.org` antes de
  /// llamar a Supabase Auth. Replicarlo exacto es lo unico que permite que la
  /// misma cuenta sirva en la web y en la app; el dominio conserva el nombre
  /// original del proyecto, asi que no se puede "corregir" a elmundotebusca.
  static const dominioSintetico = 'users.venezuelatebusca.org';

  /// Acepta indistintamente nombre de usuario o correo real.
  ///
  /// Si lleva arroba se usa tal cual —hay cuentas creadas con correo de
  /// verdad—; si no, se construye el sintetico como hace la web.
  static String correoDe(String entrada) {
    final t = entrada.trim();
    if (t.contains('@')) return t.toLowerCase();
    return '${t.toLowerCase()}@$dominioSintetico';
  }

  Future<AuthResponse> entrar({
    required String usuarioOCorreo,
    required String clave,
  }) {
    return _db.auth.signInWithPassword(
      email: correoDe(usuarioOCorreo),
      password: clave,
    );
  }

  Future<AuthResponse> registrar({
    required String usuarioOCorreo,
    required String clave,
  }) {
    final u = usuarioOCorreo.trim();
    return _db.auth.signUp(
      email: correoDe(u),
      password: clave,
      // El nombre visible es el propio usuario, igual que en la web.
      data: {'display_name': u.contains('@') ? u.split('@').first : u},
    );
  }

  Future<void> salir() => _db.auth.signOut();

  /// Ficha publica del usuario.
  ///
  /// La clave es `user_id`, NO `id` — verificado contra las consultas del
  /// sitio web. Con `id` la fila nunca aparecia y el perfil salia vacio aunque
  /// existiera.
  ///
  /// Las politicas RLS solo dejan ver el propio perfil, asi que sin sesion
  /// esto devuelve null aunque la tabla tenga filas.
  Future<Map<String, dynamic>?> perfil() async {
    final u = usuario;
    if (u == null) return null;
    try {
      return await _db
          .from('profiles')
          .select('user_id, username, avatar_url, bio')
          .eq('user_id', u.id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// URL de la foto lista para pintar.
  ///
  /// `avatar_url` puede venir como URL completa o como ruta dentro del bucket
  /// de Storage; se resuelven las dos.
  String? fotoDe(Map<String, dynamic>? perfil) {
    final crudo = perfil?['avatar_url'] as String?;
    if (crudo == null || crudo.isEmpty) return null;
    if (crudo.startsWith('http')) return crudo;
    return _db.storage.from('avatars').getPublicUrl(crudo);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Sesion actual, reactiva: la UI se entera sola de entrar y salir.
final sesionProvider = StreamProvider<User?>((ref) {
  final db = ref.watch(supabaseClientProvider);
  return db.auth.onAuthStateChange.map((e) => e.session?.user);
});

/// Usuario de ahora mismo, sin esperar al stream (util en el primer frame).
final usuarioProvider = Provider<User?>((ref) {
  final delStream = ref.watch(sesionProvider).valueOrNull;
  return delStream ?? ref.watch(supabaseClientProvider).auth.currentUser;
});

final perfilProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(sesionProvider);
  return ref.watch(authRepositoryProvider).perfil();
});
