import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/safety_repository.dart';

/// Pantalla completa "¿Estás bien?" tras un sismo cercano.
///
/// Se abre sobre lo que sea que la persona esté haciendo — por eso es una
/// pantalla, no una hoja: tiene que ganarle la atención a cualquier otra cosa
/// en pantalla, igual que una llamada entrante. Vibra y suena mientras nadie
/// responde, como pidió la demo en vivo ("que le aparezca esa señal... su
/// teléfono empieza a hacer el sonido").
class CheckinAlertaScreen extends ConsumerStatefulWidget {
  const CheckinAlertaScreen({super.key, required this.quakeId});

  final String quakeId;

  @override
  ConsumerState<CheckinAlertaScreen> createState() =>
      _CheckinAlertaScreenState();
}

class _CheckinAlertaScreenState extends ConsumerState<CheckinAlertaScreen> {
  Timer? _pulso;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _pulso = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
    // Primer pulso inmediato, sin esperar el primer tick del timer.
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  @override
  void dispose() {
    _pulso?.cancel();
    super.dispose();
  }

  Future<void> _responder({required bool estoyBien}) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    _pulso?.cancel();
    try {
      await ref
          .read(safetyRepositoryProvider)
          .responder(widget.quakeId, estoyBien: estoyBien);
    } catch (_) {
      // Si falla la red, igual se cierra: no tiene sentido atrapar a alguien
      // en esta pantalla en medio de una emergencia por un error de envío.
      // El siguiente sondeo (`poll`) la va a volver a mostrar si de verdad
      // sigue pendiente.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // No se cierra con el botón atrás: hay que responder algo, igual que
      // una llamada de emergencia real no se "descarta" sin más.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.danger500,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emergency_rounded,
                    color: Colors.white, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Detectamos un sismo cerca de ti',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '¿Estás bien?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Si no respondes, o si dices que no, compartimos tu '
                  'ubicación con voluntarios cercanos para que puedan ir a '
                  'ayudarte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.danger500,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed:
                        _enviando ? null : () => _responder(estoyBien: true),
                    child: const Text('Sí, estoy bien',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed:
                        _enviando ? null : () => _responder(estoyBien: false),
                    child: const Text('Necesito ayuda',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
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
