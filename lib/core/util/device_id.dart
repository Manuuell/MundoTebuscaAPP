import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identificador estable por instalacion.
///
/// Reemplaza el `localStorage` que la web usa para deduplicar votos y likes
/// por dispositivo. Mismo concepto, otro almacen. No identifica a la persona:
/// se regenera si se reinstala la app, y esa es justo la propiedad que
/// queremos (no es una huella digital, es un anti-doble-voto barato).
class DeviceId {
  const DeviceId._();

  static const _key = 'device_uuid';
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }
}
