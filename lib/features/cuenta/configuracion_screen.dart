import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/pais_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/safety_repository.dart';
import '../../widgets/mt_header.dart' show MarcaLockup;
import 'login_screen.dart';
import 'red_auxilio_provider.dart';

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

          // ── Red de auxilio ──────────────────────────────────────────
          _Seccion(titulo: 'Red de auxilio'),
          _Tarjeta(child: _RedAuxilioSeccion(paisCodigo: pais.codigo)),

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

/// Interruptor de "¿Estas bien?" tras un sismo.
///
/// Ver plan-app-movil/investigacion-tecnica/10-alerta-sismo-checkin.md. La
/// regla clave va en el propio texto de consentimiento: si no respondes o
/// dices que necesitas ayuda, la ubicacion se comparte — eso hay que saberlo
/// ANTES de activarlo, no despues.
class _RedAuxilioSeccion extends ConsumerWidget {
  const _RedAuxilioSeccion({required this.paisCodigo});

  final String paisCodigo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(redAuxilioProvider);
    final notifier = ref.read(redAuxilioProvider.notifier);
    final activa = estado.fase == RedAuxilioFase.activa;
    final cargando = estado.fase == RedAuxilioFase.cargando;

    ref.listen(redAuxilioProvider, (anterior, actual) {
      if (actual.error != null && actual.error != anterior?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mensajeError(actual.error!))),
        );
      }
    });

    return Column(
      children: [
        SwitchListTile(
          value: activa,
          onChanged: cargando || estado.ocupado
              ? null
              : (encender) => encender
                  ? notifier.activar(paisCodigo)
                  : notifier.desactivar(),
          secondary: estado.ocupado
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Icon(
                  Icons.shield_moon_rounded,
                  color: activa ? AppColors.brand700 : AppColors.muted,
                ),
          title: const Text('Avisar si estoy cerca de un sismo'),
          subtitle: const Text(
            'Si hay un sismo cerca de ti, te preguntamos si estas bien. Si no '
            'respondes o necesitas ayuda, tu ubicacion se comparte con '
            'voluntarios y rescatistas de la app cerca de ti. Puedes '
            'desactivarlo cuando quieras.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
        if (activa) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bolt_rounded, color: AppColors.warning500),
            title: const Text('Probar el aviso ahora'),
            subtitle: const Text(
              'Simula un sismo cercano sin esperar a uno real, para revisar '
              'el flujo completo.',
              style: TextStyle(fontSize: 12.5),
            ),
            onTap: () async {
              final mensajero = ScaffoldMessenger.of(context);
              try {
                await ref.read(safetyRepositoryProvider).probarAlerta();
                mensajero.showSnackBar(const SnackBar(
                  content: Text('Aviso de prueba enviado.'),
                ));
              } catch (_) {
                mensajero.showSnackBar(const SnackBar(
                  content: Text('No se pudo enviar el aviso de prueba.'),
                ));
              }
            },
          ),
        ],
      ],
    );
  }

  static String _mensajeError(SafetyError error) => switch (error) {
        SafetyError.locationDenied =>
          'Necesitamos permiso de ubicacion para activarlo. Revisalo en '
              'Ajustes del sistema.',
        SafetyError.locationServiceOff =>
          'Activa el GPS del telefono para poder usar la red de auxilio.',
        SafetyError.network => 'No se pudo conectar. Intenta de nuevo.',
        SafetyError.notOptedIn => 'Primero activa el interruptor.',
      };
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
