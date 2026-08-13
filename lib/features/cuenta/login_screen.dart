import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/auth_repository.dart';

/// Entrar o crear cuenta contra el Supabase real del sitio.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _nombre = TextEditingController();

  bool _registrando = false;
  bool _ocupado = false;
  bool _verClave = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _ocupado = true;
      _error = null;
    });

    final auth = ref.read(authRepositoryProvider);
    try {
      if (_registrando) {
        final r = await auth.registrar(
          correo: _correo.text,
          clave: _clave.text,
          nombre: _nombre.text,
        );
        if (!mounted) return;
        // Si el proyecto pide confirmar por correo, `session` viene null: la
        // cuenta existe pero todavia no se puede entrar. Decirlo, en vez de
        // dejar la pantalla como si no hubiera pasado nada.
        if (r.session == null) {
          setState(() => _error =
              'Cuenta creada. Revisa tu correo para confirmarla y luego '
              'inicia sesion.');
          setState(() => _registrando = false);
          return;
        }
      } else {
        await auth.entrar(correo: _correo.text, clave: _clave.text);
      }
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _error = _mensaje(e));
    } catch (_) {
      setState(() => _error = 'No pudimos conectar. Revisa tu conexion.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Los mensajes de Supabase vienen en ingles y son crudos.
  String _mensaje(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Correo o contrasena incorrectos.';
    }
    if (m.contains('already registered') || m.contains('already been')) {
      return 'Ese correo ya tiene cuenta. Inicia sesion.';
    }
    if (m.contains('password') && m.contains('least')) {
      return 'La contrasena es demasiado corta.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(_registrando ? 'Crear cuenta' : 'Entrar')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _registrando
                  ? 'Crea tu cuenta para publicar y comentar.'
                  : 'Entra con tu cuenta de El Mundo Te Busca.',
              style: t.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            if (_registrando) ...[
              TextFormField(
                controller: _nombre,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Como quieres que te vean',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Correo',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Escribe tu correo.';
                if (!t.contains('@') || !t.contains('.')) {
                  return 'Ese correo no parece valido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _clave,
              obscureText: !_verClave,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _ocupado ? null : _enviar(),
              decoration: InputDecoration(
                labelText: 'Contrasena',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_verClave
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  onPressed: () => setState(() => _verClave = !_verClave),
                ),
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Escribe tu contrasena.';
                if (_registrando && v!.length < 6) {
                  return 'Usa al menos 6 caracteres.';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger500.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger500)),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _ocupado ? null : _enviar,
              child: _ocupado
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_registrando ? 'Crear cuenta' : 'Entrar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _ocupado
                  ? null
                  : () => setState(() {
                        _registrando = !_registrando;
                        _error = null;
                      }),
              child: Text(_registrando
                  ? 'Ya tengo cuenta'
                  : 'No tengo cuenta, quiero crear una'),
            ),
          ],
        ),
      ),
    );
  }
}
