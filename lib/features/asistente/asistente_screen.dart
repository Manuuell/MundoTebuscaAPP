import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/asistente_api.dart';
import '../../widgets/mt_card.dart';
import '../inicio/cifras_providers.dart';

/// Asistente de la emergencia.
///
/// Misma estructura que la Comunidad/chatbot de TransCar: bienvenida con
/// sugerencias rapidas mientras no hay conversacion, burbujas, indicador de
/// escritura, y barra de entrada abajo.
class AsistenteScreen extends ConsumerStatefulWidget {
  const AsistenteScreen({super.key});

  @override
  ConsumerState<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _AsistenteScreenState extends ConsumerState<AsistenteScreen> {
  final _mensajes = <MensajeChat>[];
  final _entrada = TextEditingController();
  final _scroll = ScrollController();

  bool _escribiendo = false;
  String _parcial = '';
  String? _error;

  @override
  void dispose() {
    _entrada.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Contexto que se manda con cada consulta.
  ///
  /// Sin esto el modelo respondería con lo que recuerde de su entrenamiento,
  /// que para un terremoto de esta semana es nada. Las cifras salen de la
  /// misma consulta que pinta el Inicio, asi que el asistente y la pantalla
  /// nunca se contradicen.
  String _contexto() {
    final pais = ref.read(paisProvider);
    final panel = ref.read(cifrasPanelProvider).valueOrNull?.data;

    final partes = <String>[
      'Emergencia activa: ${pais.nombre}'
          '${pais.magnitud != null ? ' (sismo ${pais.magnitud})' : ''}.',
      'Linea de emergencia del pais: ${pais.lineaEmergencia ?? 'desconocida'}.',
    ];

    if (panel != null) {
      partes.add(
        'Cifras de la plataforma ahora mismo: '
        '${panel.desaparecidos} por localizar, '
        '${panel.aSalvo} reportadas a salvo, '
        '${panel.enHospitales} en hospitales, '
        '${panel.fallecidos} fallecidas, '
        '${panel.ninos} menores, '
        '${panel.puntosAyuda} puntos de ayuda.',
      );
    }

    return partes.join(' ');
  }

  Future<void> _enviar(String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty || _escribiendo) return;

    setState(() {
      _mensajes.add(MensajeChat(deUsuario: true, texto: limpio));
      _entrada.clear();
      _escribiendo = true;
      _parcial = '';
      _error = null;
    });
    _alFinal();

    try {
      final flujo = ref.read(asistenteApiProvider).responder(
            historial: _mensajes,
            contexto: _contexto(),
          );

      await for (final trozo in flujo) {
        if (!mounted) return;
        setState(() => _parcial += trozo);
        _alFinal();
      }

      if (!mounted) return;
      setState(() {
        if (_parcial.trim().isNotEmpty) {
          _mensajes.add(MensajeChat(deUsuario: false, texto: _parcial.trim()));
        }
        _parcial = '';
        _escribiendo = false;
      });
    } on AsistenteException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _parcial = '';
        _escribiendo = false;
      });
    }
    _alFinal();
  }

  void _alFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vacio = _mensajes.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: AppColors.brand50, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 19, color: AppColors.brand700),
            ),
            const SizedBox(width: 10),
            const Text('Asistente',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          if (!vacio)
            IconButton(
              tooltip: 'Empezar de nuevo',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => setState(() {
                _mensajes.clear();
                _parcial = '';
                _error = null;
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: vacio
                ? _Bienvenida(alElegir: _enviar)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _mensajes.length +
                        (_escribiendo ? 1 : 0) +
                        (_error != null ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i < _mensajes.length) {
                        return _Burbuja(mensaje: _mensajes[i]);
                      }
                      if (_error != null && i == _mensajes.length) {
                        return _BurbujaError(texto: _error!);
                      }
                      return _Escribiendo(parcial: _parcial);
                    },
                  ),
          ),
          _BarraEntrada(
            controlador: _entrada,
            ocupado: _escribiendo,
            alEnviar: _enviar,
          ),
        ],
      ),
    );
  }
}

// ── Bienvenida ───────────────────────────────────────────────────────────────

class _Bienvenida extends StatelessWidget {
  const _Bienvenida({required this.alElegir});

  final ValueChanged<String> alElegir;

  static const _sugerencias = [
    (Icons.search_rounded, '¿Como busco a un familiar desaparecido?'),
    (Icons.volunteer_activism_rounded, '¿Como puedo ayudar desde donde estoy?'),
    (Icons.medical_services_rounded, '¿Que hago en las primeras horas?'),
    (Icons.place_rounded, '¿Donde hay puntos de ayuda cerca?'),
    (Icons.report_rounded, 'Quiero reportar que alguien esta a salvo'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
                color: AppColors.brand50, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_rounded,
                size: 42, color: AppColors.brand700),
          ),
        ),
        const SizedBox(height: 18),
        Text('¿En que te ayudo?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Puedo orientarte sobre la emergencia activa y sobre como usar la '
          'app. No reemplazo a los organismos de socorro.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 26),
        const Text('SUGERENCIAS RAPIDAS',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: AppColors.muted)),
        const SizedBox(height: 12),
        for (var i = 0; i < _sugerencias.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MTEntrada(
              indice: i,
              child: MTCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                onTap: () => alElegir(_sugerencias[i].$2),
                child: Row(
                  children: [
                    Icon(_sugerencias[i].$1,
                        size: 20, color: AppColors.brand500),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(_sugerencias[i].$2,
                            style: const TextStyle(fontSize: 14.5))),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 13, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Burbujas ─────────────────────────────────────────────────────────────────

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje});

  final MensajeChat mensaje;

  @override
  Widget build(BuildContext context) {
    final mio = mensaje.deUsuario;

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: mio ? AppColors.brand500 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mio ? 18 : 5),
            bottomRight: Radius.circular(mio ? 5 : 18),
          ),
          border: mio ? null : Border.all(color: AppColors.border),
        ),
        child: SelectableText(
          mensaje.texto,
          style: TextStyle(
            color: mio ? Colors.white : AppColors.fgBase,
            height: 1.4,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _BurbujaError extends StatelessWidget {
  const _BurbujaError({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.danger500.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 18, color: AppColors.danger500),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(texto,
                      style: const TextStyle(color: AppColors.danger500))),
            ],
          ),
        ),
      );
}

/// Mientras llega la respuesta: si ya hay texto parcial se pinta tal cual, y
/// si no, tres puntos. Ensenar el texto segun llega hace la espera mucho mas
/// corta de lo que se siente.
class _Escribiendo extends StatelessWidget {
  const _Escribiendo({required this.parcial});

  final String parcial;

  @override
  Widget build(BuildContext context) {
    if (parcial.isNotEmpty) {
      return _Burbuja(mensaje: MensajeChat(deUsuario: false, texto: parcial));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const SizedBox(
          width: 34,
          height: 8,
          child: _Puntos(),
        ),
      ),
    );
  }
}

class _Puntos extends StatefulWidget {
  const _Puntos();

  @override
  State<_Puntos> createState() => _PuntosState();
}

class _PuntosState extends State<_Puntos>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) {
            final fase = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
            final salto = (fase < 0.5 ? fase : 1 - fase) * 2;
            return Opacity(
              opacity: 0.35 + salto * 0.65,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.muted, shape: BoxShape.circle),
              ),
            );
          }),
        ),
      );
}

// ── Entrada ──────────────────────────────────────────────────────────────────

class _BarraEntrada extends StatelessWidget {
  const _BarraEntrada({
    required this.controlador,
    required this.ocupado,
    required this.alEnviar,
  });

  final TextEditingController controlador;
  final bool ocupado;
  final ValueChanged<String> alEnviar;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controlador,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: alEnviar,
              decoration: InputDecoration(
                hintText: 'Escribe tu pregunta…',
                filled: true,
                fillColor: AppColors.bgBase,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: ocupado ? AppColors.border : AppColors.brand500,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: ocupado ? null : () => alEnviar(controlador.text),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Icon(Icons.arrow_upward_rounded,
                    color: ocupado ? AppColors.muted : Colors.white, size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
