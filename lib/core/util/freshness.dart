import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dato + el momento exacto en que se trajo de la red.
///
/// Existe por la regla de consistencia del plan (`01-arquitectura.md`): en una
/// app de personas desaparecidas, mostrar un estado viejo como si fuera actual
/// es peligroso. Envolver la respuesta en `Fresh` obliga a que la antiguedad
/// viaje pegada al dato hasta la UI, en vez de depender de que alguien se
/// acuerde de pintar el aviso.
@immutable
class Fresh<T> {
  const Fresh(this.data, this.fetchedAt);

  Fresh.now(this.data) : fetchedAt = DateTime.now();

  final T data;
  final DateTime fetchedAt;

  Duration get age => DateTime.now().difference(fetchedAt);

  /// Por debajo de esto no vale la pena molestar al usuario con el aviso.
  bool get isStale => age > const Duration(minutes: 5);

  Fresh<R> map<R>(R Function(T) f) => Fresh(f(data), fetchedAt);
}

/// "hace 3 min", "hace 2 h", "hace 4 d".
String edadLegible(Duration d) {
  if (d.inMinutes < 1) return 'hace unos segundos';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

/// Franja de "esto no esta fresco" para cualquier pantalla que pinte datos
/// traidos de red. Se muestra sola: si el dato es reciente no ocupa espacio.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({super.key, required this.fetchedAt, this.onRefresh});

  final DateTime fetchedAt;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(fetchedAt);
    if (age <= const Duration(minutes: 5)) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warning500.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded,
              size: 18, color: AppColors.warning500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ultima actualizacion ${edadLegible(age)}. '
              'Puede no reflejar el estado actual.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (onRefresh != null)
            TextButton(onPressed: onRefresh, child: const Text('Actualizar')),
        ],
      ),
    );
  }
}
