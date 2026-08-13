import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/elevation.dart';

/// Una de las cifras deslizables del Inicio.
///
/// El valor se pinta tal cual llega. Nada de animarlo interpolando desde el
/// valor anterior: al cambiar de pais eso produce numeros negativos en
/// pantalla, que es exactamente el defecto que tiene la web hoy.
class CifraChip extends StatelessWidget {
  const CifraChip({
    super.key,
    required this.valor,
    required this.etiqueta,
    required this.color,
    this.onTap,
  });

  final int valor;
  final String etiqueta;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Una cifra negativa es siempre un error de calculo, no un dato. Antes de
    // ensenarla se corta aqui: el usuario no tiene por que ver el bug.
    final seguro = valor < 0 ? 0 : valor;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: MTElevation.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 8),
            Text(
              '$seguro',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.navy700,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              etiqueta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
