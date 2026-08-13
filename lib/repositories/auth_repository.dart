import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
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

  /// Dominio de los correos sinteticos que crea el sitio al registrar.
  static const dominioSintetico = 'users.venezuelatebusca.org';

  /// Entra con nombre de usuario, igual que el sitio.
  ///
  /// El correo NO se puede construir a partir del usuario: el sitio guarda un
  /// `login_email` por cuenta en `profiles`, y unas veces es el sintetico y
  /// otras el correo real de la persona. Hay que consultarlo.
  ///
  /// Esa consulta no se puede hacer desde la app: RLS no deja que la llave
  /// anonima lea `profiles` —ni debe, seria la lista de usuarios de una
  /// plataforma de desaparecidos— asi que la resuelve el proxio del servidor,
  /// que devuelve la sesion y nunca el correo.
  Future<void> entrar({
    required String usuarioOCorreo,
    required String clave,
  }) async {
    final entrada = usuarioOCorreo.trim();

    // Con arroba se intenta directo: ahorra un salto y funciona si la persona
    // escribio su correo real.
    if (entrada.contains('@')) {
      await _db.auth
          .signInWithPassword(email: entrada.toLowerCase(), password: clave);
      return;
    }

    if (Env.authUrl.isEmpty) {
      throw const AuthException(
        'El inicio de sesion por usuario no esta configurado en esta version.',
      );
    }

    final res = await http
        .post(
          Uri.parse(Env.authUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': entrada, 'password': clave}),
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode == 429) {
      throw const AuthException(
        'Demasiados intentos. Espera unos minutos antes de reintentar.',
      );
    }
    if (res.statusCode != 200) {
      throw const AuthException('Invalid login credentials');
    }

    final datos = jsonDecode(res.body) as Map<String, dynamic>;
    final refresco = datos['refresh_token'] as String?;
    if (refresco == null) {
      throw const AuthException('Invalid login credentials');
    }

    // Con el refresh token el SDK monta la sesion y la persiste igual que si
    // hubiera hecho el login el mismo.
    await _db.auth.setSession(refresco);
  }

  Future<AuthResponse> registrar({
    required String usuarioOCorreo,
    required String clave,
  }) {
    final u = usuarioOCorreo.trim();
    return _db.auth.signUp(
      email: u.contains('@')
          ? u.toLowerCase()
          : '${u.toLowerCase()}@$dominioSintetico',
      password: clave,
      // El nombre visible es el propio usuario, igual que en la web.
      data: {'display_name': u.contains('@') ? u.split('@').first : u},
    );
  }

  Future<void> salir() => _db.auth.signOut();

  /// Publica un post de comunidad o una ficha de persona.
  ///
  /// Pasa por el servidor y no por Supabase directo: la web quito a proposito
  /// la escritura publica con la llave anonima tras sufrir abuso, asi que la
  /// app tampoco la tiene. El servidor decide que columnas se escriben — si el
  /// cliente pudiera mandar el objeto entero, cualquiera colaria `verified` o
  /// `moderation_status` y publicaria como si lo hubiera revisado alguien.
  Future<String> publicar(Map<String, dynamic> datos) async {
    final token = _db.auth.currentSession?.accessToken;
    if (token == null) {
      throw const AuthException('Necesitas iniciar sesion para publicar.');
    }
    if (Env.authUrl.isEmpty) {
      throw const AuthException('Publicar no esta configurado en esta version.');
    }

    final res = await http
        .post(
          Uri.parse('${Env.authUrl}/publicar'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(datos),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 429) {
      throw const AuthException(
        'Has publicado varias veces seguidas. Espera unos minutos.',
      );
    }
    if (res.statusCode != 200) {
      final cuerpo = jsonDecode(res.body);
      throw AuthException(switch (cuerpo is Map ? cuerpo['error'] : null) {
        'cuerpo_corto' => 'Escribe un poco mas de detalle.',
        'nombre_corto' => 'Falta el nombre de la persona.',
        'sin_sesion' || 'token_invalido' =>
          'Tu sesion caduco. Vuelve a entrar.',
        _ => 'No pudimos publicar. Intentalo de nuevo.',
      });
    }

    return '${(jsonDecode(res.body) as Map)['id']}';
  }

  /// Ficha del usuario.
  ///
  /// Se pide al servidor y no a Supabase directo: `profiles` no tiene politica
  /// RLS de lectura para el propio usuario —el sitio siempre la consulta desde
  /// su backend— asi que desde la app la consulta vuelve vacia y el perfil
  /// caia al trozo del correo como nombre.
  ///
  /// Se intenta primero la via directa por si algun dia se anade esa politica.
  Future<Map<String, dynamic>?> perfil() async {
    final u = usuario;
    if (u == null) return null;

    try {
      final directo = await _db
          .from('profiles')
          .select('user_id, username, avatar_url, bio, recovery_email, email_notifications')
          .eq('user_id', u.id)
          .maybeSingle();
      if (directo != null) return directo;
    } catch (_) {
      // RLS o red: se cae al servidor.
    }

    if (Env.authUrl.isEmpty) return null;
    final token = _db.auth.currentSession?.accessToken;
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('${Env.authUrl}/profile'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) return null;
      final datos = jsonDecode(res.body);
      return datos is Map<String, dynamic> ? datos : null;
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
