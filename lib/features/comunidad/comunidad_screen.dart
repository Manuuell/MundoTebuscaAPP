import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/floating_tab_bar.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/freshness.dart';
import '../../models/publicacion.dart';
import '../../widgets/mt_card.dart';
import 'comunidad_providers.dart';
import 'publicacion_detalle_screen.dart';
import 'widgets/novedades_sheet.dart';
import 'widgets/publicacion_card.dart';

/// Comunidad.
///
/// Agrupa el muro, voluntarios, caravanas y denuncias — no son tabs primarios
/// de la app, son subsecciones de aqui (`COMMUNITY_PATHS` en `MobileNav.tsx`).
class ComunidadScreen extends ConsumerWidget {
  const ComunidadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          title: const Text('Comunidad'),
          actions: [
            const _BotonNovedades(),
            // El filtro solo aplica al muro, pero vive en la cabecera para no
            // robarle una franja de alto al feed: con la fila de chips, en un
            // telefono normal apenas entraban dos publicaciones por pantalla.
            const _BotonFiltros(),
            const SizedBox(width: 4),
          ],
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
        floatingActionButton: Padding(
          // Por encima de la tab bar flotante, que si no lo tapa.
          padding:
              EdgeInsets.only(bottom: FloatingTabBar.alturaOcupada - 12),
          child: FloatingActionButton.extended(
            heroTag: 'publicar-comunidad',
            onPressed: () => _publicar(context),
            backgroundColor: AppColors.brand500,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.edit_rounded, size: 20),
            label: const Text('Publicar'),
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

/// Publicar en el muro es una escritura, y la escritura vive en la web. Se
/// abre alli y se dice antes, en vez de ofrecer un editor que no puede enviar.
Future<void> _publicar(BuildContext context) async {
  final seguir = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Publicar en Comunidad'),
      content: const Text(
        'Publicar se hace por ahora en el sitio web, que se abrira fuera de '
        'la app.\n\n'
        'Puedes pedir ayuda, ofrecerla, avisar de un rescate o compartir '
        'informacion util.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir el sitio')),
      ],
    ),
  );

  if (seguir == true) {
    await launchUrl(Uri.parse('https://elmundotebusca.com/comunidad'),
        mode: LaunchMode.externalApplication);
  }
}

/// Campana con contador de novedades sin ver.
class _BotonNovedades extends ConsumerWidget {
  const _BotonNovedades();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sinVer = ref.watch(sinVerProvider).valueOrNull ?? 0;

    return Stack(
      children: [
        IconButton(
          tooltip: 'Novedades',
          onPressed: () => mostrarNovedades(context, ref),
          icon: Icon(
            sinVer > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            color: sinVer > 0 ? AppColors.brand700 : AppColors.muted,
          ),
        ),
        if (sinVer > 0)
          // IgnorePointer: el `Text` del badge contesta que si al hit test
          // (RenderParagraph siempre lo hace, para poder seleccionar texto),
          // asi que sin esto tocar justo el numero no abre nada y tocar el
          // borde si — parece que el boton falla de forma intermitente.
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(
                    color: AppColors.danger500, shape: BoxShape.circle),
                child: Text(
                  sinVer > 9 ? '9+' : '$sinVer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Filtros del muro, en una hoja en vez de una fila de chips.
class _BotonFiltros extends ConsumerWidget {
  const _BotonFiltros();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroTipoProvider);
    final activo = filtro != null;

    return Stack(
      children: [
        IconButton(
          tooltip: 'Filtros',
          onPressed: () => _abrir(context, ref),
          icon: Icon(
            activo ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
            color: activo ? AppColors.brand700 : AppColors.muted,
          ),
        ),
        if (activo)
          Positioned(
            right: 10,
            top: 10,
            child: IgnorePointer(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: filtro.color, shape: BoxShape.circle),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _abrir(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (_, sheetRef, _) {
          final actual = sheetRef.watch(filtroTipoProvider);

          void elegir(TipoPublicacion? t) {
            sheetRef.read(filtroTipoProvider.notifier).state = t;
            Navigator.pop(sheetContext);
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Text('Filtrar publicaciones',
                        style:
                            Theme.of(sheetContext).textTheme.titleLarge),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Elige que tipo quieres ver en el muro.',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                  RadioGroup<TipoPublicacion?>(
                    groupValue: actual,
                    onChanged: elegir,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ListTile(
                          leading: Icon(Icons.all_inclusive_rounded,
                              color: AppColors.navy700),
                          title: Text('Todo'),
                          trailing: Radio<TipoPublicacion?>(value: null),
                        ),
                        for (final t in TipoPublicacion.values)
                          ListTile(
                            leading: Icon(t.icono, color: t.color),
                            title: Text(t.etiqueta),
                            trailing: Radio<TipoPublicacion?>(value: t),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
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
        // Con un filtro puesto, el feed solo muestra un tipo. Sin este aviso
        // "no hay publicaciones" se lee como que la emergencia esta vacia, no
        // como que hay un filtro activo.
        if (filtro != null)
          Container(
            width: double.infinity,
            color: filtro.color.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(filtro.icono, size: 16, color: filtro.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Viendo solo: ${filtro.etiqueta}',
                      style: TextStyle(
                          fontSize: 13,
                          color: filtro.color,
                          fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(filtroTipoProvider.notifier).state = null,
                  child: const Text('Quitar'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _Lista<Publicacion>(
            valor: muro,
            alRecargar: () => ref.invalidate(muroProvider),
            vacio: filtro == null
                ? 'Todavia no hay publicaciones en esta emergencia.'
                : 'No hay publicaciones de tipo "${filtro.etiqueta}".',
            constructor: (p) => PublicacionCard(
              publicacion: p,
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => PublicacionDetalleScreen(publicacion: p),
                ),
              ),
            ),
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
                  itemBuilder: (_, i) =>
                      MTEntrada(indice: i, child: constructor(fresh.data[i])),
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
