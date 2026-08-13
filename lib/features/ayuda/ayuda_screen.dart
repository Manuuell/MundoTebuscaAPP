import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/mt_card.dart';

/// "¿Como puedo ayudar?"
///
/// Mismo contenido que `/voluntarios/guia` en la web. Las tres preguntas y los
/// dos botones no se resumen ni se reescriben: responden dudas concretas que
/// frenan a quien duda si puede aportar algo.
class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  static const _preguntas = <(IconData, String, String)>[
    (
      Icons.forum_outlined,
      '¿Que es un voluntario digital?',
      'Alguien que ayuda a distancia, sin estar en la zona del desastre: '
          'comparte y verifica informacion, responde a quien pregunta por un '
          'punto de ayuda, avisa si algo cambio, o difunde publicaciones de '
          'personas desaparecidas para que lleguen a mas gente. No necesitas '
          'experiencia previa ni estar fisicamente en Venezuela o Colombia.',
    ),
    (
      Icons.medical_services_outlined,
      '¿Y si estoy en un hospital o punto de ayuda?',
      'Si trabajas o colaboras en un hospital o un punto de ayuda concreto, '
          'puedes pedir permiso para mantener su informacion actualizada tu '
          'mismo (insumos, disponibilidad, estado). Un moderador revisa esa '
          'solicitud antes de darte el acceso — no es automatico, para que '
          'nadie pueda hacerse pasar por un lugar que no es suyo.',
    ),
    (
      Icons.verified_user_outlined,
      '¿Que gano yo con esto?',
      'Nada mas que ayudar a que la informacion sea real y este actualizada. '
          'Es una plataforma ciudadana sin fines de lucro — nadie cobra por '
          'participar.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(title: const Text('¿Como puedo ayudar?')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.success500,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'No hace falta ser rescatista para salvar vidas aqui. Un '
                  'voluntario digital ayuda desde donde este.',
                  style: TextStyle(height: 1.4, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _preguntas.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MTEntrada(
                indice: i,
                child: MTCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_preguntas[i].$1,
                              size: 19, color: AppColors.brand700),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(_preguntas[i].$2,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                    color: AppColors.navy700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(_preguntas[i].$3,
                          style: const TextStyle(height: 1.45, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),

          // Inscribirse es una escritura, y la escritura vive en la web. Se
          // abre alli en vez de ofrecer un formulario que no puede enviar.
          _Boton(
            texto: 'Quiero ser voluntario digital',
            relleno: AppColors.brand500,
            colorTexto: Colors.white,
            ruta: 'https://elmundotebusca.com/voluntarios',
          ),
          const SizedBox(height: 10),
          _Boton(
            texto: 'Quiero gestionar un hospital o punto de ayuda',
            relleno: Colors.white,
            colorTexto: AppColors.navy700,
            ruta: 'https://elmundotebusca.com/voluntarios',
          ),
          const SizedBox(height: 14),
          const Text(
            'Inscribirse se hace por ahora en el sitio web; se abrira fuera de '
            'la app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({
    required this.texto,
    required this.relleno,
    required this.colorTexto,
    required this.ruta,
  });

  final String texto;
  final Color relleno;
  final Color colorTexto;
  final String ruta;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: relleno,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () =>
            launchUrl(Uri.parse(ruta), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: relleno == Colors.white
                ? Border.all(color: AppColors.border)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(texto,
                    style: TextStyle(
                        color: colorTexto,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              Icon(Icons.arrow_forward_rounded, size: 18, color: colorTexto),
            ],
          ),
        ),
      ),
    );
  }
}
