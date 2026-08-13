import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/elevation.dart';
import 'mt_card.dart' show Press;

/// Item de la tab bar.
typedef ItemTab = ({IconData icono, IconData iconoActivo, String etiqueta});

/// Tab bar flotante estilo iOS 26 (Liquid Glass).
///
/// A diferencia de `MobileNav.tsx:150-153` de la web —que va pegada al borde
/// con `inset-x-0 bottom-0` y un simple `border-t`— esta flota en una capsula
/// con inset lateral e inferior. Es una mejora nueva de la app, no una
/// migracion 1:1: en nativo se puede seguir el lenguaje visual actual de iOS
/// sin las limitaciones de `position: fixed` en CSS.
///
/// El material glass se reserva para la capa de navegacion. Apple es explicita
/// en que no debe usarse dentro del contenido — meterlo tambien en cada
/// tarjeta destruiria la jerarquia que el propio material comunica.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.items,
    required this.indiceActual,
    required this.alTocar,
  });

  final List<ItemTab> items;
  final int indiceActual;
  final ValueChanged<int> alTocar;

  /// Alto de la capsula mas su margen inferior. Las listas necesitan este
  /// hueco al final o la ultima tarjeta queda debajo de la barra.
  static const alturaOcupada = 76.0;

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 12 + abajo,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          // El blur es un filtro no local: repinta todo lo que hay debajo en
          // cada frame que cambia. En una barra que no se anima sola el coste
          // es asumible, pero por eso no se pone tambien en las tarjetas.
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.55)),
              // Nivel 1 alto, que proyecta hacia abajo. La sombra de hoja va
              // hacia arriba y aqui quedaria al reves.
              boxShadow: MTElevation.cardHover,
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _Item(
                      item: items[i],
                      activo: i == indiceActual,
                      alTocar: () => alTocar(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.item,
    required this.activo,
    required this.alTocar,
  });

  final ItemTab item;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.brand700 : AppColors.muted;

    return Press(
      onTap: alTocar,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              activo ? item.iconoActivo : item.icono,
              key: ValueKey(activo),
              size: 23,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.1,
              color: color,
              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
