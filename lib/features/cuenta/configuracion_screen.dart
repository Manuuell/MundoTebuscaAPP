import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/state/pais_provider.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/safety_repository.dart';
import '../../widgets/asistente_sheet.dart';
import '../../widgets/mt_card.dart';
import 'login_screen.dart';
import 'perfil_screen.dart';
import 'red_auxilio_provider.dart';

final _versionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Ajustes: perfil, cuenta y sesion.
///
/// Sigue `mockups/ajustes.html`. Ojo con lo que NO esta aqui: la linea de
/// emergencia. El mockup no la incluye y SOS vive en la hoja "Mas", asi que
/// repetirla aqui solo duplicaria contenido — pero conviene saberlo, porque en
/// una app de desastres es el dato mas critico de toda la interfaz.
class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider);
    final perfil = ref.watch(perfilProvider).valueOrNull;
    final version = ref.watch(_versionProvider).valueOrNull ?? '—';
    final pais = ref.watch(paisProvider);

    final nombre = (perfil?['username'] ??
        usuario?.userMetadata?['display_name'] ??
        usuario?.email?.split('@').first) as String?;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Ajustes',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26)),
        actions: const [BotonAsistente(), SizedBox(width: 8)],
      ),
      body: usuario == null
          ? const _SinSesion()
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
              children: [
                _TarjetaPerfil(nombre: nombre, perfil: perfil),
                const SizedBox(height: 14),
                const _Contadores(),
                const SizedBox(height: 22),
                const _Rotulo('SECCIONES'),
                const SizedBox(height: 8),
                const _BloqueSecciones(),
                const SizedBox(height: 22),
                const _Rotulo('RED DE AUXILIO'),
                const SizedBox(height: 8),
                MTCard(
                  padding: EdgeInsets.zero,
                  clip: true,
                  child: _RedAuxilioSeccion(paisCodigo: pais.codigo),
                ),
                const SizedBox(height: 22),
                const _Rotulo('CUENTA'),
                const SizedBox(height: 8),
                _BloqueCuenta(perfil: perfil),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => cerrarSesion(context, ref),
                    child: const Text('Cerrar sesion'),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: () => _eliminarCuenta(context),
                    child: const Text('Eliminar cuenta',
                        style: TextStyle(
                            color: AppColors.danger500,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const Center(
                  child: Text(
                    'No borra tus publicaciones, solo las desvincula',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 26),
                Center(
                  child: Text('Version $version',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.border)),
                ),
              ],
            ),
    );
  }

  /// Eliminar la cuenta es irreversible y necesita permisos de administrador,
  /// que la app no tiene ni debe tener. Se explica y se remite a la web, en vez
  /// de ofrecer un boton que no puede cumplir lo que promete.
  Future<void> _eliminarCuenta(BuildContext context) async {
    final ir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta accion no se puede deshacer. Tus publicaciones no se borran: '
          'se desvinculan de ti.\n\n'
          'Por seguridad, la eliminacion se hace desde el sitio web.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger500),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir el sitio'),
          ),
        ],
      ),
    );

    if (ir == true) {
      await launchUrl(Uri.parse('https://elmundotebusca.com/configuracion'),
          mode: LaunchMode.externalApplication);
    }
  }
}

// ── Perfil ───────────────────────────────────────────────────────────────────

class _TarjetaPerfil extends StatelessWidget {
  const _TarjetaPerfil({required this.nombre, required this.perfil});

  final String? nombre;
  final Map<String, dynamic>? perfil;

  @override
  Widget build(BuildContext context) {
    final usuarioArroba = perfil?['username'] as String?;
    final bio = perfil?['bio'] as String?;

    final subtitulo = [
      if (usuarioArroba != null) '@$usuarioArroba',
      if (bio?.trim().isNotEmpty == true) bio!.trim(),
    ].join(' · ');

    return MTCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AvatarUsuario(radio: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre ?? 'Sin nombre',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy700)),
                if (subtitulo.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitulo,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13)),
                ],
                const SizedBox(height: 10),
                Press(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PerfilScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.brand50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_circle_outlined,
                            size: 16, color: AppColors.brand700),
                        SizedBox(width: 6),
                        Text('Ver perfil publico',
                            style: TextStyle(
                                color: AppColors.brand700,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contadores extends StatelessWidget {
  const _Contadores();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(
            child: _Contador(
                icono: Icons.article_outlined,
                valor: '0',
                etiqueta: 'Mis publicaciones'),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _Contador(
                icono: Icons.bookmark_border_rounded,
                valor: '0',
                etiqueta: 'Guardados'),
          ),
        ],
      );
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  final IconData icono;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => MTCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icono, size: 22, color: AppColors.brand700),
            const SizedBox(height: 8),
            Text(valor,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy700)),
            const SizedBox(height: 2),
            Text(etiqueta,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
      );
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w800,
                color: AppColors.muted)),
      );
}

/// Destinos que en la web cuelgan del menu. Viven aqui para que ninguna ruta
/// quede sin punto de entrada.
class _BloqueSecciones extends StatelessWidget {
  const _BloqueSecciones();

  @override
  Widget build(BuildContext context) => MTCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(
          children: [
            _Fila(
              icono: Icons.emergency_rounded,
              color: AppColors.danger500,
              titulo: 'Emergencia y seguridad',
              detalle: 'Telefonos y guia de las primeras horas',
              alTocar: () => context.push(Rutas.sos),
            ),
            const Divider(height: 1, indent: 66),
            _Fila(
              icono: Icons.smart_toy_rounded,
              color: AppColors.brand500,
              titulo: 'Asistente',
              detalle: 'Pregunta sobre la emergencia o la app',
              alTocar: () => context.push(Rutas.asistente),
            ),
            const Divider(height: 1, indent: 66),
            _Fila(
              icono: Icons.local_hospital_outlined,
              color: AppColors.brand700,
              titulo: 'Ayuda y hospitales',
              alTocar: () => context.push(Rutas.ayuda),
            ),
            const Divider(height: 1, indent: 66),
            _Fila(
              icono: Icons.pets_outlined,
              color: AppColors.warning500,
              titulo: 'Mascotas',
              alTocar: () => context.push(Rutas.mascotas),
            ),
          ],
        ),
      );
}

// ── Cuenta ───────────────────────────────────────────────────────────────────

class _BloqueCuenta extends ConsumerWidget {
  const _BloqueCuenta({required this.perfil});

  final Map<String, dynamic>? perfil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recuperacion = perfil?['recovery_email'] as String?;
    final avisos = perfil?['email_notifications'] as bool? ?? false;

    return MTCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          _Fila(
            icono: Icons.lock_outline_rounded,
            color: AppColors.info500,
            titulo: 'Cambiar contrasena',
            alTocar: () => _cambiarClave(context, ref),
          ),
          const Divider(height: 1, indent: 66),
          _Fila(
            icono: Icons.mail_outline_rounded,
            color: const Color(0xFF8B5CF6),
            titulo: 'Correo de recuperacion',
            detalle: recuperacion?.isNotEmpty == true
                ? recuperacion
                : 'No configurado',
            // Escribir en `profiles` necesita permisos que la app no tiene
            // todavia: se cambia en la web.
            alTocar: () => launchUrl(
              Uri.parse('https://elmundotebusca.com/configuracion'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const Divider(height: 1, indent: 66),
          _Fila(
            icono: Icons.notifications_none_rounded,
            color: AppColors.success500,
            titulo: 'Avisos por correo',
            detalle: 'Cambios en tus publicaciones',
            // El interruptor refleja el estado pero no lo guarda: eso es una
            // escritura en `profiles`. Uno que se mueve y no guarda es peor que
            // uno que dice por que no se puede.
            control: Switch(
              value: avisos,
              onChanged: (_) => ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(const SnackBar(
                  content: Text(
                      'Este ajuste se cambia por ahora desde el sitio web.'),
                  behavior: SnackBarBehavior.floating,
                )),
            ),
          ),
        ],
      ),
    );
  }

  /// Cambiar contrasena SI funciona desde la app: es Supabase Auth, no
  /// `profiles`, asi que no depende de las politicas que hoy bloquean el resto.
  Future<void> _cambiarClave(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final form = GlobalKey<FormState>();

    final nueva = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contrasena'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nueva contrasena',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '').length < 6 ? 'Usa al menos 6 caracteres.' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, ctrl.text);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (nueva == null || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(supabaseClientProvider)
          .auth
          .updateUser(UserAttributes(password: nueva));
      mensajero
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Contrasena actualizada.'),
          behavior: SnackBarBehavior.floating,
        ));
    } catch (e) {
      mensajero
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('No pudimos cambiarla: $e'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.color,
    required this.titulo,
    this.detalle,
    this.alTocar,
    this.control,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String? detalle;
  final VoidCallback? alTocar;
  final Widget? control;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: alTocar,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icono, size: 19, color: color),
      ),
      title: Text(titulo,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.navy700)),
      subtitle: detalle == null
          ? null
          : Text(detalle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      trailing: control ??
          (alTocar == null
              ? null
              : const Icon(Icons.chevron_right_rounded,
                  color: AppColors.muted)),
    );
  }
}

class _SinSesion extends StatelessWidget {
  const _SinSesion();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_outlined,
                  size: 52, color: AppColors.border),
              const SizedBox(height: 16),
              Text('Sin sesion iniciada',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Entra con tu cuenta para gestionar tu perfil y tus ajustes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).push(
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
