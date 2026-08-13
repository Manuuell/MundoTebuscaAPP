import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/persona.dart';
import '../../../widgets/mt_card.dart';

/// Color de cada estado. Los mismos que usan los chips y el mockup.
Color colorEstado(EstadoPersona e) => switch (e) {
      EstadoPersona.porLocalizar => AppColors.danger500,
      EstadoPersona.hospitalizado => AppColors.info500,
      EstadoPersona.localizado => AppColors.success500,
      EstadoPersona.fallecido => AppColors.navy700,
    };

/// Tarjeta de persona en la lista.
class PersonaTile extends StatelessWidget {
  const PersonaTile({super.key, required this.persona, this.onTap});

  final Persona persona;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = persona;
    final color = colorEstado(p.estado);
    final sinNombre = p.nombre.trim().isEmpty;

    return MTCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cuadrado redondeado tintado con el color del estado, no un
          // circulo: se distingue de los avatares de Comunidad, que si son
          // personas que escriben.
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 62,
              height: 62,
              child: p.fotoUrl?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: p.fotoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _Marcador(color: color, p: p),
                      errorWidget: (_, _, _) => _Marcador(color: color, p: p),
                    )
                  : _Marcador(color: color, p: p),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sinNombre ? 'Sin identificar' : p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy700,
                      height: 1.2),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Insignia(
                        texto: p.estado.etiqueta,
                        color: color,
                        relleno: color.withValues(alpha: 0.10)),
                    if (p.esNoIdentificada)
                      const _Insignia(
                        texto: 'Sin identificar',
                        color: Colors.white,
                        relleno: AppColors.navy700,
                        icono: Icons.visibility_rounded,
                      ),
                    if (p.esMenor)
                      _Insignia(
                          texto: 'Menor',
                          color: AppColors.warning500,
                          relleno:
                              AppColors.warning500.withValues(alpha: 0.14)),
                  ],
                ),
                if (p.ubicacion?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 15, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(p.ubicacion!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5, color: AppColors.muted)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.color, required this.p});

  final Color color;
  final Persona p;

  @override
  Widget build(BuildContext context) => Container(
        color: color.withValues(alpha: 0.10),
        alignment: Alignment.center,
        child: Icon(
          p.esNoIdentificada
              ? Icons.image_outlined
              : Icons.person_outline_rounded,
          color: color,
          size: 26,
        ),
      );
}

class _Insignia extends StatelessWidget {
  const _Insignia({
    required this.texto,
    required this.color,
    required this.relleno,
    this.icono,
  });

  final String texto;
  final Color color;
  final Color relleno;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: relleno,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(texto,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
