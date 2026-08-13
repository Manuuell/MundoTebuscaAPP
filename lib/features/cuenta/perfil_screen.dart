import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/mt_card.dart';
import 'login_screen.dart';

/// Avatar del usuario, reutilizable.
///
/// Cae en cascada: foto del perfil, luego la inicial del nombre, luego un
/// icono. Nunca queda un hueco vacio.
class AvatarUsuario extends ConsumerWidget {
  const AvatarUsuario({super.key, this.radio = 20});

  final double radio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider);
    final perfil = ref.watch(perfilProvider).valueOrNull;
    final foto = ref.read(authRepositoryProvider).fotoDe(perfil);

    final nombre = (perfil?['username'] ??
        usuario?.userMetadata?['display_name'] ??
        usuario?.email?.split('@').first) as String?;

    if (foto != null) {
      return CircleAvatar(
        radius: radio,
        backgroundColor: AppColors.brand50,
        backgroundImage: CachedNetworkImageProvider(foto),
      );
    }

    return CircleAvatar(
      radius: radio,
      backgroundColor: AppColors.brand50,
      child: nombre != null && nombre.isNotEmpty
          ? Text(
              nombre.characters.first.toUpperCase(),
              style: TextStyle(
                color: AppColors.brand700,
                fontWeight: FontWeight.w800,
                fontSize: radio * 0.9,
              ),
            )
          : Icon(Icons.person_rounded,
              color: AppColors.brand700, size: radio),
    );
  }
}

/// Mi perfil.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider);
    final perfil = ref.watch(perfilProvider).valueOrNull;

    final nombre = (perfil?['username'] ??
        usuario?.userMetadata?['display_name'] ??
        usuario?.email?.split('@').first) as String?;
    final bio = perfil?['bio'] as String?;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(title: const Text('Mi perfil')),
      body: usuario == null
          ? _SinSesion()
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(perfilProvider),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, MediaQuery.paddingOf(context).bottom + 24),
                children: [
                  MTCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const AvatarUsuario(radio: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre ?? 'Sin nombre',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 2),
                              Text(usuario.email ?? '',
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 13)),
                              if (bio?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(bio!,
                                    style: const TextStyle(height: 1.35)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tarjeta de voluntario digital, como en la web.
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.success500.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(MTCard.radio),
                      border: Border.all(
                          color: AppColors.success500.withValues(alpha: 0.30)),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppColors.success500,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: Colors.white,
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tu perfil de voluntario digital',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15)),
                                Text('Recien llegado',
                                    style: TextStyle(
                                        color: AppColors.success500,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Publica, comenta o reacciona a algo para dar tu '
                          'primer paso como voluntario digital.',
                          style: TextStyle(height: 1.35),
                        ),
                        const SizedBox(height: 16),
                        // Los contadores no se inventan: escribir todavia no
                        // esta habilitado en la app, asi que todos valen cero
                        // y se dice por que en vez de dejar seis ceros sueltos
                        // que parezcan un error de carga.
                        const _AvisoContadores(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  MTCard(
                    padding: EdgeInsets.zero,
                    clip: true,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.article_outlined,
                              color: AppColors.brand700),
                          title: const Text('Mis publicaciones'),
                          trailing: const Text('0',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.bookmark_border_rounded,
                              color: AppColors.brand700),
                          title: const Text('Guardados'),
                          trailing: const Text('0',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  MTCard(
                    padding: EdgeInsets.zero,
                    clip: true,
                    child: ListTile(
                      leading: const Icon(Icons.logout_rounded,
                          color: AppColors.danger500),
                      title: const Text('Cerrar sesion',
                          style: TextStyle(
                              color: AppColors.danger500,
                              fontWeight: FontWeight.w600)),
                      onTap: () => cerrarSesion(context, ref),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Cierra la sesion, preguntando antes.
///
/// Se confirma porque volver a entrar exige la contrasena, y en una emergencia
/// puede que quien use el telefono no la recuerde — un toque accidental no
/// deberia dejar a nadie fuera de su cuenta.
Future<void> cerrarSesion(BuildContext context, WidgetRef ref) async {
  final salir = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Cerrar sesion?'),
      content: const Text(
        'Para volver a entrar necesitaras tu usuario y contrasena. '
        'Podras seguir consultando la app sin sesion.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger500),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cerrar sesion'),
        ),
      ],
    ),
  );

  if (salir != true) return;

  await ref.read(authRepositoryProvider).salir();
  ref.invalidate(perfilProvider);

  if (context.mounted) {
    // Se vuelve atras: quedarse en "Mi perfil" sin sesion deja al usuario
    // mirando un estado vacio sin entender que paso.
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('Sesion cerrada.'),
        behavior: SnackBarBehavior.floating,
      ));
  }
}

class _AvisoContadores extends StatelessWidget {
  const _AvisoContadores();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.muted),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Publicar, comentar y reaccionar todavia se hacen desde el '
                'sitio web. Tu actividad aparecera aqui cuando se habiliten '
                'en la app.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
}

class _SinSesion extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 52, color: AppColors.border),
              const SizedBox(height: 16),
              Text('Sin sesion iniciada',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Entra con tu cuenta para ver tu perfil y tu actividad.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                ),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Entrar o crear cuenta'),
              ),
            ],
          ),
        ),
      );
}
