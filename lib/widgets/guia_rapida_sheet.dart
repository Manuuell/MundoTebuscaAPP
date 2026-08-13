import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_colors.dart';
import '../core/util/guia_claves.dart';
import '../repositories/guia_repository.dart';
import 'guia_interactiva.dart';
import 'mt_card.dart' show Press;

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
              const SizedBox(height: 14),
              Press(
                onTap: () {
                  Navigator.pop(sheetContext);
                  iniciarRecorridoGuiado(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.brand50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.brand500.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.explore_rounded,
                          color: AppColors.brand700, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Recorrido guiado por la app',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand700),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.brand700, size: 20),
                    ],
                  ),
                ),
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

/// Recorrido guiado: spotlight en vivo sobre la tab bar real, tocando
/// pantalla por pantalla.
///
/// Es el punto de extensión para cada sección: Manuu puede añadir aquí (o en
/// un `pasosGuiaComunidad()` propio, encadenado después de estos) los pasos
/// que señalen el botón de publicar en el muro/voluntarios/caravanas/
/// denuncias; jerdiaz los de filtros y mapa. El patrón es siempre el mismo:
/// declarar una `GlobalKey` en `guia_claves.dart`, ponerla en el widget real
/// con `key:`, y añadir un `GuiaPaso` que la señale.
Future<void> iniciarRecorridoGuiado(BuildContext context) {
  final router = GoRouter.of(context);

  return iniciarGuiaInteractiva(context, [
    GuiaPaso(
      objetivo: GuiaClaves.tabInicio,
      titulo: 'Inicio',
      texto: 'Cifras del terremoto, noticias y accesos rápidos a lo más '
          'urgente. Es la primera pantalla que ves al abrir la app.',
      alEntrar: (_) async => router.go(Rutas.inicio),
    ),
    GuiaPaso(
      objetivo: GuiaClaves.tabSeBusca,
      titulo: 'Se busca',
      texto: 'Personas que se buscan. Cambia a "¿La reconoces?" para pasar '
          'fichas una por una, como si repasaras una lista.',
      alEntrar: (_) async => router.go(Rutas.seBusca),
    ),
    GuiaPaso(
      objetivo: GuiaClaves.tabComunidad,
      titulo: 'Comunidad',
      texto: 'El muro: publicaciones de necesito/ofrezco ayuda, voluntarios, '
          'caravanas y denuncias. Todo lo que la gente reporta en vivo.',
      alEntrar: (_) async => router.go(Rutas.comunidad),
    ),
    GuiaPaso(
      objetivo: GuiaClaves.tabMapa,
      titulo: 'Mapa',
      texto: 'Puntos de ayuda, hospitales, rescates y la zona del epicentro, '
          'todo en un mapa.',
      alEntrar: (_) async => router.go(Rutas.mapa),
    ),
    GuiaPaso(
      objetivo: GuiaClaves.tabAjustes,
      titulo: 'Ajustes',
      texto: 'Tu perfil, país activo y la Red de auxilio: el interruptor '
          'que comparte tu ubicación si hay un sismo cerca y no respondes.',
      alEntrar: (_) async => router.go(Rutas.configuracion),
    ),
    GuiaPaso(
      objetivo: GuiaClaves.botonAsistente,
      titulo: 'Asistente',
      texto: 'Siempre a mano, sobre "Más". Pregúntale dónde ir o qué hacer '
          'y te guía dentro de la app.',
    ),
  ]);
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
