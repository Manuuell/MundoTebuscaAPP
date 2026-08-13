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
import '../../widgets/pais_switcher.dart';
import '../../widgets/mt_card.dart' show Press;
import '../shell/home_shell.dart';
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
      appBar: MTHeader(
        acciones: [
          Press(
            onTap: () => mostrarHojaMas(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Icon(Icons.more_horiz_rounded,
                  color: AppColors.muted, size: 24),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cifrasPanelProvider);
          ref.invalidate(cifrasSismoProvider);
          ref.invalidate(noticiasProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: PaisSwitcher(),
            ),
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
    final panel = ref.watch(cifrasPanelProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cuando el mundo se detiene,', style: t.headlineLarge),
            Text(
              'la solidaridad nos encuentra.',
              style: t.headlineLarge?.copyWith(color: AppColors.brand500),
            ),
            const SizedBox(height: 12),
            Text(
              'Plataforma ciudadana de ayuda y busqueda ante emergencias. '
              'Activa ahora para ${pais.nombre}.',
              style: t.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: () => context.push(Rutas.ayuda),
                  child: const Text('Como puedo ayudar'),
                ),
                OutlinedButton.icon(
                  // En movil esto NO navega a una pantalla nueva: cambia al
                  // tab Mapa, que ya existe. Apilar una ruta encima de un tab
                  // duplicado deja al usuario con dos mapas en la pila.
                  onPressed: () => StatefulNavigationShell.of(context)
                      .goBranch(3, initialLocation: true),
                  icon: const Icon(Icons.circle, size: 10, color: AppColors.danger500),
                  label: const Text('Ver mapa EN VIVO'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 14),
            Text('JUNTOS SOMOS MAS FUERTES',
                style: t.labelSmall?.copyWith(
                  color: AppColors.muted,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 12),
            panel.when(
              loading: () => const _CargandoCifras(filas: 4),
              error: (e, _) => const _SinDatos(),
              data: (fresh) {
                final c = fresh.data;
                return Column(
                  children: [
                    _FilaHero('Personas buscadas', c.personasBuscadas),
                    _FilaHero('Reportes verificados', c.reportesVerificados),
                    _FilaHero('Voluntarios activos', c.voluntariosActivos),
                    _FilaHero('Puntos de ayuda', c.puntosAyuda),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaHero extends StatelessWidget {
  const _FilaHero(this.etiqueta, this.valor);

  final String etiqueta;
  final int valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            '${valor < 0 ? 0 : valor}',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(etiqueta,
                style: const TextStyle(color: AppColors.muted)),
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
      loading: () => const SizedBox(height: 90, child: _CargandoCifras(filas: 1)),
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
          height: 92,
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
