import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'mt_card.dart' show Press;

/// Selector de pestañas estilo iOS (segmented control), para usar como
/// `AppBar.bottom` en pantallas con `TabBarView`.
///
/// El `TabBar` de Material (subrayado + texto suelto, alineado a la
/// izquierda) es el "muy plano" del que se quejo el dueño. Este dibuja una
/// pastilla que se desliza detras de la pestaña activa dentro de una pista
/// redondeada — mismo espiritu que `FloatingTabBar` (la barra inferior), pero
/// con relleno de marca (`brand50`) en vez de blanco+sombra: son dos niveles
/// distintos (navegacion vs. seleccion de contenido) y conviene que se lean
/// distintos, no identicos.
///
/// La pastilla sigue el `TabController.animation` en vivo: se desliza al
/// mismo ritmo que el dedo si se desliza el `TabBarView`, no solo al tocar.
class SegmentedTabs extends StatelessWidget implements PreferredSizeWidget {
  const SegmentedTabs({super.key, required this.tabs});

  final List<String> tabs;

  static const _altura = 40.0;
  static const _relleno = 3.0;
  static const _paddingInferior = 12.0;

  @override
  Size get preferredSize =>
      const Size.fromHeight(_altura + _paddingInferior);

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, _paddingInferior),
      child: SizedBox(
        height: _altura,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_altura / 2),
            border: Border.all(color: AppColors.border),
          ),
          child: AnimatedBuilder(
            animation: controller.animation!,
            builder: (context, _) {
              final valor = controller.animation!.value;
              final maximo = (tabs.length - 1).toDouble();
              final posicion = valor < 0 ? 0.0 : (valor > maximo ? maximo : valor);
              final activo = posicion.round();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final anchoSegmento = constraints.maxWidth / tabs.length;
                  return Stack(
                    children: [
                      Positioned(
                        left: posicion * anchoSegmento + _relleno,
                        top: _relleno,
                        bottom: _relleno,
                        width: anchoSegmento - _relleno * 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.brand50,
                            borderRadius: BorderRadius.circular(
                                (_altura - _relleno * 2) / 2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            Expanded(
                              child: _Segmento(
                                texto: tabs[i],
                                activo: activo == i,
                                onTap: () => controller.animateTo(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento({
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      child: SizedBox.expand(
        child: Center(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
              color: activo ? AppColors.brand700 : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
