import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/freshness.dart';
import '../../models/publicacion.dart';
import 'comunidad_providers.dart';
import 'widgets/publicacion_card.dart';

/// Comunidad.
///
/// Agrupa el muro, voluntarios, caravanas y denuncias — no son tabs primarios
/// de la app, son subsecciones de aqui (`COMMUNITY_PATHS` en `MobileNav.tsx`).
class ComunidadScreen extends StatelessWidget {
  const ComunidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          title: const Text('Comunidad'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.brand700,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.brand500,
            tabs: [
              Tab(text: 'Muro'),
              Tab(text: 'Voluntarios'),
              Tab(text: 'Caravanas'),
              Tab(text: 'Denuncias'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MuroTab(),
            _VoluntariosTab(),
            _CaravanasTab(),
            _DenunciasTab(),
          ],
        ),
      ),
    );
  }
}

// ── Muro ─────────────────────────────────────────────────────────────────────

class _MuroTab extends ConsumerWidget {
  const _MuroTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muro = ref.watch(muroProvider);
    final filtro = ref.watch(filtroTipoProvider);

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              FilterChip(
                label: const Text('Todo'),
                selected: filtro == null,
                onSelected: (_) =>
                    ref.read(filtroTipoProvider.notifier).state = null,
              ),
              const SizedBox(width: 8),
              for (final t in TipoPublicacion.values) ...[
                FilterChip(
                  avatar: Icon(t.icono, size: 16, color: t.color),
                  label: Text(t.etiqueta),
                  selected: filtro == t,
                  selectedColor: t.color.withValues(alpha: 0.15),
                  onSelected: (sel) => ref
                      .read(filtroTipoProvider.notifier)
                      .state = sel ? t : null,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: _Lista<Publicacion>(
            valor: muro,
            alRecargar: () => ref.invalidate(muroProvider),
            vacio: 'Todavia no hay publicaciones con este filtro.',
            constructor: (p) => PublicacionCard(publicacion: p),
            conPadding: false,
          ),
        ),
      ],
    );
  }
}

// ── Voluntarios ──────────────────────────────────────────────────────────────

class _VoluntariosTab extends ConsumerWidget {
  const _VoluntariosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Lista<Voluntario>(
      valor: ref.watch(voluntariosProvider),
      alRecargar: () => ref.invalidate(voluntariosProvider),
      vacio: 'Nadie se ha inscrito como voluntario para esta emergencia '
          'todavia.',
      constructor: (v) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.brand50,
            child: Icon(Icons.person_outline, color: AppColors.brand700),
          ),
          title: Text(v.nombre),
          subtitle: Text(
            [
              if (v.tipo?.isNotEmpty == true) v.tipo!,
              if (v.habilidades?.isNotEmpty == true) v.habilidades!,
              if (v.disponibilidad?.isNotEmpty == true) v.disponibilidad!,
            ].join(' · '),
          ),
          isThreeLine: v.habilidades?.isNotEmpty == true,
        ),
      ),
    );
  }
}

// ── Caravanas ────────────────────────────────────────────────────────────────

class _CaravanasTab extends ConsumerWidget {
  const _CaravanasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Lista<Caravana>(
      valor: ref.watch(caravanasProvider),
      alRecargar: () => ref.invalidate(caravanasProvider),
      vacio: 'No hay caravanas de ayuda programadas ahora mismo.',
      constructor: (c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.titulo,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (c.origen != null || c.destino != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.route_rounded,
                        size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${c.origen ?? '?'} → ${c.destino ?? '?'}',
                          style: const TextStyle(color: AppColors.muted)),
                    ),
                  ],
                ),
              ],
              if (c.saleEn != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      'Sale ${c.saleEn!.day}/${c.saleEn!.month} '
                      '${c.saleEn!.hour.toString().padLeft(2, '0')}:'
                      '${c.saleEn!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ],
              if (c.whatsappUrl?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse(c.whatsappUrl!),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: Text('Escribir a ${c.organizador ?? 'la caravana'}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Denuncias ────────────────────────────────────────────────────────────────

class _DenunciasTab extends ConsumerWidget {
  const _DenunciasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Lista<Denuncia>(
      valor: ref.watch(denunciasProvider),
      alRecargar: () => ref.invalidate(denunciasProvider),
      vacio: 'No hay denuncias registradas para esta emergencia.',
      constructor: (d) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.report_gmailerrorred_rounded,
                      size: 18, color: AppColors.danger500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(d.categoriaLegible,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger500)),
                  ),
                  Text(tiempoTranscurrido(d.creadaEn),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 10),
              Text(d.cuerpo, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (d.ubicacion?.isNotEmpty == true)
                    Expanded(
                      child: Text(d.ubicacion!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    )
                  else
                    const Spacer(),
                  const Icon(Icons.thumb_up_alt_outlined,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text('${d.apoyos}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Lista genérica con sus estados ───────────────────────────────────────────

/// Carga, error, vacío y datos — con la franja de antigüedad encima.
///
/// Los cuatro tabs comparten estos estados; tenerlos en un solo sitio evita
/// que uno se quede sin banner de antigüedad o sin botón de reintentar según
/// quién lo escribió.
class _Lista<T> extends StatelessWidget {
  const _Lista({
    required this.valor,
    required this.alRecargar,
    required this.vacio,
    required this.constructor,
    this.conPadding = true,
  });

  final AsyncValue<Fresh<List<T>>> valor;
  final VoidCallback alRecargar;
  final String vacio;
  final Widget Function(T) constructor;
  final bool conPadding;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Vacio(
        icono: Icons.cloud_off_rounded,
        titulo: 'No pudimos cargar esto',
        // Sin conexión no se muestra una lista vacía: "no hay denuncias" y "no
        // pudimos consultar" son afirmaciones muy distintas.
        detalle: 'Revisa tu conexion e intentalo de nuevo.',
        accion: alRecargar,
      ),
      data: (fresh) {
        if (fresh.data.isEmpty) {
          return _Vacio(
            icono: Icons.inbox_rounded,
            titulo: 'Nada por aqui',
            detalle: vacio,
            accion: alRecargar,
          );
        }
        return Column(
          children: [
            StaleDataBanner(fetchedAt: fresh.fetchedAt, onRefresh: alRecargar),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => alRecargar(),
                child: ListView.separated(
                  padding: conPadding
                      ? const EdgeInsets.all(16)
                      : const EdgeInsets.only(top: 4),
                  itemCount: fresh.data.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: conPadding ? 10 : 0),
                  itemBuilder: (_, i) => constructor(fresh.data[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.accion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 44, color: AppColors.border),
            const SizedBox(height: 14),
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(detalle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: accion, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
