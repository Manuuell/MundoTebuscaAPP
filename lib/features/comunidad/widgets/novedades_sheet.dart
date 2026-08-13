import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/pais_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/freshness.dart';
import '../../../repositories/novedades_repository.dart';
import 'publicacion_card.dart' show tiempoTranscurrido;

final novedadesProvider = FutureProvider<Fresh<List<Novedad>>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref
      .watch(novedadesRepositoryProvider)
      .recientes(paisCodigo: pais.codigo);
});

/// Cuántas novedades hay desde la última vez que se abrió la bandeja.
final sinVerProvider = FutureProvider<int>((ref) async {
  final novedades = await ref.watch(novedadesProvider.future);
  final visto = await UltimaVisita.leer();
  if (visto == null) return novedades.data.length;
  return novedades.data
      .where((n) => n.cuando != null && n.cuando!.isAfter(visto))
      .length;
});

/// Bandeja de novedades de la emergencia.
Future<void> mostrarNovedades(BuildContext context, WidgetRef ref) async {
  await UltimaVisita.marcar();
  ref.invalidate(sinVerProvider);

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetContext, scrollController) => Consumer(
        builder: (_, sheetRef, _) {
          final novedades = sheetRef.watch(novedadesProvider);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text('Novedades',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Cambios recientes en esta emergencia.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
              Expanded(
                child: novedades.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const _Centro(
                      texto: 'No pudimos cargar las novedades.'),
                  data: (fresh) {
                    if (fresh.data.isEmpty) {
                      return const _Centro(
                          texto: 'Todavia no hay novedades que mostrar.');
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: fresh.data.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final n = fresh.data[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: n.color.withValues(alpha: 0.15),
                            child: Icon(n.icono, size: 20, color: n.color),
                          ),
                          title: Text(n.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(n.detalle,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Text(tiempoTranscurrido(n.cuando),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.muted)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Centro extends StatelessWidget {
  const _Centro({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted)),
        ),
      );
}
