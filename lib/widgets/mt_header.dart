import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../features/cuenta/login_screen.dart';
import '../features/cuenta/perfil_screen.dart';
import '../repositories/auth_repository.dart';
import '../core/router/app_router.dart';
import 'guia_rapida_sheet.dart';
import 'mt_card.dart' show Press;

/// Lockup de marca.
///
/// Es el archivo real del disenador, no un wordmark reconstruido con `Text`:
/// asi la tipografia y el interletrado son los de la marca y no dependen de
/// que `google_fonts` acierte con el peso.
///
/// La version de cabecera deja fuera los lemas "juntos salvamos vidas" y
/// "voluntarios digitales" del lockup completo. A este tamano esas dos
/// lineas medirian dos o tres pixeles: no se leerian, solo ensuciarian. Van en
/// `lockup_completo`, para donde hay sitio de sobra.
class MarcaLockup extends StatelessWidget {
  const MarcaLockup({super.key, this.alto = 46, this.completo = false});

  final double alto;
  final bool completo;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      completo
          ? 'assets/images/lockup_completo.png'
          : 'assets/images/lockup.png',
      height: alto,
      // El logo lleva el nombre del producto; para un lector de pantalla es
      // el titulo de la pantalla, no una imagen decorativa.
      semanticLabel: 'El Mundo Te Busca',
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
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider);

    return AppBar(
      toolbarHeight: 74,
      titleSpacing: 16,
      title: const MarcaLockup(),
      actions: [
        ...acciones,
        Press(
          onTap: () => mostrarGuiaRapida(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Icon(Icons.help_outline_rounded,
                color: AppColors.muted, size: 24),
          ),
        ),
        Press(
          onTap: () => context.push(Rutas.asistente),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
                color: AppColors.brand50, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_rounded,
                size: 19, color: AppColors.brand700),
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
            child: Press(
              onTap: () => context.push(Rutas.perfil),
              child: const AvatarUsuario(radio: 16),
            ),
          ),
      ],
    );
  }
}
