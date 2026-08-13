import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/freshness.dart';
import '../../models/publicacion.dart';
import '../../repositories/comunidad_repository.dart';
import 'widgets/publicacion_card.dart';

final comentariosProvider =
    FutureProvider.family<Fresh<List<Comentario>>, String>((ref, id) async {
  return ref.watch(comunidadRepositoryProvider).comentarios(id);
});

/// Detalle de una publicacion con su hilo de comentarios.
class PublicacionDetalleScreen extends ConsumerWidget {
  const PublicacionDetalleScreen({super.key, required this.publicacion});

  final Publicacion publicacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comentarios = ref.watch(comentariosProvider(publicacion.id));

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(title: const Text('Publicacion')),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(comentariosProvider(publicacion.id)),
        child: ListView(
          children: [
            PublicacionCard(publicacion: publicacion),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: comentarios.when(
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )),
                error: (_, _) => const Text(
                    'No pudimos cargar los comentarios.',
                    style: TextStyle(color: AppColors.muted)),
                data: (fresh) => _Hilo(comentarios: fresh.data),
              ),
            ),
            // Comentar es una escritura, y toda escritura pasa por la Edge
            // Function que todavia no existe. En vez de una caja de texto que
            // no envia nada, se dice por que.
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Comentar estara disponible cuando se habiliten las '
                      'cuentas.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hilo extends StatelessWidget {
  const _Hilo({required this.comentarios});

  final List<Comentario> comentarios;

  @override
  Widget build(BuildContext context) {
    if (comentarios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Todavia no hay comentarios.',
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }

    // Las respuestas se cuelgan de su padre en vez de ir en orden plano: el
    // `parent_id` ya existe en la tabla y sin esto una respuesta se lee como
    // un comentario suelto que no viene a cuento.
    final raiz = comentarios.where((c) => !c.esRespuesta).toList();
    final porPadre = <String, List<Comentario>>{};
    for (final c in comentarios.where((c) => c.esRespuesta)) {
      porPadre.putIfAbsent(c.padreId!, () => []).add(c);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          comentarios.length == 1
              ? '1 comentario'
              : '${comentarios.length} comentarios',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final c in raiz) ...[
          _ComentarioTile(comentario: c),
          for (final r in porPadre[c.id] ?? const <Comentario>[])
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _ComentarioTile(comentario: r),
            ),
        ],
      ],
    );
  }
}

class _ComentarioTile extends StatelessWidget {
  const _ComentarioTile({required this.comentario});

  final Comentario comentario;

  @override
  Widget build(BuildContext context) {
    final c = comentario;
    final nombre = c.autor?.trim().isNotEmpty == true ? c.autor! : 'Anonimo';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.brand50,
            child: Text(
              nombre.characters.first.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.brand700, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgBase,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(c.cuerpo,
                          style: const TextStyle(fontSize: 14, height: 1.35)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 4),
                  child: Row(
                    children: [
                      Text(tiempoTranscurrido(c.creadoEn),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                      if (c.likes > 0) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.favorite_rounded,
                            size: 11, color: AppColors.danger500),
                        const SizedBox(width: 3),
                        Text('${c.likes}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
