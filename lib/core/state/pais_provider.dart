import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/pais.dart';

/// Emergencias que la app sabe mostrar hoy.
///
/// Semilla local a proposito: es lo primero que se pinta al abrir y no puede
/// depender de una consulta de red. La lista real (con magnitud y fecha
/// actualizadas) llega despues del backend y sobreescribe estos valores.
const paisesSemilla = <Pais>[
  Pais(
    codigo: 'co',
    nombre: 'Colombia',
    bandera: '🇨🇴',
    magnitud: 'M7,4',
    lineaEmergencia: '123',
  ),
  Pais(
    codigo: 've',
    nombre: 'Venezuela',
    bandera: '🇻🇪',
    magnitud: 'M7,2 y 7,5',
    lineaEmergencia: '911',
  ),
];

/// Pais activo. Se persiste para que la app abra donde el usuario la dejo.
///
/// La web arranca por defecto en la emergencia mas antigua; aqui el defecto es
/// la primera de la lista, que es la mas reciente. Abrir en una emergencia
/// vieja es desorientador para quien acaba de vivir la nueva.
class PaisNotifier extends Notifier<Pais> {
  static const _key = 'pais_activo';

  @override
  Pais build() => paisesSemilla.first;

  Future<void> cargarGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final codigo = prefs.getString(_key);
    if (codigo == null) return;
    for (final p in paisesSemilla) {
      if (p.codigo == codigo) {
        state = p;
        return;
      }
    }
  }

  Future<void> cambiar(Pais pais) async {
    state = pais;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pais.codigo);
  }
}

final paisProvider = NotifierProvider<PaisNotifier, Pais>(PaisNotifier.new);

/// Si el usuario ya vio el modal de seleccion de pais (primer lanzamiento).
final yaVioIntroProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('vio_intro_pais') ?? false;
});
