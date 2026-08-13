import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/publicacion.dart';

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

/// Tarjeta del muro.
///
/// A sangre y separada por una banda de fondo, sin caja redondeada: es la
/// misma decision que ya se tomo en TransCar, donde la caja sobre gris hacia
/// que el muro pareciera un hilo de foro en vez de un feed.
class PublicacionCard extends StatelessWidget {
  const PublicacionCard({super.key, required this.publicacion, this.onTap});

  final Publicacion publicacion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = publicacion;
    final t = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: p.tipo.color.withValues(alpha: 0.15),
                    child: Icon(p.tipo.icono, size: 20, color: p.tipo.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.autor?.trim().isNotEmpty == true
                              ? p.autor!
                              : 'Anonimo',
                          style: t.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        // Meta compacta en una linea, en vez de chips grandes.
                        Row(
                          children: [
                            Text(tiempoTranscurrido(p.creadoEn),
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.muted)),
                            const Text(' · ',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.muted)),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: p.tipo.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(p.tipo.etiqueta,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: p.tipo.color,
                                    fontWeight: FontWeight.w700)),
                            if (p.ubicacion?.isNotEmpty == true)
                              Flexible(
                                child: Text(' · ${p.ubicacion}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.muted)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(p.cuerpo,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(height: 1.4)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  for (final e in p.reacciones.entries) ...[
                    _Reaccion(clave: e.key, cuenta: e.value),
                    const SizedBox(width: 14),
                  ],
                  const Spacer(),
                  // Marca de procedencia: si el post se ingirio de una red
                  // externa, el lector merece saberlo — no lo escribio un
                  // vecino aqui.
                  if (p.esExterno)
                    Text('via ${p.origen}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reaccion extends StatelessWidget {
  const _Reaccion({required this.clave, required this.cuenta});

  final String clave;
  final int cuenta;

  static const _emoji = {
    'apoyo': '🙌',
    'corazon': '❤️',
    'hecho': '✅',
    'gracias': '🙏',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_emoji[clave] ?? '👍', style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text('$cuenta',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
