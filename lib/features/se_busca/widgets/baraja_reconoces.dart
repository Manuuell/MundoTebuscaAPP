import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/elevation.dart';
import '../../../models/persona.dart';

/// Baraja de personas sin identificar.
///
/// Equivale a `RecognizeDeck.tsx` de la web. La mecanica de deslizar existe
/// porque el gesto es rapido y repetible: quien busca a un familiar puede
/// revisar decenas de fichas seguidas sin levantar el pulgar.
class BarajaReconoces extends StatefulWidget {
  const BarajaReconoces({
    super.key,
    required this.personas,
    required this.alReconocer,
    this.alReiniciar,
  });

  final List<Persona> personas;
  final void Function(Persona) alReconocer;
  final VoidCallback? alReiniciar;

  @override
  State<BarajaReconoces> createState() => _BarajaReconocesState();
}

class _BarajaReconocesState extends State<BarajaReconoces> {
  int _indice = 0;
  Offset _arrastre = Offset.zero;
  bool _soltando = false;

  static const _umbral = 110.0;

  Persona? get _actual =>
      _indice < widget.personas.length ? widget.personas[_indice] : null;

  /// -1 descartar, +1 reconocer, 0 sin decidir. Manda el sello y el color.
  int get _direccion {
    if (_arrastre.dx > 40) return 1;
    if (_arrastre.dx < -40) return -1;
    return 0;
  }

  void _decidir(int direccion) {
    final p = _actual;
    if (p == null) return;
    if (direccion > 0) widget.alReconocer(p);
    setState(() {
      _indice++;
      _arrastre = Offset.zero;
      _soltando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.personas.length;

    if (_actual == null) {
      return _Vacio(
        revisadas: total,
        alReiniciar: total == 0
            ? null
            : () => setState(() {
                  _indice = 0;
                  _arrastre = Offset.zero;
                }),
        alRecargar: widget.alReiniciar,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              Text('${_indice + 1} de $total',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              const Text('Desliza o usa los botones',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // La siguiente ficha asoma por detras: sin eso la baraja parece
              // una sola tarjeta y no se entiende que hay mas.
              if (_indice + 1 < total)
                Transform.translate(
                  offset: const Offset(0, 12),
                  child: Transform.scale(
                    scale: 0.95,
                    child: _Ficha(persona: widget.personas[_indice + 1]),
                  ),
                ),
              GestureDetector(
                onPanUpdate: (d) => setState(() => _arrastre += d.delta),
                onPanEnd: (_) {
                  if (_arrastre.dx.abs() > _umbral) {
                    _decidir(_arrastre.dx > 0 ? 1 : -1);
                  } else {
                    setState(() {
                      _arrastre = Offset.zero;
                      _soltando = true;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: _soltando ? 220 : 0),
                  curve: MTMotion.easeIOS,
                  transform: Matrix4.identity()
                    ..translateByDouble(_arrastre.dx, _arrastre.dy, 0, 1)
                    ..rotateZ(_arrastre.dx / 1400),
                  transformAlignment: Alignment.center,
                  child: _Ficha(
                    persona: _actual!,
                    direccion: _direccion,
                    intensidad:
                        (_arrastre.dx.abs() / _umbral).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BotonRedondo(
              icono: Icons.close_rounded,
              color: AppColors.muted,
              relleno: Colors.white,
              alTocar: () => _decidir(-1),
              etiqueta: 'No la reconozco',
            ),
            const SizedBox(width: 26),
            _BotonRedondo(
              icono: Icons.check_rounded,
              color: Colors.white,
              relleno: const Color(0xFF2F7D57),
              grande: true,
              alTocar: () => _decidir(1),
              etiqueta: 'La reconozco',
            ),
          ],
        ),
      ],
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.persona,
    this.direccion = 0,
    this.intensidad = 0,
  });

  final Persona persona;
  final int direccion;
  final double intensidad;

  @override
  Widget build(BuildContext context) {
    final p = persona;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: MTElevation.cardHover,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: p.fotoUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: p.fotoUrl!, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFDDDDE0),
                          child: const Icon(Icons.image_outlined,
                              size: 58, color: Color(0xFFAAAAB2)),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre.trim().isEmpty ? 'Sin identificar' : p.nombre,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy700),
                    ),
                    if (p.descripcion?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(p.descripcion!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(height: 1.4, fontSize: 14.5)),
                    ],
                    if (p.ubicacion?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 15, color: AppColors.muted),
                          const SizedBox(width: 5),
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
          const Positioned(
            top: 14,
            left: 14,
            child: _PildoraSinIdentificar(),
          ),
          // Sello de la decision, que aparece segun se arrastra. Confirma el
          // gesto antes de soltar: sin el es facil descartar a alguien sin
          // querer.
          if (direccion != 0)
            Positioned(
              top: 26,
              left: direccion > 0 ? 22 : null,
              right: direccion < 0 ? 22 : null,
              child: Opacity(
                opacity: intensidad,
                child: Transform.rotate(
                  angle: direccion > 0 ? -0.24 : 0.24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: direccion > 0
                            ? const Color(0xFF2F7D57)
                            : AppColors.danger500,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    child: Text(
                      direccion > 0 ? 'LA RECONOZCO' : 'OTRA',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 0.5,
                        color: direccion > 0
                            ? const Color(0xFF2F7D57)
                            : AppColors.danger500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PildoraSinIdentificar extends StatelessWidget {
  const _PildoraSinIdentificar();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.navy700,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_rounded, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text('Sin identificar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
    required this.icono,
    required this.color,
    required this.relleno,
    required this.alTocar,
    required this.etiqueta,
    this.grande = false,
  });

  final IconData icono;
  final Color color;
  final Color relleno;
  final VoidCallback alTocar;
  final String etiqueta;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final lado = grande ? 76.0 : 64.0;

    return Semantics(
      button: true,
      label: etiqueta,
      child: Material(
        color: relleno,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: alTocar,
          child: Container(
            width: lado,
            height: lado,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: grande
                  ? null
                  : Border.all(color: AppColors.border, width: 1.5),
              boxShadow: MTElevation.card,
            ),
            child: Icon(icono, size: grande ? 36 : 30, color: color),
          ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.revisadas,
    this.alReiniciar,
    this.alRecargar,
  });

  final int revisadas;
  final VoidCallback? alReiniciar;
  final VoidCallback? alRecargar;

  @override
  Widget build(BuildContext context) {
    final huboFichas = revisadas > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              huboFichas
                  ? Icons.check_circle_outline_rounded
                  : Icons.search_off_rounded,
              size: 52,
              color: huboFichas ? AppColors.success500 : AppColors.border,
            ),
            const SizedBox(height: 16),
            Text(
              huboFichas ? 'Revisaste todas' : 'No hay fichas por revisar',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              huboFichas
                  ? 'Viste las $revisadas fichas sin identificar de esta '
                      'emergencia. Vuelve mas tarde: se publican nuevas cada dia.'
                  : 'Ahora mismo no hay personas encontradas sin identificar '
                      'en esta emergencia.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                if (alReiniciar != null)
                  OutlinedButton(
                      onPressed: alReiniciar, child: const Text('Ver de nuevo')),
                if (alRecargar != null)
                  FilledButton(
                      onPressed: alRecargar, child: const Text('Actualizar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
