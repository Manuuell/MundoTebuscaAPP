import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/guia_rapida_sheet.dart';

/// SOS: la pantalla que tiene que funcionar aunque todo lo demas falle.
///
/// Por eso el numero de emergencia NO viene de la red: sale del pais activo,
/// que ya esta en memoria. Una pantalla de emergencia que necesita conexion
/// para mostrar un telefono no sirve de nada en una emergencia.
class SosScreen extends ConsumerWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pais = ref.watch(paisProvider);
    final linea = pais.lineaEmergencia;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergencia y seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (linea != null)
            Card(
              color: AppColors.danger500.withValues(alpha: 0.08),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                leading: Text(
                  linea,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppColors.danger500,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                title: Text('Linea unica de emergencias · ${pais.nombre}'),
                subtitle: const Text(
                  'Policia, bomberos y ambulancias. Desde cualquier telefono, '
                  '24 horas.',
                ),
                onTap: () => launchUrl(Uri.parse('tel:$linea')),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.warning500.withValues(alpha: 0.10),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Protege a la ninez: no dejes a ninos y ninas solos ni con '
                'personas que no conoces, ni siquiera en refugios o colas. '
                'Mantenlos con un familiar o adulto de confianza.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Guia rapida', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_rounded,
                  color: AppColors.brand700),
              title: const Text('Que hacer en las primeras horas'),
              subtitle: const Text('9 pasos · funciona sin conexion'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => mostrarGuiaRapida(context),
            ),
          ),
        ],
      ),
    );
  }
}
