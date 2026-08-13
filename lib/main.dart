import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sin llaves la app arranca igual, con las pantallas en su estado de error.
  // Es preferible a una pantalla negra: durante el desarrollo se puede navegar
  // toda la UI sin backend, y en produccion el fallo se ve, no se esconde.
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // `anonKey` sigue funcionando pero esta marcada para desaparecer en la
      // proxima mayor del SDK; el nombre nuevo acepta la misma llave.
      publishableKey: Env.supabaseAnonKey,
    );
  } else {
    debugPrint(
      'AVISO: sin SUPABASE_URL / SUPABASE_ANON_KEY. '
      'Pasalos con --dart-define (ver lib/core/config/env.dart).',
    );
  }

  runApp(const ProviderScope(child: MundoTeBuscaApp()));
}
