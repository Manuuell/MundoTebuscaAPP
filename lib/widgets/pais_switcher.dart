import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state/pais_provider.dart';
import '../core/theme/app_colors.dart';
import '../models/pais.dart';

/// Selector de emergencia activa.
///
/// En escritorio la web lo pinta como una tarjeta grande; en movil se reduce a
/// esto: bandera + nombre + chevron en la barra superior.
class PaisSwitcher extends ConsumerWidget {
  const PaisSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pais = ref.watch(paisProvider);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _elegir(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pais.bandera, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              pais.nombre,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _elegir(BuildContext context, WidgetRef ref) async {
    final elegido = await showModalBottomSheet<Pais>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Que emergencia quieres ver',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Veras sus personas buscadas, mapa, ayuda y noticias.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            for (final p in paisesSemilla)
              ListTile(
                leading:
                    Text(p.bandera, style: const TextStyle(fontSize: 26)),
                title: Text(p.nombre),
                subtitle: p.magnitud == null ? null : Text(p.magnitud!),
                onTap: () => Navigator.pop(sheetContext, p),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (elegido != null) {
      await ref.read(paisProvider.notifier).cambiar(elegido);
    }
  }
}
