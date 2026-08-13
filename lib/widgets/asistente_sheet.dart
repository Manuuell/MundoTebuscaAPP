import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/elevation.dart';
import 'mt_card.dart' show Press;

/// Botón flotante del asistente: una burbuja circular independiente de la tab
/// bar, apoyada justo encima del ítem "Más".
///
/// Antes vivía en la cabecera; se sube aquí porque el asistente es una acción
/// disponible en cualquier pantalla — igual que la tab bar — y no algo propio
/// de cada AppBar. Va a `Rutas.asistente` directo en vez de abrir una hoja: el
/// chat necesita su propio scroll y estado, que no cabe cómodo en un
/// `BottomSheet`.
class BotonAsistenteFlotante extends StatelessWidget {
  const BotonAsistenteFlotante({super.key});

  static const diametro = 46.0;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: () => context.push(Rutas.asistente),
      child: Container(
        width: diametro,
        height: diametro,
        decoration: const BoxDecoration(
          color: AppColors.brand500,
          shape: BoxShape.circle,
          boxShadow: MTElevation.cardHover,
        ),
        child: const Icon(Icons.smart_toy_rounded,
            size: 22, color: Colors.white),
      ),
    );
  }
}
