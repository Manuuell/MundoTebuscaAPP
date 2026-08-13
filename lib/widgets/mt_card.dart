import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/elevation.dart';

/// Tarjeta base del sistema.
///
/// Radio de 24 px en todas las tarjetas de contenido: la web ya estandarizo en
/// `rounded-3xl` y mezclar 16 y 24 segun el componente se nota.
///
/// El error tipico al portar "borde + sombra" de CSS es aplicar los dos con la
/// misma fuerza y que el resultado se vea recargado. Aqui el borde es de 1 px
/// casi imperceptible y quien comunica profundidad es la sombra. Regla: si un
/// widget necesita sombra de nivel 2, se le quita el borde; si necesita borde
/// marcado (un estado de error), se le baja la sombra a nivel 0.
class MTCard extends StatelessWidget {
  const MTCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.elevated = false,
    this.borderColor,
    this.onTap,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Nivel 1 alto en vez de nivel 1. No combinar con un borde marcado.
  final bool elevated;

  final Color? borderColor;
  final VoidCallback? onTap;

  /// Recorta el contenido al radio — necesario si dentro hay una imagen a
  /// sangre que si no se sale por las esquinas.
  final bool clip;

  static const radio = 24.0;

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(padding: padding, child: child);

    return _Presionable(
      onTap: onTap,
      builder: (presionado) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: MTMotion.easeIOS,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radio),
          border: Border.all(color: borderColor ?? AppColors.border),
          boxShadow: (elevated || presionado)
              ? MTElevation.cardHover
              : MTElevation.card,
        ),
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: contenido,
      ),
    );
  }
}

/// Envuelve en feedback de presion solo si hay `onTap`; si no, evita construir
/// un `StatefulWidget` de mas por cada tarjeta de una lista larga.
class _Presionable extends StatefulWidget {
  const _Presionable({required this.builder, this.onTap});

  final Widget Function(bool presionado) builder;
  final VoidCallback? onTap;

  @override
  State<_Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<_Presionable> {
  bool _abajo = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.builder(false);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _abajo = true),
      onTapUp: (_) => setState(() => _abajo = false),
      onTapCancel: () => setState(() => _abajo = false),
      child: AnimatedScale(
        scale: _abajo ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: MTMotion.easeIOS,
        child: widget.builder(_abajo),
      ),
    );
  }
}

/// Feedback de presion para controles sueltos: iconos, chips, items de la tab
/// bar. Equivale a `.press` (`globals.css:354-360`) y es mas simple que una
/// tarjeta — solo escala, sin tocar la sombra.
class Press extends StatefulWidget {
  const Press({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _abajo = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _abajo = true),
      onTapUp: (_) => setState(() => _abajo = false),
      onTapCancel: () => setState(() => _abajo = false),
      child: AnimatedScale(
        scale: _abajo ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Entrada de contenido hacia arriba, con cascada opcional.
///
/// Equivale a `.animate-rise` + `.stagger`. El escalonado se corta pasado el
/// octavo elemento, igual que la web: en una lista de 40 tarjetas, si no, la
/// ultima aparece casi un segundo despues que la primera.
class MTEntrada extends StatelessWidget {
  const MTEntrada({super.key, required this.child, this.indice = 0});

  final Widget child;
  final int indice;

  @override
  Widget build(BuildContext context) {
    // Respeta "reducir movimiento" del sistema: quien lo activa suele hacerlo
    // por mareo o vertigo, no por preferencia estetica.
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final retraso = MTMotion.pasoCascada *
        (indice < MTMotion.maxCascada ? indice : MTMotion.maxCascada);

    return _Rise(retraso: retraso, child: child);
  }
}

class _Rise extends StatefulWidget {
  const _Rise({required this.child, required this.retraso});

  final Widget child;
  final Duration retraso;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: MTMotion.duracionEntrada,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.retraso, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(parent: _ctrl, curve: MTMotion.entrada);
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(curva),
        child: widget.child,
      ),
    );
  }
}
