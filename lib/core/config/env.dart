/// Configuracion de entorno.
///
/// Las llaves NO se versionan ni se empaquetan como asset: entran por
/// `--dart-define` al compilar. La anon key de Supabase es publica por diseno
/// (va protegida por RLS), pero aun asi se inyecta en build para poder apuntar
/// a otro proyecto sin tocar codigo.
///
///     flutter run \
///       --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///       --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Tiles del mapa. El plan deja abierto si se mantiene el proveedor actual
  /// de `CrisisMap.tsx` o se cambia; por eso es configurable y no una
  /// constante enterrada en el widget del mapa.
  static const mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const mapAttribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: '© OpenStreetMap',
  );

  /// Proxy del asistente. Sin esto el chat avisa de que no esta configurado,
  /// en vez de intentar hablar con OpenAI directo — la llave nunca va aqui.
  static const asistenteUrl = String.fromEnvironment('ASISTENTE_URL');

  /// Endpoint que resuelve usuario -> sesion. Ver AuthRepository.entrar.
  static const authUrl = String.fromEnvironment('AUTH_URL');

  /// Permite arrancar la app sin backend (pantallas vacias con su aviso) en
  /// vez de reventar en el `main`. Util mientras se cablea Supabase.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
