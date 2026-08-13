import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/freshness.dart';
import '../../models/persona.dart';
import '../../repositories/personas_repository.dart';
import '../../widgets/boton_publicar.dart';
import '../../widgets/publicar_sheet.dart';
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

/// Lo cargado hasta ahora en la lista.
class PaginaPersonas {
  const PaginaPersonas({
    required this.personas,
    required this.traidoEn,
    this.cargandoMas = false,
    this.hayMas = true,
  });

  final List<Persona> personas;
  final DateTime traidoEn;
  final bool cargandoMas;
  final bool hayMas;

  PaginaPersonas copyWith({
    List<Persona>? personas,
    bool? cargandoMas,
    bool? hayMas,
  }) =>
      PaginaPersonas(
        personas: personas ?? this.personas,
        traidoEn: traidoEn,
        cargandoMas: cargandoMas ?? this.cargandoMas,
        hayMas: hayMas ?? this.hayMas,
      );
}

/// Lista con carga por scroll.
///
/// Sustituye al paginado por tamano fijo. Con 5.291 fichas en Colombia, elegir
/// "10 / 20 / 50" obliga a decidir algo que a nadie le importa; buscar a un
/// familiar es desplazarse hasta encontrarlo. Se piden tandas de 30 y se
/// acumulan.
class PersonasNotifier extends Notifier<AsyncValue<PaginaPersonas>> {
  static const _tanda = 30;

  @override
  AsyncValue<PaginaPersonas> build() {
    // Cambiar de pais o de filtro reinicia la lista: mezclar resultados de dos
    // busquedas distintas seria peor que recargar.
    ref.watch(paisProvider);
    ref.watch(filtroPersonasProvider);
    Future.microtask(recargar);
    return const AsyncValue.loading();
  }

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    try {
      final lote = await _traer(desde: 0);
      state = AsyncValue.data(PaginaPersonas(
        personas: lote,
        traidoEn: DateTime.now(),
        hayMas: lote.length == _tanda,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cargarMas() async {
    final actual = state.valueOrNull;
    if (actual == null || actual.cargandoMas || !actual.hayMas) return;

    state = AsyncValue.data(actual.copyWith(cargandoMas: true));
    try {
      final lote = await _traer(desde: actual.personas.length);
      state = AsyncValue.data(actual.copyWith(
        personas: [...actual.personas, ...lote],
        cargandoMas: false,
        hayMas: lote.length == _tanda,
      ));
    } catch (_) {
      // Un lote que falla no borra lo ya cargado: se corta la carga y quien
      // mira conserva lo que tenia.
      state = AsyncValue.data(actual.copyWith(cargandoMas: false));
    }
  }

  Future<List<Persona>> _traer({required int desde}) {
    final pais = ref.read(paisProvider);
    final f = ref.read(filtroPersonasProvider);
    return ref
        .read(personasRepositoryProvider)
        .listar(
          paisCodigo: pais.codigo,
          estado: f.estado,
          soloMenores: f.soloMenores,
          busqueda: f.busqueda,
          limite: _tanda,
          desde: desde,
          // La lista muestra a quien se busca; las fichas sin identificar
          // tienen su propia vista.
          soloNoIdentificadas: false,
        )
        .then((fresh) => fresh.data);
  }
}

final personasProvider =
    NotifierProvider<PersonasNotifier, AsyncValue<PaginaPersonas>>(
        PersonasNotifier.new);

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
    final publicada = await mostrarPublicarPersona(context);
    if (!publicada || !context.mounted) return;

    // La lista se recarga sola: si alguien publica y no ve su ficha aparecer,
    // asume que no se guardo y vuelve a publicarla.
    ref.read(personasProvider.notifier).recargar();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('Ficha publicada. Ya aparece en la lista.'),
        behavior: SnackBarBehavior.floating,
      ));
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
      // Solo en la lista: en la baraja el pulgar esta justo encima de los
      // botones de decidir, y ahi un boton mas es un toque equivocado.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // Solo en la lista: en la baraja el pulgar esta justo encima de los
      // botones de decidir, y ahi un boton mas es un toque equivocado.
      floatingActionButton: _baraja
          ? null
          : BotonPublicar(
              icono: Icons.person_add_alt_rounded,
              etiqueta: 'Publicar',
              alTocar: () => _publicarPersona(context),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Consumer(
              builder: (context, ref, _) {
                final filtro = ref.watch(filtroPersonasProvider);
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
            data: (pagina) {
              if (pagina.personas.isEmpty) {
                return _Mensaje(
                  icono: Icons.search_off_rounded,
                  titulo: 'Sin resultados',
                  detalle: 'No hay personas que coincidan con este filtro.',
                  alReintentar: () =>
                      ref.read(personasProvider.notifier).recargar(),
                );
              }

              final notifier = ref.read(personasProvider.notifier);

              return Column(
                children: [
                  StaleDataBanner(
                    fetchedAt: pagina.traidoEn,
                    onRefresh: notifier.recargar,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: notifier.recargar,
                      // Se pide la siguiente tanda antes de llegar al final,
                      // para que el scroll no se pare a esperar.
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >=
                              n.metrics.maxScrollExtent - 600) {
                            notifier.cargarMas();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            10,
                            16,
                            MediaQuery.paddingOf(context).bottom + 16,
                          ),
                          itemCount: pagina.personas.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i == pagina.personas.length) {
                              return _PieLista(pagina: pagina);
                            }
                            return MTEntrada(
                              // La cascada solo en la primera tanda: al cargar
                              // mas, animar de nuevo lo ya visto marea.
                              indice: i < 8 ? i : 8,
                              child: PersonaTile(
                                persona: pagina.personas[i],
                                onTap: () => context.push(
                                    '${Rutas.persona}/${pagina.personas[i].id}'),
                              ),
                            );
                          },
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

/// Pie de la lista: hilandera mientras carga la siguiente tanda, o el aviso de
/// que ya no hay mas. Sin esto, llegar al final se siente como si la app se
/// hubiera quedado colgada.
class _PieLista extends StatelessWidget {
  const _PieLista({required this.pagina});

  final PaginaPersonas pagina;

  @override
  Widget build(BuildContext context) {
    if (pagina.cargandoMas) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (!pagina.hayMas) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '${pagina.personas.length} personas · no hay mas resultados',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
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
