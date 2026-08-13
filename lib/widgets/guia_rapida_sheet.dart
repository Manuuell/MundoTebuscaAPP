import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../repositories/guia_repository.dart';

/// Guia rapida de emergencia.
///
/// Va como hoja y no como pantalla nueva: son nueve pasos y un telefono, y una
/// hoja se invoca desde cualquier sitio sin apilar una ruta. Todo el contenido
/// sale de assets locales, asi que abre igual sin conexion.
Future<void> mostrarGuiaRapida(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetContext, controlador) => Consumer(
        builder: (_, ref, _) {
          final pasos = ref.watch(pasosGuiaProvider);
          final emergencia = ref.watch(emergenciaProvider).valueOrNull;

          return ListView(
            controller: controlador,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text('Guia rapida',
                  style: Theme.of(sheetContext).textTheme.headlineMedium),
              const SizedBox(height: 4),
              const Text(
                'Que hacer en las primeras horas. Funciona sin conexion.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),

              // El telefono va primero: si alguien abre esto en una
              // emergencia real, no debe tener que leer nueve pasos para
              // encontrarlo.
              if (emergencia != null) ...[
                _Telefono(
                  numero: emergencia.lineaNacional.numero,
                  etiqueta: emergencia.lineaNacional.etiqueta,
                  destacado: true,
                ),
                const SizedBox(height: 8),
                for (final g in emergencia.grupos) ...[
                  _Telefono(numero: g.numero, etiqueta: g.etiqueta),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 14),
              ],

              pasos.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Text(
                    'No pudimos cargar la guia.',
                    style: TextStyle(color: AppColors.muted)),
                data: (lista) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < lista.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.brand50,
                                shape: BoxShape.circle,
                              ),
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      color: AppColors.brand700,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(lista[i],
                                  style: const TextStyle(height: 1.45)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Telefono extends StatelessWidget {
  const _Telefono({
    required this.numero,
    required this.etiqueta,
    this.destacado = false,
  });

  final String numero;
  final String etiqueta;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final color = destacado ? AppColors.danger500 : AppColors.navy700;

    return Material(
      color: color.withValues(alpha: destacado ? 0.08 : 0.04),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // `tel:` funciona sin datos moviles. Es lo unico de esta hoja que
        // depende del telefono y no de la red.
        onTap: () => launchUrl(
            Uri.parse('tel:${numero.replaceAll(RegExp(r'[^0-9+]'), '')}')),
        child: Padding(
          padding: EdgeInsets.all(destacado ? 16 : 12),
          child: Row(
            children: [
              Text(numero,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: destacado ? 26 : 17,
                  )),
              const SizedBox(width: 14),
              Expanded(
                child: Text(etiqueta,
                    style: TextStyle(fontSize: destacado ? 14 : 13)),
              ),
              Icon(Icons.call_rounded, color: color, size: destacado ? 24 : 20),
            ],
          ),
        ),
      ),
    );
  }
}
