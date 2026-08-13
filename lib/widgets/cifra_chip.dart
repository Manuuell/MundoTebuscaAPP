import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 116,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$seguro',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
