import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/config/sismo.dart';
import '../../core/router/app_router.dart';
import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/elevation.dart';
import '../../core/util/freshness.dart';
import '../../models/persona.dart';
import '../../models/publicacion.dart' show Comentario;
import '../../models/punto_ayuda.dart';
import '../../repositories/ayuda_repository.dart';
import '../../repositories/comunidad_repository.dart';
import '../../repositories/personas_repository.dart';
import '../../widgets/mt_search_bar.dart' show mostrarFlotante;
import '../comunidad/widgets/publicacion_card.dart' show tiempoTranscurrido;

/// Capas visibles del mapa. Arrancan todas encendidas, como en la web.
final capasProvider = StateProvider<Set<TipoPunto>>(
  (ref) => TipoPunto.values.toSet(),
);

final puntosProvider = FutureProvider<Fresh<List<PuntoAyuda>>>((ref) async {
  final pais = ref.watch(paisProvider);
  final capas = ref.watch(capasProvider);
  return ref
      .watch(ayudaRepositoryProvider)
      .listar(paisCodigo: pais.codigo, tipos: capas);
});

/// Personas con coordenada exacta: solo `por_localizar`, la capa pinta
/// desaparecidos en rojo, no el listado completo.
final personasMapaProvider = FutureProvider<Fresh<List<Persona>>>((ref) async {
  final pais = ref.watch(paisProvider);
  return ref
      .watch(personasRepositoryProvider)
      .conUbicacion(paisCodigo: pais.codigo);
});

/// Centro inicial por pais mientras no hay puntos que encuadrar.
///
/// Colombia no arranca en Bogota: el mapa de una emergencia debe abrir donde
/// esta la emergencia. Si hay epicentro conocido se usa ese, y Bogota queda
/// solo de respaldo para cuando no lo haya.
const _centros = <String, LatLng>{
  'co': LatLng(4.7110, -74.0721),
  've': LatLng(10.4806, -66.9036),
};

LatLng _centroDe(String pais) =>
    sismosPorPais[pais]?.centro ?? _centros[pais] ?? _centros['co']!;

Color _colorHospital(PuntoAyuda h) {
  if (!h.verificado || h.estadoHospital == null) return AppColors.muted;
  return switch (h.estadoHospital) {
    'operativo' => AppColors.success500,
    'saturado' => AppColors.warning500,
    'lleno' => AppColors.danger500,
    'cerrado' => AppColors.muted,
    _ => AppColors.info500,
  };
}

class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pais = ref.watch(paisProvider);
    final puntos = ref.watch(puntosProvider);
    final personas = ref.watch(personasMapaProvider);
    final capas = ref.watch(capasProvider);
    final sismo = sismosPorPais[pais.codigo];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: [
          Builder(
            builder: (btnContext) => IconButton(
              icon: const Icon(Icons.layers_outlined),
              tooltip: 'Capas',
              onPressed: () => _abrirCapas(btnContext, ref),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          puntos.maybeWhen(
            data: (fresh) => StaleDataBanner(
              fetchedAt: fresh.fetchedAt,
              onRefresh: () {
                ref.invalidate(puntosProvider);
                ref.invalidate(personasMapaProvider);
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _centroDe(pais.codigo),
                initialZoom: 7,
              ),
              children: [
                TileLayer(
                  urlTemplate: Env.mapTileUrl,
                  userAgentPackageName: 'com.mundotebusca.mundo_te_busca',
                ),
                // Debajo de las chinchetas a proposito: la mancha situa la
                // zona, los puntos son lo que se toca.
                if (sismo != null && capas.contains(TipoPunto.zona))
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: sismo.centro,
                        radius: sismo.radioAfectadoKm * 1000,
                        useRadiusInMeter: true,
                        color: AppColors.danger500.withValues(alpha: 0.10),
                        borderColor: AppColors.danger500.withValues(alpha: 0.45),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (sismo != null && capas.contains(TipoPunto.zona))
                      Marker(
                        point: sismo.centro,
                        width: 44,
                        height: 44,
                        child: _PinEpicentro(sismo: sismo),
                      ),
                    for (final p
                        in personas.valueOrNull?.data ?? const <Persona>[])
                      if (capas.contains(TipoPunto.desaparecidos) &&
                          p.lat != null &&
                          p.lng != null)
                        Marker(
                          point: LatLng(p.lat!, p.lng!),
                          width: 22,
                          height: 22,
                          child: _PinPersona(
                            persona: p,
                            onTap: () =>
                                context.push('${Rutas.persona}/${p.id}'),
                          ),
                        ),
                    for (final p in puntos.valueOrNull?.data ?? const <PuntoAyuda>[])
                      // `lat`/`lng` son nullable: muchos puntos solo tienen
                      // `direccion` en texto libre, sin coordenadas todavia.
                      if (capas.contains(p.tipo) && p.lat != null && p.lng != null)
                        Marker(
                          point: LatLng(p.lat!, p.lng!),
                          width: 40,
                          height: 40,
                          child: _Pin(
                            punto: p,
                            onTap: () => _abrirDetallePunto(context, p),
                          ),
                        ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [TextSourceAttribution(Env.mapAttribution)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _abrirCapas(BuildContext anchorContext, WidgetRef ref) {
    mostrarFlotante(
      anchorContext,
      ancho: 250,
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) {
          final capas = sheetRef.watch(capasProvider);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in TipoPunto.values)
                  InkWell(
                    onTap: () {
                      final next = {...capas};
                      capas.contains(t) ? next.remove(t) : next.add(t);
                      sheetRef.read(capasProvider.notifier).state = next;
                    },
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(t.etiqueta,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Switch(
                            value: capas.contains(t),
                            onChanged: (on) {
                              final next = {...capas};
                              on ? next.add(t) : next.remove(t);
                              sheetRef.read(capasProvider.notifier).state = next;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _abrirDetallePunto(BuildContext context, PuntoAyuda punto) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaDetallePunto(punto: punto),
    );
  }
}

/// El epicentro no es un punto de ayuda: no se visita, no tiene telefono y no
/// se agota. Por eso lleva su propia chincheta en vez de reutilizar `_Pin`.
class _PinEpicentro extends StatelessWidget {
  const _PinEpicentro({required this.sismo});

  final Sismo sismo;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${sismo.titulo}\n${sismo.lugar}',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.danger500,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: MTElevation.card,
        ),
        alignment: Alignment.center,
        child: Text(
          sismo.magnitud.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PinPersona extends StatelessWidget {
  const _PinPersona({required this.persona, this.onTap});

  final Persona persona;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: persona.nombre,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.danger500,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: MTElevation.card,
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.punto, this.onTap});

  final PuntoAyuda punto;
  final VoidCallback? onTap;

  Color get _color => switch (punto.tipo) {
        TipoPunto.hospital => _colorHospital(punto),
        TipoPunto.refugio => AppColors.success500,
        TipoPunto.rescate => AppColors.warning500,
        TipoPunto.zona => AppColors.danger500,
        TipoPunto.desaparecidos => AppColors.danger500,
        TipoPunto.ayuda => AppColors.brand500,
      };

  IconData get _icono => switch (punto.tipo) {
        TipoPunto.hospital => Icons.local_hospital_rounded,
        TipoPunto.refugio => Icons.home_rounded,
        TipoPunto.rescate => Icons.support_rounded,
        TipoPunto.zona => Icons.warning_rounded,
        TipoPunto.desaparecidos => Icons.person_pin_circle_rounded,
        TipoPunto.ayuda => Icons.volunteer_activism_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: punto.nombre,
        child: Container(
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: MTElevation.card,
          ),
          child: Icon(_icono, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ── Ficha de un punto (ayuda / hospital) ────────────────────────────────────

const _categoriaEtiqueta = <String, String>{
  'comida': 'Comida',
  'agua': 'Agua',
  'medicina': 'Medicina',
  'refugio': 'Refugio',
  'alojamiento': 'Alojamiento',
  'ropa': 'Ropa',
  'otro': 'Otro',
};

final _comentariosPuntoProvider = FutureProvider.family
    .autoDispose<Fresh<List<Comentario>>, ({String tipo, String id})>((ref, args) {
  return ref
      .watch(comunidadRepositoryProvider)
      .comentariosDe(entityType: args.tipo, entityId: args.id);
});

class _HojaDetallePunto extends ConsumerWidget {
  const _HojaDetallePunto({required this.punto});

  final PuntoAyuda punto;

  bool get _esHospital => punto.tipo == TipoPunto.hospital;
  String get _entityType => _esHospital ? 'hospital' : 'aid_point';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comentarios = ref.watch(
        _comentariosPuntoProvider((tipo: _entityType, id: punto.id)));
    final color = _esHospital ? _colorHospital(punto) : AppColors.brand500;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.34,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _esHospital
                        ? Icons.local_hospital_rounded
                        : Icons.volunteer_activism_rounded,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(punto.nombre,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy700)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!_esHospital)
                            _Pastilla(
                              texto: punto.disponible == null
                                  ? 'Sin reportar'
                                  : punto.disponible!
                                      ? '✅ Sí hay'
                                      : '❌ Se acabó',
                              color: punto.disponible == false
                                  ? AppColors.danger500
                                  : AppColors.success500,
                            ),
                          if (punto.verificado)
                            const _Pastilla(
                                texto: '✔ Verificado', color: AppColors.info500),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (punto.categorias.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _esHospital ? 'ESPECIALIDADES' : 'RECURSOS',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in punto.categorias)
                    _Pastilla(
                      texto: _categoriaEtiqueta[c] ?? c,
                      color: AppColors.navy700,
                      relleno: false,
                    ),
                ],
              ),
            ],
            if (punto.descripcion != null && punto.descripcion!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _esHospital ? 'ESTADO Y NECESIDADES' : 'DESCRIPCIÓN',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Text(punto.descripcion!, style: const TextStyle(height: 1.4)),
            ],
            const SizedBox(height: 16),
            if (punto.direccion != null && punto.direccion!.trim().isNotEmpty)
              _FilaDato(icono: Icons.place_rounded, texto: punto.direccion!),
            if (punto.telefono != null && punto.telefono!.trim().isNotEmpty)
              _FilaDato(
                icono: Icons.call_rounded,
                texto: punto.telefono!,
                onTap: () => launchUrl(Uri.parse('tel:${punto.telefono}')),
              ),
            const Divider(height: 32, color: AppColors.border),
            comentarios.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )),
              error: (_, _) => const Text('No pudimos cargar los comentarios.',
                  style: TextStyle(color: AppColors.muted)),
              data: (fresh) => _ComentariosPunto(comentarios: fresh.data),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 16, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comentar estará disponible cuando se habiliten las cuentas.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.texto, required this.color, this.relleno = true});

  final String texto;
  final Color color;
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: relleno ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: relleno ? null : Border.all(color: AppColors.border),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.icono, required this.texto, this.onTap});

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icono, size: 17, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 13.5,
                  color: onTap != null ? AppColors.info500 : AppColors.fgBase,
                  fontWeight: onTap != null ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComentariosPunto extends StatelessWidget {
  const _ComentariosPunto({required this.comentarios});

  final List<Comentario> comentarios;

  @override
  Widget build(BuildContext context) {
    if (comentarios.isEmpty) {
      return const Text('Todavía no hay comentarios.',
          style: TextStyle(color: AppColors.muted));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          comentarios.length == 1
              ? '1 comentario'
              : '${comentarios.length} comentarios',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 12),
        for (final c in comentarios)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.brand50,
                  child: Text(
                    (c.autor?.trim().isNotEmpty == true ? c.autor! : 'Anonimo')
                        .characters
                        .first
                        .toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.brand700, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.bgBase,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                c.autor?.trim().isNotEmpty == true
                                    ? c.autor!
                                    : 'Anonimo',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 3),
                            Text(c.cuerpo,
                                style:
                                    const TextStyle(fontSize: 14, height: 1.35)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6, top: 4),
                        child: Text(tiempoTranscurrido(c.creadoEn),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
