import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/app_router.dart';
import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/freshness.dart';
import '../../models/persona.dart';
import '../../repositories/personas_repository.dart';
import '../../widgets/mt_card.dart';
import '../../widgets/mt_search_bar.dart';
import 'widgets/baraja_reconoces.dart';
import 'widgets/persona_tile.dart';

// ── Estado ───────────────────────────────────────────────────────────────────

class FiltroPersonas {
  const FiltroPersonas({this.estado, this.soloMenores = false, this.busqueda});

  final EstadoPersona? estado;
  final bool soloMenores;
  final String? busqueda;

  FiltroPersonas copyWith({
    EstadoPersona? estado,
    bool? soloMenores,
    String? busqueda,
    bool limpiarEstado = false,
  }) =>
      FiltroPersonas(
        estado: limpiarEstado ? null : (estado ?? this.estado),
        soloMenores: soloMenores ?? this.soloMenores,
        busqueda: busqueda ?? this.busqueda,
      );
}

final filtroPersonasProvider =
    StateProvider<FiltroPersonas>((ref) => const FiltroPersonas());

/// Cuántas fichas por página. 10 por defecto, igual que `PAGE_SIZE` en la web.
final porPaginaProvider = StateProvider<int>((ref) => 10);

final personasProvider = FutureProvider<Fresh<List<Persona>>>((ref) async {
  final pais = ref.watch(paisProvider);
  final f = ref.watch(filtroPersonasProvider);
  final porPagina = ref.watch(porPaginaProvider);
  return ref.watch(personasRepositoryProvider).listar(
        paisCodigo: pais.codigo,
        estado: f.estado,
        soloMenores: f.soloMenores,
        busqueda: f.busqueda,
        limite: porPagina,
        // La lista muestra a quien se busca; las fichas sin identificar tienen
        // su propia vista.
        soloNoIdentificadas: false,
      );
});

/// Fichas de la baraja.
///
/// Se sirven de las MISMAS personas que la lista. La idea original era
/// filtrar por `is_unidentified = true`, pero en la base las 48.073 filas de
/// `persons` lo tienen en false: filtrando, la baraja no ensenaria ni una
/// ficha. Repasar a quien se busca tambien sirve para reconocer a alguien, asi
/// que la pantalla mantiene su proposito.
final noIdentificadasProvider =
    FutureProvider<Fresh<List<Persona>>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref.watch(personasRepositoryProvider).listar(
        paisCodigo: pais.codigo,
        estado: EstadoPersona.porLocalizar,
        limite: 60,
      );
});

// ── Pantalla ─────────────────────────────────────────────────────────────────

class SeBuscaScreen extends ConsumerStatefulWidget {
  const SeBuscaScreen({
    super.key,
    this.estadoInicial,
    this.soloMenores = false,
  });

  final EstadoPersona? estadoInicial;
  final bool soloMenores;

  @override
  ConsumerState<SeBuscaScreen> createState() => _SeBuscaScreenState();
}

class _SeBuscaScreenState extends ConsumerState<SeBuscaScreen> {
  final _buscador = TextEditingController();
  bool _baraja = false;

  @override
  void initState() {
    super.initState();
    if (widget.estadoInicial != null || widget.soloMenores) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(filtroPersonasProvider.notifier).state = FiltroPersonas(
          estado: widget.estadoInicial,
          soloMenores: widget.soloMenores,
        );
      });
    }
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _publicarPersona(BuildContext context) async {
    final seguir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publicar una persona'),
        content: const Text(
          'Publicar una ficha se hace por ahora en el sitio web, que se '
          'abrira fuera de la app.\n\n'
          'Ten a mano el nombre completo, la ultima ubicacion conocida y una '
          'foto reciente si la tienes.',
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
      await launchUrl(Uri.parse('https://elmundotebusca.com/se-busca'),
          mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Se busca',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      // Publicar una persona es una escritura y la escritura vive en la web.
      // Se abre alli en vez de ofrecer un formulario que no puede enviar: en
      // esta pantalla, creer que publicaste a un familiar y que no se haya
      // guardado es el peor fallo posible.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _publicarPersona(context),
        backgroundColor: AppColors.brand500,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_rounded, size: 20),
        label: const Text('Publicar persona'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Consumer(
              builder: (context, ref, _) {
                final filtro = ref.watch(filtroPersonasProvider);
                final porPagina = ref.watch(porPaginaProvider);
                final activos = (filtro.estado != null ? 1 : 0) +
                    (filtro.soloMenores ? 1 : 0);

                return MTSearchBar(
                  controller: _buscador,
                  hintText: 'Nombre, documento o ubicación',
                  filtrosActivos: activos,
                  alTocarFiltros: () => _abrirFiltros(context, ref),
                  onClear: () {
                    _buscador.clear();
                    ref
                        .read(filtroPersonasProvider.notifier)
                        .update((f) => f.copyWith(busqueda: ''));
                    setState(() {});
                  },
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (v) => ref
                      .read(filtroPersonasProvider.notifier)
                      .update((f) => f.copyWith(busqueda: v)),
                  trailing: _baraja
                      ? null
                      : MTPaginationButton(
                          porPagina: porPagina,
                          onChanged: (n) =>
                              ref.read(porPaginaProvider.notifier).state = n,
                        ),
                );
              },
            ),
          ),
          _Segmentado(
            enBaraja: _baraja,
            alCambiar: (v) => setState(() => _baraja = v),
          ),
          const SizedBox(height: 10),
          Expanded(child: _baraja ? const _VistaBaraja() : const _VistaLista()),
        ],
      ),
    );
  }

  void _abrirFiltros(BuildContext context, WidgetRef ref) {
    final filtro = ref.read(filtroPersonasProvider);
    mostrarHojaFiltros(
      context,
      titulo: 'Filtrar personas',
      alLimpiar: () =>
          ref.read(filtroPersonasProvider.notifier).state = const FiltroPersonas(),
      contenido: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip(
            texto: 'Todos',
            color: AppColors.navy700,
            activo: filtro.estado == null && !filtro.soloMenores,
            alTocar: () => ref.read(filtroPersonasProvider.notifier).state =
                const FiltroPersonas(),
          ),
          for (final e in EstadoPersona.values)
            _Chip(
              texto: e.etiqueta,
              color: colorEstado(e),
              activo: filtro.estado == e,
              alTocar: () => ref.read(filtroPersonasProvider.notifier).state =
                  FiltroPersonas(estado: filtro.estado == e ? null : e),
            ),
          _Chip(
            texto: 'Menores',
            color: AppColors.warning500,
            activo: filtro.soloMenores,
            alTocar: () => ref.read(filtroPersonasProvider.notifier).state =
                FiltroPersonas(soloMenores: !filtro.soloMenores),
          ),
        ],
      ),
    );
  }
}

/// Conmutador Lista / ¿La reconoces?
class _Segmentado extends StatelessWidget {
  const _Segmentado({required this.enBaraja, required this.alCambiar});

  final bool enBaraja;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _Opcion(
              texto: 'Lista',
              activa: !enBaraja,
              alTocar: () => alCambiar(false)),
          _Opcion(
              texto: '¿La reconoces?',
              activa: enBaraja,
              alTocar: () => alCambiar(true)),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion(
      {required this.texto, required this.activa, required this.alTocar});

  final String texto;
  final bool activa;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Press(
        onTap: alTocar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activa ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: activa
                ? [
                    BoxShadow(
                      color: AppColors.navy700.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: activa ? AppColors.brand700 : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Vista lista ──────────────────────────────────────────────────────────────

class _VistaLista extends ConsumerWidget {
  const _VistaLista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personas = ref.watch(personasProvider);

    return Column(
      children: [
        Expanded(
          child: personas.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _Mensaje(
              icono: Icons.cloud_off_rounded,
              titulo: 'No pudimos cargar la lista',
              detalle: 'Revisa tu conexion e intentalo de nuevo.',
              alReintentar: () => ref.invalidate(personasProvider),
            ),
            data: (fresh) {
              if (fresh.data.isEmpty) {
                return _Mensaje(
                  icono: Icons.search_off_rounded,
                  titulo: 'Sin resultados',
                  detalle: 'No hay personas que coincidan con este filtro.',
                  alReintentar: () => ref.invalidate(personasProvider),
                );
              }
              return Column(
                children: [
                  StaleDataBanner(
                    fetchedAt: fresh.fetchedAt,
                    onRefresh: () => ref.invalidate(personasProvider),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => ref.invalidate(personasProvider),
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          MediaQuery.paddingOf(context).bottom + 16,
                        ),
                        itemCount: fresh.data.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => MTEntrada(
                          indice: i,
                          child: PersonaTile(
                            persona: fresh.data[i],
                            // go_router, no Navigator: con pushNamed la ruta
                            // no existe y la ficha no abre.
                            onTap: () => context.push(
                                '${Rutas.persona}/${fresh.data[i].id}'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.color,
    required this.activo,
    required this.alTocar,
  });

  final String texto;
  final Color color;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Press(
        onTap: alTocar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: activo ? color : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: activo ? color : color.withValues(alpha: 0.35)),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: activo ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Vista baraja ─────────────────────────────────────────────────────────────

class _VistaBaraja extends ConsumerWidget {
  const _VistaBaraja();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fichas = ref.watch(noIdentificadasProvider);

    return fichas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Mensaje(
        icono: Icons.cloud_off_rounded,
        titulo: 'No pudimos cargar las fichas',
        detalle: 'Revisa tu conexion e intentalo de nuevo.',
        alReintentar: () => ref.invalidate(noIdentificadasProvider),
      ),
      data: (fresh) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.paddingOf(context).bottom + 8,
        ),
        child: BarajaReconoces(
          personas: fresh.data,
          alReiniciar: () => ref.invalidate(noIdentificadasProvider),
          alReconocer: (p) {
            // Reportar el reconocimiento es una escritura, y la escritura
            // pasa por la Edge Function que todavia no existe. Se avisa en vez
            // de fingir que se guardo: alguien que cree haber reportado a un
            // familiar y no lo hizo es el peor resultado posible aqui.
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(
                content: Text(
                  'Reportar reconocimientos estara disponible cuando se '
                  'habiliten las cuentas.',
                ),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                ),
              ));
          },
        ),
      ),
    );
  }
}

// ── Compartido ───────────────────────────────────────────────────────────────

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.alReintentar,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: AppColors.border),
            const SizedBox(height: 14),
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(detalle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),
            OutlinedButton(
                onPressed: alReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
