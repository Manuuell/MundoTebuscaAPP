import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/safety_repository.dart';
import '../../widgets/mt_card.dart';

final necesitanAyudaProvider =
    FutureProvider.autoDispose<List<PersonaNecesitaAyuda>>((ref) {
  return ref.read(safetyRepositoryProvider).listarNecesitanAyuda();
});

/// Lista de personas que la Red de auxilio marcó como "necesita ayuda" o que
/// no respondieron al check-in de un sismo. Solo para cuentas con rol
/// 'volunteer' — la Edge Function lo exige; aquí simplemente se muestra lo
/// que ella decida devolver.
class NecesitanAyudaScreen extends ConsumerWidget {
  const NecesitanAyudaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider);
    final lista = ref.watch(necesitanAyudaProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(title: const Text('Necesitan ayuda')),
      body: usuario == null
          ? const _Mensaje(
              icono: Icons.login_rounded,
              titulo: 'Inicia sesión',
              detalle: 'Esta lista es solo para cuentas con rol de '
                  'voluntario/a.',
            )
          : lista.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => e is SafetyException &&
                      e.type == SafetyError.notOptedIn
                  ? const _Mensaje(
                      icono: Icons.shield_outlined,
                      titulo: 'Sin permiso',
                      detalle: 'Tu cuenta todavía no tiene el rol de '
                          'voluntario/a asignado.',
                    )
                  : _Mensaje(
                      icono: Icons.cloud_off_rounded,
                      titulo: 'No pudimos cargar la lista',
                      detalle: 'Revisa tu conexión e intenta de nuevo.',
                      alReintentar: () =>
                          ref.invalidate(necesitanAyudaProvider),
                    ),
              data: (personas) {
                if (personas.isEmpty) {
                  return const _Mensaje(
                    icono: Icons.check_circle_outline_rounded,
                    titulo: 'Nadie necesita ayuda ahora mismo',
                    detalle: 'Cuando alguien no responda al check-in o diga '
                        'que no está bien, aparecerá aquí.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(necesitanAyudaProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: personas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _Tarjeta(persona: personas[i]),
                  ),
                );
              },
            ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.persona});

  final PersonaNecesitaAyuda persona;

  @override
  Widget build(BuildContext context) {
    final noRespondio = persona.status == 'no_response';

    return MTCard(
      onTap: persona.lat == null || persona.lng == null
          ? null
          : () => launchUrl(Uri.parse(
              'https://www.google.com/maps/search/?api=1&query='
              '${persona.lat},${persona.lng}')),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger500.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              noRespondio
                  ? Icons.phone_disabled_rounded
                  : Icons.emergency_rounded,
              color: AppColors.danger500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(persona.nombre ?? 'Persona sin perfil',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  noRespondio
                      ? 'No respondió al check-in'
                      : 'Dijo que no está bien',
                  style: const TextStyle(
                      color: AppColors.danger500,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
                if (persona.tipoSangre != null) ...[
                  const SizedBox(height: 4),
                  Text('Tipo de sangre: ${persona.tipoSangre}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12.5)),
                ],
                if (persona.lat != null && persona.lng != null) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 14, color: AppColors.brand700),
                      SizedBox(width: 3),
                      Text('Toca para ver la ubicación en el mapa',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.brand700)),
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

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.alReintentar,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback? alReintentar;

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
            if (alReintentar != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                  onPressed: alReintentar, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
