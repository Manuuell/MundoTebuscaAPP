import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/noticias_repository.dart';
import '../../widgets/mt_card.dart';

/// Carrusel de noticias verificadas.
class NoticiasCarrusel extends ConsumerWidget {
  const NoticiasCarrusel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticias = ref.watch(noticiasProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Noticias verificadas',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Informacion de fuentes confiables',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        noticias.when(
          loading: () => const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const _Aviso(
              texto: 'No pudimos cargar las noticias ahora mismo.'),
          data: (fresh) {
            if (fresh.data.isEmpty) {
              return const _Aviso(
                  texto: 'No hay noticias recientes para esta emergencia.');
            }
            return SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: fresh.data.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => MTEntrada(
                  indice: i,
                  child: _Tarjeta(noticia: fresh.data[i]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.noticia});

  final Noticia noticia;

  @override
  Widget build(BuildContext context) {
    final n = noticia;

    return SizedBox(
      width: 260,
      child: MTCard(
        padding: EdgeInsets.zero,
        clip: true,
        onTap: n.url == null ? null : () => _confirmarSalida(context, n),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n.fotoUrl != null)
              CachedNetworkImage(
                imageUrl: n.fotoUrl!,
                height: 118,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(height: 118, color: AppColors.bgBase),
                errorWidget: (_, _, _) =>
                    Container(height: 118, color: AppColors.bgBase),
              )
            else
              Container(
                height: 118,
                width: double.infinity,
                color: AppColors.brand50,
                child: const Icon(Icons.newspaper_rounded,
                    size: 34, color: AppColors.brand500),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (n.curada) ...[
                          const Icon(Icons.verified_rounded,
                              size: 13, color: AppColors.success500),
                          const SizedBox(width: 4),
                        ],
                        if (!n.enEspanol) ...[
                          // GDELT devuelve casi todo en ingles para estas
                          // consultas. Avisar del idioma antes de que alguien
                          // toque y se encuentre una nota que no puede leer.
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _codigoIdioma(n.idioma),
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.muted),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            n.fuente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        n.titulo,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (n.url != null)
                      const Row(
                        children: [
                          Icon(Icons.open_in_new_rounded,
                              size: 13, color: AppColors.info500),
                          SizedBox(width: 5),
                          Text('Ver fuente',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.info500,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _codigoIdioma(String? i) => switch (i) {
        'English' => 'EN',
        'Portuguese' => 'PT',
        'French' => 'FR',
        'Urdu' => 'UR',
        _ => (i ?? '??').substring(0, 2).toUpperCase(),
      };

  /// Aviso antes de salir de la app.
  ///
  /// Estas notas vienen de un agregador, no del equipo: la app no responde de
  /// lo que hay al otro lado del enlace, y decirlo antes de abrirlo es el mismo
  /// criterio que ya aplica `ExternalLinkGuard` en la web.
  Future<void> _confirmarSalida(BuildContext context, Noticia n) async {
    final dominio = Uri.tryParse(n.url!)?.host ?? n.url!;

    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vas a salir de la app'),
        content: Text(
          'Esta nota se abre en $dominio, un sitio externo. '
          'El Mundo Te Busca no responde por su contenido.'
          '${n.enEspanol ? '' : '\n\nEsta escrita en ${n.idioma?.toLowerCase()}.'}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir')),
        ],
      ),
    );

    if (salir == true) {
      await launchUrl(Uri.parse(n.url!), mode: LaunchMode.externalApplication);
    }
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => MTCard(
        child: Text(texto, style: const TextStyle(color: AppColors.muted)),
      );
}
