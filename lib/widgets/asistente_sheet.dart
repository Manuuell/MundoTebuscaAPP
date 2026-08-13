import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'mt_card.dart' show Press;

/// Punto de entrada del asistente virtual.
///
/// Va en la cabecera y no como boton flotante, por la misma razon que la guia
/// rapida: ya hay una tab bar flotante y un segundo elemento flotante
/// competiria con ella.
class BotonAsistente extends StatelessWidget {
  const BotonAsistente({super.key});

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: () => mostrarAsistente(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        padding: const EdgeInsets.all(7),
        decoration: const BoxDecoration(
          color: AppColors.brand50,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.smart_toy_rounded,
            size: 21, color: AppColors.brand700),
      ),
    );
  }
}

/// Vista previa del asistente.
///
/// El bot todavia no existe: esto documenta donde vive el acceso y deja el
/// campo desactivado, en vez de aceptar texto que no va a ninguna parte.
Future<void> mostrarAsistente(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: AppColors.brand50, shape: BoxShape.circle),
                  child: const Icon(Icons.smart_toy_rounded,
                      color: AppColors.brand700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Asistente',
                          style:
                              Theme.of(sheetContext).textTheme.titleLarge),
                      const Text('En construccion',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Hola. Cuando este listo podre ayudarte a buscar una persona, '
                'encontrar el punto de ayuda mas cercano o explicarte que '
                'hacer en las primeras horas.',
                style: TextStyle(height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Escribe tu pregunta…',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.send_rounded),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'El asistente todavia no esta disponible.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
