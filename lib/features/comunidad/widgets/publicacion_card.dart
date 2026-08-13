import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/publicacion.dart';
import '../../../widgets/mt_card.dart';

/// "hace 3 min", "hace 2 h", "hace 4 d".
String tiempoTranscurrido(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  if (d.inDays < 7) return 'hace ${d.inDays} d';
  return '${t.day}/${t.month}/${t.year}';
}

/// Tarjeta del muro, con el mismo lenguaje visual que la web: recuadro
/// redondeado con profundidad, chips de tipo y de origen, enlace externo y
/// pildoras de reaccion.
class PublicacionCard extends StatelessWidget {
  const PublicacionCard({super.key, required this.publicacion, this.onTap});

  final Publicacion publicacion;
  final VoidCallback? onTap;

  static const _emoji = {
    'gracias': '🙏',
    'corazon': '❤️',
    'hecho': '✅',
    'apoyo': '🙌',
  };

  /// Las tres pildoras salen siempre, en el mismo orden, aunque el post no
  /// traiga esa reaccion — igual que en la web. Un feed donde cada tarjeta
  /// tiene distinto numero de botones se lee desordenado.
  static const _ordenReacciones = ['gracias', 'corazon', 'hecho'];

  @override
  Widget build(BuildContext context) {
    final p = publicacion;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      child: MTCard(
        padding: EdgeInsets.zero,
        clip: true,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.bgBase,
                    child: const Icon(Icons.person_rounded,
                        size: 24, color: AppColors.border),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.autor?.trim().isNotEmpty == true
                                    ? p.autor!
                                    : 'Anonimo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5),
                              ),
                            ),
                            Text(' · ${tiempoTranscurrido(p.creadoEn)}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Chip(
                              texto: p.tipo.etiqueta,
                              icono: p.tipo.icono,
                              color: p.tipo.color,
                            ),
                            // Procedencia: quien lee merece saber que esto no
                            // lo escribio un vecino aqui, sino que se ingirio
                            // de una red externa.
                            if (p.esExterno)
                              _Chip(
                                texto: 'Importado de ${p.origen}',
                                icono: Icons.cloud_download_rounded,
                                color: AppColors.info500,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (p.fijado)
                    const Icon(Icons.push_pin_rounded,
                        size: 16, color: AppColors.brand700),
                ],
              ),
            ),

            // ── Cuerpo ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(p.cuerpo,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(height: 1.45, fontSize: 15)),
            ),

            if (p.fotoUrl?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: CachedNetworkImage(
                  imageUrl: p.fotoUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(height: 180, color: AppColors.border),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),

            if (p.enlaceUrl?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse(p.enlaceUrl!),
                      mode: LaunchMode.externalApplication),
                  child: const Row(
                    children: [
                      Icon(Icons.open_in_new_rounded,
                          size: 17, color: AppColors.info500),
                      SizedBox(width: 8),
                      Text('Ver enlace / video',
                          style: TextStyle(
                              color: AppColors.info500,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Divider(height: 1),
            ),

            // ── Reacciones ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  for (final k in _ordenReacciones) ...[
                    _Pildora(
                      emoji: _emoji[k]!,
                      cuenta: p.reacciones[k] ?? 0,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  const Icon(Icons.bookmark_border_rounded,
                      size: 21, color: AppColors.muted),
                  const SizedBox(width: 6),
                ],
              ),
            ),

            InkWell(
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Icon(Icons.mode_comment_outlined,
                        size: 18, color: AppColors.muted),
                    SizedBox(width: 8),
                    Text('Comentar',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.icono, required this.color});

  final String texto;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 5),
          Text(texto,
              style: TextStyle(
                  fontSize: 11.5,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Pildora de reaccion.
///
/// Se ve como boton pero no reacciona al tocarla: guardar una reaccion es una
/// escritura, y la escritura pasa por la Edge Function que todavia no existe.
/// Un "me apoya" que no guarda nada engana mas que no tenerlo.
class _Pildora extends StatelessWidget {
  const _Pildora({required this.emoji, required this.cuenta});

  final String emoji;
  final int cuenta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('$cuenta',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
