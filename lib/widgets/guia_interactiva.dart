import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/elevation.dart';
import 'mt_card.dart' show Press;

/// Un paso de la guía interactiva: resalta [objetivo] y difumina el resto.
///
/// [objetivo] debe ser la `GlobalKey` del widget real que se quiere señalar
/// (un ítem de la tab bar, un botón, una tarjeta…), no una recreación. Así la
/// guía siempre apunta al control de verdad, aunque cambie de sitio.
///
/// [alEntrar] permite que un paso viva en OTRA pantalla: por ejemplo, cambiar
/// de pestaña o hacer `context.push(...)` antes de resaltar algo ahí. La guía
/// espera un frame tras ejecutarlo para que el nuevo árbol exista antes de
/// medir [objetivo].
class GuiaPaso {
  const GuiaPaso({
    required this.objetivo,
    required this.titulo,
    required this.texto,
    this.alEntrar,
    this.forma = FormaFoco.circulo,
  });

  final GlobalKey objetivo;
  final String titulo;
  final String texto;
  final Future<void> Function(BuildContext context)? alEntrar;
  final FormaFoco forma;
}

enum FormaFoco { circulo, redondeado }

/// Lanza la guía interactiva: un recorrido de spotlights sobre widgets reales,
/// con el resto de la pantalla difuminado.
///
/// A diferencia de la hoja estática (`guia_rapida_sheet.dart`, que sigue
/// existiendo para consulta rápida offline), esta guía es para la primera vez
/// que alguien abre la app: le señala en vivo dónde está cada cosa.
Future<void> iniciarGuiaInteractiva(
  BuildContext context,
  List<GuiaPaso> pasos,
) async {
  if (pasos.isEmpty) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entrada;
  final completador = _ControladorGuia(pasos: pasos, cerrar: () {
    entrada.remove();
  });
  entrada = OverlayEntry(builder: (_) => _CapaGuia(controlador: completador));
  overlay.insert(entrada);
  await completador.mostrarPaso(0);
}

class _ControladorGuia extends ChangeNotifier {
  _ControladorGuia({required this.pasos, required this.cerrar});

  final List<GuiaPaso> pasos;
  final VoidCallback cerrar;

  int indice = 0;
  Rect? rectObjetivo;
  bool listo = false;

  Future<void> mostrarPaso(int i) async {
    listo = false;
    notifyListeners();
    indice = i;
    final paso = pasos[i];

    if (paso.alEntrar != null) {
      final ctx = paso.objetivo.currentContext;
      if (ctx != null) await paso.alEntrar!(ctx);
      // Espera a que la navegacion/transicion termine antes de medir.
      await Future<void>.delayed(const Duration(milliseconds: 340));
    }
    // Deja que el frame se asiente antes de buscar el RenderBox.
    await Future<void>.delayed(const Duration(milliseconds: 16));

    final renderObject = paso.objetivo.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.attached) {
      final posicion = renderObject.localToGlobal(Offset.zero);
      rectObjetivo = posicion & renderObject.size;
    } else {
      // El objetivo no existe en este frame (p.ej. tab bar fuera de vista).
      // Se muestra un recuadro centrado en vez de fallar la guia completa.
      rectObjetivo = null;
    }
    listo = true;
    notifyListeners();
  }

  Future<void> siguiente() async {
    if (indice + 1 >= pasos.length) {
      cerrar();
      return;
    }
    await mostrarPaso(indice + 1);
  }

  Future<void> anterior() async {
    if (indice == 0) return;
    await mostrarPaso(indice - 1);
  }
}

class _CapaGuia extends StatelessWidget {
  const _CapaGuia({required this.controlador});

  final _ControladorGuia controlador;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controlador,
      builder: (context, _) {
        final paso = controlador.pasos[controlador.indice];
        final size = MediaQuery.sizeOf(context);
        final rect = controlador.rectObjetivo ??
            Rect.fromCenter(
                center: Offset(size.width / 2, size.height / 2),
                width: 1,
                height: 1);

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Difumina todo salvo un hueco alrededor del objetivo.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: controlador.listo ? 1 : 0,
                    child: CustomPaint(
                      painter: _RecortePainter(
                          rect: rect.inflate(8), forma: paso.forma),
                    ),
                  ),
                ),
              ),
              // Cerrar tocando fuera de la tarjeta.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: controlador.cerrar,
                ),
              ),
              if (controlador.listo)
                _Tarjeta(
                  rect: rect,
                  paso: paso,
                  indice: controlador.indice,
                  total: controlador.pasos.length,
                  onSiguiente: controlador.siguiente,
                  onAnterior:
                      controlador.indice > 0 ? controlador.anterior : null,
                  onSaltar: controlador.cerrar,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RecortePainter extends CustomPainter {
  _RecortePainter({required this.rect, required this.forma});

  final Rect rect;
  final FormaFoco forma;

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Path()..addRect(Offset.zero & size);
    final hueco = forma == FormaFoco.circulo
        ? (Path()
          ..addOval(Rect.fromCircle(
              center: rect.center, radius: rect.longestSide / 2)))
        : (Path()
          ..addRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(20))));

    final recorte = Path.combine(PathOperation.difference, fondo, hueco);
    canvas.drawPath(recorte, Paint()..color = Colors.black.withValues(alpha: 0.72));

    // Anillo de foco alrededor del hueco.
    canvas.drawPath(
      hueco,
      Paint()
        ..color = AppColors.brand500
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _RecortePainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.forma != forma;
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.rect,
    required this.paso,
    required this.indice,
    required this.total,
    required this.onSiguiente,
    required this.onAnterior,
    required this.onSaltar,
  });

  final Rect rect;
  final GuiaPaso paso;
  final int indice;
  final int total;
  final VoidCallback onSiguiente;
  final VoidCallback? onAnterior;
  final VoidCallback onSaltar;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Si hay mas espacio arriba del objetivo que abajo, la tarjeta se apoya
    // arriba; si no, abajo. Asi nunca tapa lo que se esta senalando.
    final espacioAbajo = size.height - rect.bottom;
    final apoyaArriba = espacioAbajo < 220 && rect.top > 220;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: MTMotion.easeIOS,
      left: 20,
      right: 20,
      top: apoyaArriba ? null : (rect.bottom + 20).clamp(20, size.height - 260),
      bottom: apoyaArriba
          ? (size.height - rect.top + 20).clamp(20, size.height - 260)
          : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: MTElevation.sheet,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brand50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${indice + 1} / $total',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brand700),
                  ),
                ),
                const Spacer(),
                Press(
                  onTap: onSaltar,
                  child: const Text('Saltar',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(paso.titulo,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text(paso.texto,
                style: const TextStyle(height: 1.4, color: AppColors.fgBase)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (onAnterior != null)
                  TextButton(
                      onPressed: onAnterior, child: const Text('Atrás')),
                const Spacer(),
                FilledButton(
                  onPressed: onSiguiente,
                  child: Text(
                      indice + 1 == total ? 'Entendido' : 'Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
