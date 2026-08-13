import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/mt_header.dart' show MarcaLockup;
import 'perfil_screen.dart';
import 'login_screen.dart';

final _versionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Configuracion y perfil.
///
/// Ocupa el sitio que tenia SOS en la barra inferior. La linea de emergencia
/// NO desaparece por eso: sigue arriba del todo aqui y en la portada, porque
/// es lo unico de la app que tiene que alcanzarse sin pensar.
class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider);
    final perfil = ref.watch(perfilProvider).valueOrNull;
    final pais = ref.watch(paisProvider);
    final version = ref.watch(_versionProvider).valueOrNull ?? '—';

    final nombre = (perfil?['display_name'] ??
            perfil?['username'] ??
            usuario?.userMetadata?['display_name'] ??
            usuario?.email?.split('@').first) as String?;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(title: const Text('Configuracion')),
      body: ListView(
        children: [
          // ── Emergencia, siempre lo primero ──────────────────────────
          if (pais.lineaEmergencia != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Material(
                color: AppColors.danger500.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      launchUrl(Uri.parse('tel:${pais.lineaEmergencia}')),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(pais.lineaEmergencia!,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    color: AppColors.danger500,
                                    fontWeight: FontWeight.w800)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Emergencias en ${pais.nombre}. Policia, bomberos '
                            'y ambulancias, 24 horas.',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.call_rounded,
                            color: AppColors.danger500),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Perfil ──────────────────────────────────────────────────
          _Seccion(titulo: 'Mi cuenta'),
          if (usuario == null)
            _Tarjeta(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'No has iniciado sesion. Con una cuenta podras publicar, '
                      'comentar y recibir avisos sobre tus publicaciones.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const LoginScreen()),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Entrar o crear cuenta'),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _Tarjeta(
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.brand50,
                      child: Text(
                        (nombre ?? '?').characters.first.toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.brand700,
                            fontWeight: FontWeight.w800,
                            fontSize: 20),
                      ),
                    ),
                    title: Text(nombre ?? 'Sin nombre',
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(usuario.email ?? ''),
                  ),
                  const Divider(height: 1),
                  _Dato(
                      etiqueta: 'Identificador',
                      valor: '${usuario.id.substring(0, 8)}…'),
                  if (usuario.createdAt.isNotEmpty)
                    _Dato(
                      etiqueta: 'Miembro desde',
                      valor: _fecha(DateTime.tryParse(usuario.createdAt)),
                    ),
                  _Dato(
                    etiqueta: 'Correo confirmado',
                    valor: usuario.emailConfirmedAt != null ? 'Si' : 'No',
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded,
                        color: AppColors.brand700),
                    title: const Text('Ver mi perfil'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const PerfilScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded,
                        color: AppColors.danger500),
                    title: const Text('Cerrar sesion',
                        style: TextStyle(color: AppColors.danger500)),
                    onTap: () async {
                      await ref.read(authRepositoryProvider).salir();
                      ref.invalidate(perfilProvider);
                    },
                  ),
                ],
              ),
            ),

          // ── Emergencia activa ───────────────────────────────────────
          _Seccion(titulo: 'Emergencia'),
          _Tarjeta(
            child: Column(
              children: [
                for (final p in paisesSemilla)
                  RadioGroup<String>(
                    groupValue: pais.codigo,
                    onChanged: (_) =>
                        ref.read(paisProvider.notifier).cambiar(p),
                    child: ListTile(
                      leading: Text(p.bandera,
                          style: const TextStyle(fontSize: 24)),
                      title: Text(p.nombre),
                      subtitle: p.magnitud == null ? null : Text(p.magnitud!),
                      trailing: Radio<String>(value: p.codigo),
                    ),
                  ),
              ],
            ),
          ),

          // ── Acerca de ───────────────────────────────────────────────
          _Seccion(titulo: 'Acerca de'),
          _Tarjeta(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 22, 16, 18),
                  child: Center(child: MarcaLockup(alto: 76, completo: true)),
                ),
                const Divider(height: 1),
                _Dato(etiqueta: 'Version', valor: version),
                ListTile(
                  leading: const Icon(Icons.public_rounded,
                      color: AppColors.brand700),
                  title: const Text('Abrir el sitio web'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('https://elmundotebusca.com'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _fecha(DateTime? d) =>
      d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
        child: Text(titulo.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: AppColors.muted)),
      );
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta)),
            Text(valor,
                style: const TextStyle(
                    color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
