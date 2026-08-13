import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../features/cuenta/login_screen.dart';
import '../repositories/auth_repository.dart';
import 'guia_rapida_sheet.dart';
import 'mt_card.dart' show Press;

/// Marca: el corazon mas el wordmark en dos lineas, igual que la cabecera del
/// sitio.
class MarcaLockup extends StatelessWidget {
  const MarcaLockup({super.key, this.alto = 38});

  final double alto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/marca.png', height: alto),
        const SizedBox(width: 9),
        const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('El Mundo',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy700,
                )),
            Text('Te Busca',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy700,
                )),
          ],
        ),
      ],
    );
  }
}

/// Cabecera de la app, con la misma composicion que el sitio: marca a la
/// izquierda, ayuda y sesion a la derecha.
///
/// El boton de ayuda abre la guia rapida. Es el refuerzo de acceso que
/// describe la investigacion —equivalente al `SafetyBanner` de la web— y no un
/// boton flotante: dos elementos flotantes en la misma pantalla competirian
/// con la tab bar.
class MTHeader extends ConsumerWidget implements PreferredSizeWidget {
  const MTHeader({super.key, this.acciones = const []});

  /// Acciones propias de la pantalla, antes de las comunes.
  final List<Widget> acciones;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider);

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 16,
      title: const MarcaLockup(),
      actions: [
        ...acciones,
        Press(
          onTap: () => mostrarGuiaRapida(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Icon(Icons.help_outline_rounded,
                color: AppColors.muted, size: 24),
          ),
        ),
        if (usuario == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              ),
              icon: const Icon(Icons.login_rounded, size: 17),
              label: const Text('Entrar'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.brand50,
              child: Text(
                (usuario.userMetadata?['display_name'] as String? ??
                        usuario.email ??
                        '?')
                    .characters
                    .first
                    .toUpperCase(),
                style: const TextStyle(
                    color: AppColors.brand700,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}
