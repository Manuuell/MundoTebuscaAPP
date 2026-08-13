import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/env.dart';
import '../../core/config/sismo.dart';
import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/freshness.dart';
import '../../models/punto_ayuda.dart';
import '../../repositories/ayuda_repository.dart';

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

class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pais = ref.watch(paisProvider);
    final puntos = ref.watch(puntosProvider);
    final capas = ref.watch(capasProvider);
    final sismo = sismosPorPais[pais.codigo];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Capas',
            onPressed: () => _elegirCapas(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          puntos.maybeWhen(
            data: (fresh) => StaleDataBanner(
              fetchedAt: fresh.fetchedAt,
              onRefresh: () => ref.invalidate(puntosProvider),
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
                    for (final p in puntos.valueOrNull?.data ?? const <PuntoAyuda>[])
                      // `lat`/`lng` son nullable: muchos puntos solo tienen
                      // `direccion` en texto libre, sin coordenadas todavia.
                      if (capas.contains(p.tipo) && p.lat != null && p.lng != null)
                        Marker(
                          point: LatLng(p.lat!, p.lng!),
                          width: 40,
                          height: 40,
                          child: _Pin(punto: p),
                        ),
                    if (sismo != null && capas.contains(TipoPunto.zona))
                      Marker(
                        point: sismo.centro,
                        width: 44,
                        height: 44,
                        child: _PinEpicentro(sismo: sismo),
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

  Future<void> _elegirCapas(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (_, sheetRef, _) {
          final capas = sheetRef.watch(capasProvider);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in TipoPunto.values)
                  SwitchListTile(
                    title: Text(t.etiqueta),
                    value: capas.contains(t),
                    onChanged: (on) {
                      final next = {...capas};
                      on ? next.add(t) : next.remove(t);
                      sheetRef.read(capasProvider.notifier).state = next;
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
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

class _Pin extends StatelessWidget {
  const _Pin({required this.punto});

  final PuntoAyuda punto;

  Color get _color => switch (punto.tipo) {
        TipoPunto.hospital => AppColors.info500,
        TipoPunto.refugio => AppColors.success500,
        TipoPunto.rescate => AppColors.warning500,
        TipoPunto.zona => AppColors.danger500,
        TipoPunto.ayuda => AppColors.brand500,
      };

  IconData get _icono => switch (punto.tipo) {
        TipoPunto.hospital => Icons.local_hospital_rounded,
        TipoPunto.refugio => Icons.home_rounded,
        TipoPunto.rescate => Icons.support_rounded,
        TipoPunto.zona => Icons.warning_rounded,
        TipoPunto.ayuda => Icons.volunteer_activism_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: punto.nombre,
      child: Container(
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(_icono, color: Colors.white, size: 20),
      ),
    );
  }
}
