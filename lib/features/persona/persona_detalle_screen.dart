import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/freshness.dart';
import '../../models/persona.dart';
import '../../repositories/personas_repository.dart';
import '../../widgets/mt_card.dart';
import '../se_busca/widgets/persona_tile.dart' show colorEstado;

final personaProvider =
    FutureProvider.family<Fresh<Persona?>, String>((ref, id) async {
  return ref.watch(personasRepositoryProvider).porId(id);
});

/// Ficha de una persona.
///
/// Destino de `/persona/{id}`, la misma ruta que la web, para que un enlace
/// compartido abra la app si esta instalada.
class PersonaDetalleScreen extends ConsumerWidget {
  const PersonaDetalleScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(personaProvider(id));

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Ficha'),
        actions: [
          persona.valueOrNull?.data == null
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Compartir',
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () => _compartir(persona.value!.data!),
                ),
        ],
      ),
      body: persona.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Mensaje(
          texto: 'No pudimos cargar la ficha.',
          alReintentar: () => ref.invalidate(personaProvider(id)),
        ),
        data: (fresh) {
          final p = fresh.data;
          if (p == null) {
            return const _Mensaje(
                texto: 'Esta persona ya no esta publicada.');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(personaProvider(id)),
            child: ListView(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 24),
              children: [
                StaleDataBanner(
                  fetchedAt: fresh.fetchedAt,
                  onRefresh: () => ref.invalidate(personaProvider(id)),
                ),
                _Cabecera(persona: p),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.posibleDuplicada) ...[
                        const _AvisoDuplicada(),
                        const SizedBox(height: 12),
                      ],
                      _Datos(persona: p),
                      if (p.descripcion?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        MTCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Rotulo('Senas y detalles'),
                              const SizedBox(height: 8),
                              Text(p.descripcion!,
                                  style: const TextStyle(height: 1.45)),
                            ],
                          ),
                        ),
                      ],
                      if (p.contactoNombre != null ||
                          p.contactoTelefono != null ||
                          p.contactoCorreo != null) ...[
                        const SizedBox(height: 12),
                        _Contacto(persona: p),
                      ],
                      const SizedBox(height: 12),
                      _Reacciones(persona: p),
                      const SizedBox(height: 16),
                      _Procedencia(persona: p),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _compartir(Persona p) {
    SharePlus.instance.share(ShareParams(
      text: [
        p.nombre.trim().isEmpty ? 'Persona sin identificar' : p.nombre,
        p.estado.etiqueta,
        if (p.ubicacion != null) p.ubicacion!,
        '',
        'https://elmundotebusca.com/persona/${p.id}',
      ].join('\n'),
    ));
  }
}

// ── Cabecera con foto ────────────────────────────────────────────────────────

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final p = persona;
    final color = colorEstado(p.estado);
    final sinNombre = p.nombre.trim().isEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 104,
              height: 124,
              child: p.fotoUrl?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: p.fotoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: color.withValues(alpha: 0.10)),
                      errorWidget: (_, _, _) => _SinFoto(color: color),
                    )
                  : _SinFoto(color: color),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sinNombre ? 'Sin identificar' : p.nombre,
                  style: const TextStyle(
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pastilla(
                        texto: p.estado.etiqueta,
                        color: color,
                        relleno: color.withValues(alpha: 0.12)),
                    if (p.esMenor)
                      _Pastilla(
                          texto: 'Menor',
                          color: AppColors.warning500,
                          relleno:
                              AppColors.warning500.withValues(alpha: 0.14)),
                    if (p.verificada)
                      _Pastilla(
                          texto: 'Verificada',
                          color: AppColors.success500,
                          relleno:
                              AppColors.success500.withValues(alpha: 0.14),
                          icono: Icons.verified_rounded),
                  ],
                ),
                if (p.ubicacion?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.place_outlined,
                            size: 16, color: AppColors.muted),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(p.ubicacion!,
                            style: const TextStyle(
                                fontSize: 13.5, color: AppColors.muted)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SinFoto extends StatelessWidget {
  const _SinFoto({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        color: color.withValues(alpha: 0.10),
        alignment: Alignment.center,
        child: Icon(Icons.person_outline_rounded, size: 40, color: color),
      );
}

// ── Datos ────────────────────────────────────────────────────────────────────

class _Datos extends StatelessWidget {
  const _Datos({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final p = persona;

    final filas = <(String, String)>[
      if (p.edad != null) ('Edad', '${p.edad} anos'),
      if (p.genero?.isNotEmpty == true) ('Genero', _capital(p.genero!)),
      if (p.documento?.isNotEmpty == true) ('Documento', p.documento!),
      if (p.region?.isNotEmpty == true) ('Region', p.region!),
      if (p.hospital?.isNotEmpty == true) ('Hospital', p.hospital!),
      if (p.causa?.isNotEmpty == true) ('Motivo', _capital(p.causa!)),
    ];

    if (filas.isEmpty) {
      // Decirlo es mejor que dejar un hueco: la ficha existe, lo que falta son
      // los datos, y quien la lee puede aportarlos.
      return MTCard(
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Esta ficha no tiene mas datos publicados todavia.',
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                    height: 1.35),
              ),
            ),
          ],
        ),
      );
    }

    return MTCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(filas[i].$1,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13.5)),
                  ),
                  Expanded(
                    child: Text(filas[i].$2,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Contacto ─────────────────────────────────────────────────────────────────

class _Contacto extends StatelessWidget {
  const _Contacto({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final p = persona;

    return MTCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Rotulo('Si la has visto'),
          const SizedBox(height: 6),
          Text(
            p.contactoNombre?.isNotEmpty == true
                ? 'Avisa a ${p.contactoNombre} , quien publico esta ficha.'
                : 'Avisa a quien publico esta ficha.',
            style: const TextStyle(fontSize: 13.5, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (p.contactoTelefono?.isNotEmpty == true)
                FilledButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse('tel:${p.contactoTelefono}')),
                  icon: const Icon(Icons.call_rounded, size: 17),
                  label: const Text('Llamar'),
                ),
              if (p.contactoCorreo?.isNotEmpty == true)
                OutlinedButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse('mailto:${p.contactoCorreo}')),
                  icon: const Icon(Icons.mail_outline_rounded, size: 17),
                  label: const Text('Escribir'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Reacciones y procedencia ─────────────────────────────────────────────────

class _Reacciones extends StatelessWidget {
  const _Reacciones({required this.persona});

  final Persona persona;

  static const _emoji = {
    'fuerza': '💪',
    'corazon': '❤️',
    'difundir': '📣',
  };
  static const _nombre = {
    'fuerza': 'Fuerza',
    'corazon': 'Animo',
    'difundir': 'Difundir',
  };

  @override
  Widget build(BuildContext context) {
    return MTCard(
      child: Row(
        children: [
          for (final k in _emoji.keys) ...[
            Expanded(
              child: Column(
                children: [
                  Text(_emoji[k]!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text('${persona.reacciones[k] ?? 0}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(_nombre[k]!,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Procedencia extends StatelessWidget {
  const _Procedencia({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final p = persona;
    final partes = <String>[
      if (p.fuenteExterna?.isNotEmpty == true)
        'Importada de ${p.fuenteExterna}',
      if (p.creadaEn != null) 'Publicada el ${_fecha(p.creadaEn!)}',
      if (p.actualizadoEn != null)
        'Actualizada el ${_fecha(p.actualizadoEn!)}',
    ];

    if (partes.isEmpty) return const SizedBox.shrink();

    return Text(
      partes.join(' · '),
      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
    );
  }

  static String _fecha(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _AvisoDuplicada extends StatelessWidget {
  const _AvisoDuplicada();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.warning500.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.copy_all_rounded,
                size: 17, color: AppColors.warning500),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Puede haber otra ficha de esta misma persona. Si la ves, '
                'avisa: dos fichas dividen los avisos entre las dos.',
                style: TextStyle(fontSize: 12.5, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

// ── Piezas ───────────────────────────────────────────────────────────────────

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(texto.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w800,
          color: AppColors.muted));
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({
    required this.texto,
    required this.color,
    required this.relleno,
    this.icono,
  });

  final String texto;
  final Color color;
  final Color relleno;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: relleno, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Text(texto,
                style: TextStyle(
                    fontSize: 12.5,
                    color: color,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, this.alReintentar});

  final String texto;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
              if (alReintentar != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: alReintentar, child: const Text('Reintentar')),
              ],
            ],
          ),
        ),
      );
}
