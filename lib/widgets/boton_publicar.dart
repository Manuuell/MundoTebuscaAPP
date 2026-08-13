import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/elevation.dart';
import 'floating_tab_bar.dart';

/// Boton cuadrado de publicar, centrado sobre la tab bar.
///
/// Va centrado y no en la esquina porque la esquina derecha ya es del
/// asistente: dos botones flotantes ahi se solapan, que es justo lo que
/// pasaba antes.
///
/// Cuadrado en vez de pastilla alargada por la misma razon — una pastilla
/// ocupa medio ancho de pantalla y vuelve a chocar con el asistente en
/// telefonos estrechos.
class BotonPublicar extends StatelessWidget {
  const BotonPublicar({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.alTocar,
  });

  final IconData icono;

  /// Se pinta debajo del icono y ademas va como etiqueta accesible: un boton
  /// solo con icono no dice nada a un lector de pantalla.
  final String etiqueta;

  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Por encima de la tab bar flotante, que si no lo tapa.
      padding: EdgeInsets.only(bottom: FloatingTabBar.alturaOcupada - 10),
      child: Semantics(
        button: true,
        label: etiqueta,
        child: Material(
          color: AppColors.brand500,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: alTocar,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: MTElevation.cardHover,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, color: Colors.white, size: 25),
                  const SizedBox(height: 3),
                  Text(
                    etiqueta,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
