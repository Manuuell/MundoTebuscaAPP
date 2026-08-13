import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/freshness.dart';
import '../../models/persona.dart';
import '../../repositories/personas_repository.dart';

final personaProvider =
    FutureProvider.family<Fresh<Persona?>, String>((ref, id) async {
  return ref.watch(personasRepositoryProvider).porId(id);
});

/// Ficha de una persona. Es el destino de `/persona/{id}`, la misma ruta que
/// la web, para que un enlace compartido abra la app si esta instalada.
class PersonaDetalleScreen extends ConsumerWidget {
  const PersonaDetalleScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(personaProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Ficha')),
      body: persona.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('No pudimos cargar la ficha.')),
        data: (fresh) {
          final p = fresh.data;
          if (p == null) {
            return const Center(child: Text('Esta persona ya no esta publicada.'));
          }
          return ListView(
            children: [
              StaleDataBanner(
                fetchedAt: fresh.fetchedAt,
                onRefresh: () => ref.invalidate(personaProvider(id)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(p.estado.etiqueta,
                        style: const TextStyle(color: AppColors.muted)),
                    if (p.ubicacion != null) ...[
                      const SizedBox(height: 12),
                      Text(p.ubicacion!),
                    ],
                    if (p.descripcion != null) ...[
                      const SizedBox(height: 12),
                      Text(p.descripcion!),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
