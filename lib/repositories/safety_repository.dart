import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_providers.dart';
import '../core/util/device_id.dart';

enum SafetyError { locationDenied, locationServiceOff, notOptedIn, network }

class SafetyException implements Exception {
  const SafetyException(this.type);

  final SafetyError type;
}

/// Red de auxilio: check-in "¿estas bien?" tras un sismo.
///
/// Ver plan-app-movil/investigacion-tecnica/10-alerta-sismo-checkin.md.
/// Habla SIEMPRE con la Edge Function `safety-optin`, nunca directo con
/// `safety_optins`/`safety_checkins`: esas tablas no tienen ninguna politica
/// publica a proposito (ver supabase/schema.sql del repo web) porque es
/// ubicacion en vivo de una persona real, no un dato mas.
class SafetyRepository {
  const SafetyRepository(this._db);

  final SupabaseClient _db;

  static const _prefsKey = 'red_auxilio_activa';
  static const _funcion = 'safety-optin';

  Future<bool> activaLocalmente() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> _guardarLocal(bool activa) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, activa);
  }

  Future<Position> _ubicacionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const SafetyException(SafetyError.locationServiceOff);
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw const SafetyException(SafetyError.locationDenied);
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  }

  /// Activa el interruptor: pide permiso, toma la ubicacion actual y
  /// registra el opt-in en el servidor. Si algo falla no se guarda nada
  /// local, para que el interruptor no quede "encendido" a medias.
  Future<void> activar({required String paisCodigo}) async {
    final pos = await _ubicacionActual();
    final deviceId = await DeviceId.get();

    final res = await _db.functions.invoke(_funcion, body: {
      'action': 'activate',
      'device_id': deviceId,
      'country': paisCodigo,
      'lat': pos.latitude,
      'lng': pos.longitude,
    });
    if (res.status != 200) throw const SafetyException(SafetyError.network);

    await _guardarLocal(true);
  }

  /// Se apaga localmente aunque falle la red: nadie deberia quedar sin poder
  /// desactivar el interruptor por falta de senal. La proxima apertura con
  /// red reintenta el lado servidor porque `actualizarUbicacionSiActiva` ya
  /// no corre (el interruptor local quedo apagado).
  Future<void> desactivar() async {
    final deviceId = await DeviceId.get();
    await _guardarLocal(false);

    final res = await _db.functions.invoke(_funcion, body: {
      'action': 'deactivate',
      'device_id': deviceId,
    });
    if (res.status != 200) throw const SafetyException(SafetyError.network);
  }

  /// Llamar en cada apertura de la app: mantiene la ultima ubicacion al dia
  /// sin necesitar tracking en segundo plano (ver §3 del diseno). Oportunista
  /// a proposito: si falla no interrumpe el uso normal de la app.
  Future<void> actualizarUbicacionSiActiva() async {
    if (!await activaLocalmente()) return;
    try {
      final pos = await _ubicacionActual();
      final deviceId = await DeviceId.get();
      await _db.functions.invoke(_funcion, body: {
        'action': 'update-location',
        'device_id': deviceId,
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    } catch (_) {
      // silencioso a proposito, ver docstring
    }
  }

  /// Dispara un check-in de prueba sin esperar un sismo real ni el cron de
  /// USGS (todavia no conectado) — para poder probar el flujo completo hoy.
  Future<void> probarAlerta() async {
    final deviceId = await DeviceId.get();
    final res = await _db.functions.invoke(_funcion, body: {
      'action': 'test-alert',
      'device_id': deviceId,
    });
    if (res.status == 404) {
      throw const SafetyException(SafetyError.notOptedIn);
    }
    if (res.status != 200) throw const SafetyException(SafetyError.network);
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(ref.watch(supabaseClientProvider));
});
