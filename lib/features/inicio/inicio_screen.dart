import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/pais.dart';
import '../../models/persona.dart';
import '../../widgets/cifra_chip.dart';
import '../../widgets/mt_header.dart';
import '../../core/theme/elevation.dart';
import '../../widgets/donar_sheet.dart';
import '../../widgets/mt_card.dart';
import 'cifras_providers.dart';
import '../../repositories/noticias_repository.dart';
import 'noticias_carrusel.dart';

/// Pantalla Inicio.
///
/// No es un feed de tarjetas: son bloques verticales, en el mismo orden que
/// `src/app/page.tsx:12-35` de la web. Las tarjetas de "cerca de ti" que
/// aparecian en un mockup temprano NO van aqui — ese contenido es de
/// "Se busca" y de "Ayuda".
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pais = ref.watch(paisProvider);
    final panel = ref.watch(cifrasPanelProvider);

    return Scaffold(
      appBar: const MTHeader(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cifrasPanelProvider);
          ref.invalidate(cifrasSismoProvider);
          ref.invalidate(noticiasProvider);
        },
        child: ListView(
          // El hueco de la tab bar flotante viene del MediaQuery que inyecta
          // HomeShell, pero un ListView con `padding` propio IGNORA ese inset
          // (BoxScrollView solo lo aplica cuando no le pasan padding). Sin
          // sumarlo a mano aqui, el carrusel de noticias queda debajo de la
          // barra y no hay forma de subirlo con scroll.
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            _Hero(pais: pais),
            const SizedBox(height: 20),
            const _CifrasSismoBloque(),
            const SizedBox(height: 20),
            _FilaDeCifras(panel: panel),
            const SizedBox(height: 24),
            const NoticiasCarrusel(),
          ],
        ),
      ),
    );
  }
}

// ── 1. Hero ──────────────────────────────────────────────────────────────────

class _Hero extends ConsumerWidget {
  const _Hero({required this.pais});

  final Pais pais;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MTCard.radio),
        // Borde marcado en navy, como el sitio. Es la excepcion a la regla de
        // "borde sutil + sombra": aqui el borde ES el recurso visual, asi que
        // la sombra baja a nivel 0 para no recargar.
        border: Border.all(color: AppColors.navy700, width: 1.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Circulos decorativos que asoman por las esquinas, recortados por
          // el clip de la tarjeta.
          Positioned(
            right: -46,
            top: -54,
            child: _Circulo(
                lado: 168, color: AppColors.brand500.withValues(alpha: 0.22)),
          ),
          Positioned(
            right: -30,
            top: 128,
            child: _Circulo(
                lado: 128, color: AppColors.navy700.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SelectorPais(),
                const SizedBox(height: 18),
                RichText(
                  text: TextSpan(
                    style: t.headlineLarge,
                    children: [
                      const TextSpan(text: 'Cuando el mundo se detiene, '),
                      TextSpan(
                        text: 'la solidaridad nos encuentra.',
                        style: TextStyle(color: AppColors.brand500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Plataforma ciudadana de ayuda y busqueda ante emergencias '
                  'en cualquier parte del mundo. Activa ahora para '
                  '${pais.nombre}.',
                  style: t.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.push(Rutas.ayuda),
                  child: const Text('¿Como puedo ayudar?'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => StatefulNavigationShell.of(context)
                            .goBranch(3, initialLocation: true),
                        style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text('Ver Mapa',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            SizedBox(width: 7),
                            Icon(Icons.circle,
                                size: 9, color: AppColors.danger500),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => mostrarDonar(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: AppColors.brand700,
                          side: const BorderSide(color: AppColors.brand500),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_rounded, size: 16),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text('Donar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _PanelCifras(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo({required this.lado, required this.color});

  final double lado;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Dos pastillas, no un desplegable: con dos emergencias activas se ve de un
/// vistazo cual esta puesta y cual es la otra.
class _SelectorPais extends ConsumerWidget {
  const _SelectorPais();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(paisProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in paisesSemilla)
            Press(
              onTap: () => ref.read(paisProvider.notifier).cambiar(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: MTMotion.easeIOS,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: p.codigo == actual.codigo
                      ? AppColors.navy700
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.bandera, style: const TextStyle(fontSize: 17)),
                    if (p.codigo == actual.codigo) ...[
                      const SizedBox(width: 7),
                      Text(p.nombre,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Juntos somos mas fuertes": cada cifra con su icono en circulo.
class _PanelCifras extends ConsumerWidget {
  const _PanelCifras();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(cifrasPanelProvider);
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JUNTOS SOMOS MAS FUERTES',
              style: t.labelSmall?.copyWith(
                color: AppColors.navy700,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 12),
          panel.when(
            loading: () => const _CargandoCifras(filas: 4),
            error: (e, _) => const _SinDatos(),
            data: (fresh) {
              final c = fresh.data;
              return Column(
                children: [
                  _FilaHero('Personas buscadas', c.personasBuscadas,
                      Icons.people_alt_rounded, AppColors.info500),
                  _FilaHero('Reportes verificados', c.reportesVerificados,
                      Icons.verified_user_rounded, AppColors.success500),
                  _FilaHero('Voluntarios activos', c.voluntariosActivos,
                      Icons.volunteer_activism_rounded, const Color(0xFF8B5CF6)),
                  _FilaHero('Puntos de ayuda', c.puntosAyuda,
                      Icons.place_rounded, AppColors.brand500),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilaHero extends StatelessWidget {
  const _FilaHero(this.etiqueta, this.valor, this.icono, this.color);

  final String etiqueta;
  final int valor;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Miles con punto, como la web: "5.280" se lee de un vistazo y "5280" no.
    final seguro = valor < 0 ? 0 : valor;
    final texto = seguro.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icono, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800, height: 1.05)),
              Text(etiqueta,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 2. Cifras del sismo (prensa) ─────────────────────────────────────────────

class _CifrasSismoBloque extends ConsumerWidget {
  const _CifrasSismoBloque();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sismo = ref.watch(cifrasSismoProvider);

    return sismo.when(
      loading: () => const _CargandoCifras(filas: 2),
      error: (_, _) => const SizedBox.shrink(),
      data: (fresh) {
        final c = fresh.data;
        if (c == null) return const SizedBox.shrink();

        // Regla de honestidad heredada de la web: si la cifra de prensa tiene
        // mas de 30 dias no se pinta como si fuera de hoy.
        if (!c.esReciente) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No hay cifras de prensa recientes para esta emergencia.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    if (c.fallecidos != null)
                      _Dato('Fallecidos', c.fallecidos!),
                    if (c.heridos != null) _Dato('Heridos', c.heridos!),
                    if (c.desaparecidos != null)
                      _Dato('Desaparecidos', c.desaparecidos!),
                  ],
                ),
                const SizedBox(height: 10),
                // La fuente y la fecha van SIEMPRE visibles. Una cifra sin
                // procedencia en un desastre no es informacion, es rumor.
                Text(
                  [
                    if (c.fuente != null) c.fuente!,
                    if (c.fecha != null)
                      '${c.fecha!.day}/${c.fecha!.month}/${c.fecha!.year}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final int valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$valor',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(etiqueta,
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

// ── 3. Fila de 8 cifras ──────────────────────────────────────────────────────

class _FilaDeCifras extends StatelessWidget {
  const _FilaDeCifras({required this.panel});

  final AsyncValue<dynamic> panel;

  @override
  Widget build(BuildContext context) {
    return panel.when(
      loading: () => const SizedBox(height: 78, child: _CargandoCifras(filas: 1)),
      error: (_, _) => const _SinDatos(),
      data: (fresh) {
        final CifrasPanel c = fresh.data as CifrasPanel;

        // Cada chip lleva al mismo filtro que el enlace equivalente de la web.
        final items = <(String, int, Color, String?)>[
          ('Desaparecidos', c.desaparecidos, AppColors.danger500,
              '?status=${EstadoPersona.porLocalizar.wire}'),
          ('En hospitales', c.enHospitales, AppColors.info500,
              '?status=${EstadoPersona.hospitalizado.wire}'),
          ('A salvo', c.aSalvo, AppColors.success500,
              '?status=${EstadoPersona.localizado.wire}'),
          ('Ninos', c.ninos, AppColors.warning500, '?maxAge=11'),
          ('Fallecidos', c.fallecidos, AppColors.navy700,
              '?status=${EstadoPersona.fallecido.wire}'),
          ('Denuncias', c.denuncias, AppColors.brand700, null),
          ('Necesidades', c.necesidades, AppColors.brand500, null),
          ('Ofrecen ayuda', c.ofrecenAyuda, AppColors.success500, null),
        ];

        return SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final (etiqueta, valor, color, query) = items[i];
              return CifraChip(
                valor: valor,
                etiqueta: etiqueta,
                color: color,
                onTap: query == null
                    ? null
                    : () => context.go('${Rutas.seBusca}$query'),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Estados de carga ─────────────────────────────────────────────────────────

class _CargandoCifras extends StatelessWidget {
  const _CargandoCifras({required this.filas});

  final int filas;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        filas,
        (_) => Container(
          height: 22,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _SinDatos extends StatelessWidget {
  const _SinDatos();

  @override
  Widget build(BuildContext context) {
    // Sin conexion no se inventan ceros: un 0 se lee como "no hay
    // desaparecidos", que es una afirmacion muy distinta a "no pudimos
    // consultar".
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'No pudimos cargar las cifras. Desliza para reintentar.',
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}
