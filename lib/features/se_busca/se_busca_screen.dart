import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/freshness.dart';
import '../../models/persona.dart';
import '../../repositories/personas_repository.dart';

/// Filtros activos de la pantalla.
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

final personasProvider = FutureProvider<Fresh<List<Persona>>>((ref) async {
  final pais = ref.watch(paisProvider);
  final f = ref.watch(filtroPersonasProvider);
  return ref.watch(personasRepositoryProvider).listar(
        paisCodigo: pais.codigo,
        estado: f.estado,
        soloMenores: f.soloMenores,
        busqueda: f.busqueda,
      );
});

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
  @override
  void initState() {
    super.initState();
    // El filtro llega por la URL (chip del Inicio o enlace compartido desde la
    // web). Se aplica despues del primer frame para no escribir en un provider
    // durante el build.
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
  Widget build(BuildContext context) {
    final personas = ref.watch(personasProvider);
    final filtro = ref.watch(filtroPersonasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Se busca')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar nombre, documento o ubicacion',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => ref
                  .read(filtroPersonasProvider.notifier)
                  .update((f) => f.copyWith(busqueda: v)),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: filtro.estado == null && !filtro.soloMenores,
                  onSelected: (_) => ref
                      .read(filtroPersonasProvider.notifier)
                      .state = const FiltroPersonas(),
                ),
                const SizedBox(width: 8),
                for (final e in EstadoPersona.values) ...[
                  FilterChip(
                    label: Text(e.etiqueta),
                    selected: filtro.estado == e,
                    onSelected: (sel) => ref
                        .read(filtroPersonasProvider.notifier)
                        .state = FiltroPersonas(estado: sel ? e : null),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: personas.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Error(onReintentar: () {
                ref.invalidate(personasProvider);
              }),
              data: (fresh) {
                if (fresh.data.isEmpty) {
                  return const Center(
                    child: Text('No hay personas con este filtro.'),
                  );
                }
                return Column(
                  children: [
                    StaleDataBanner(
                      fetchedAt: fresh.fetchedAt,
                      onRefresh: () => ref.invalidate(personasProvider),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: fresh.data.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _PersonaCard(persona: fresh.data[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({required this.persona});

  final Persona persona;

  Color get _color => switch (persona.estado) {
        EstadoPersona.porLocalizar => AppColors.danger500,
        EstadoPersona.hospitalizado => AppColors.info500,
        EstadoPersona.localizado => AppColors.success500,
        EstadoPersona.fallecido => AppColors.navy700,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push('${Rutas.persona}/${persona.id}'),
        leading: CircleAvatar(
          backgroundColor: _color.withValues(alpha: 0.15),
          foregroundColor: _color,
          backgroundImage: persona.fotoUrl == null
              ? null
              : NetworkImage(persona.fotoUrl!),
          child: persona.fotoUrl == null
              ? const Icon(Icons.person_outline)
              : null,
        ),
        title: Text(persona.nombre),
        subtitle: Text(
          [
            persona.estado.etiqueta,
            if (persona.ubicacion != null) persona.ubicacion!,
          ].join(' · '),
        ),
        trailing: persona.esMenor
            ? const Chip(
                label: Text('Menor'),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No pudimos cargar la lista.'),
          const SizedBox(height: 8),
          FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
