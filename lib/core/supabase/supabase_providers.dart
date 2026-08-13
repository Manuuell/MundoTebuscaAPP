import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente unico de Supabase.
///
/// El plan decide que Flutter habla directo con Supabase, sin API intermedia:
/// mismas politicas RLS que la web, sin duplicar reglas de negocio en dos
/// lenguajes. Todo repositorio pide el cliente por aqui para poder cambiarlo
/// en tests con un `overrideWithValue`.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Sesion actual. `null` mientras no haya login — la Fase 1 (solo lectura) no
/// lo necesita, pero el provider ya esta para cuando llegue la Fase 3.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.session?.user ??
      ref.watch(supabaseClientProvider).auth.currentUser;
});
