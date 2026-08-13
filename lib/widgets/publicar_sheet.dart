import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/state/pais_provider.dart';
import '../core/theme/app_colors.dart';
import '../features/cuenta/login_screen.dart';
import '../models/persona.dart';
import '../models/publicacion.dart';
import '../repositories/auth_repository.dart';

/// Formularios de publicacion.
///
/// Se abre como hoja y no como pantalla: son pocos campos y quien publica en
/// una emergencia quiere terminar rapido y volver a lo que estaba mirando.
Future<bool> mostrarPublicarPost(BuildContext context) =>
    _mostrar(context, esPersona: false);

Future<bool> mostrarPublicarPersona(BuildContext context) =>
    _mostrar(context, esPersona: true);

Future<bool> _mostrar(BuildContext context, {required bool esPersona}) async {
  final hecho = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _Formulario(esPersona: esPersona),
    ),
  );
  return hecho ?? false;
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.esPersona});

  final bool esPersona;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  final _form = GlobalKey<FormState>();
  final _cuerpo = TextEditingController();
  final _nombre = TextEditingController();
  final _lugar = TextEditingController();
  final _telefono = TextEditingController();
  final _edad = TextEditingController();

  TipoPublicacion _tipo = TipoPublicacion.necesito;
  EstadoPersona _estado = EstadoPersona.porLocalizar;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _cuerpo.dispose();
    _nombre.dispose();
    _lugar.dispose();
    _telefono.dispose();
    _edad.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _error = null;
    });

    final pais = ref.read(paisProvider);
    final perfil = ref.read(perfilProvider).valueOrNull;
    final usuario = ref.read(usuarioProvider);
    final autor = (perfil?['username'] ??
        usuario?.userMetadata?['display_name'] ??
        'Anonimo') as String;

    final datos = widget.esPersona
        ? {
            'tipo': 'persona',
            'country': pais.codigo,
            'first_name': _nombre.text,
            'age': int.tryParse(_edad.text.trim()),
            'location_text': _lugar.text,
            'description': _cuerpo.text,
            'status': _estado.wire,
            'contact_name': autor,
            'contact_phone': _telefono.text,
            'author_name': autor,
          }
        : {
            'tipo': 'post',
            'country': pais.codigo,
            'type': _tipo.wire,
            'body': _cuerpo.text,
            'location_text': _lugar.text,
            'contact_phone': _telefono.text,
            'author_name': autor,
          };

    try {
      await ref.read(authRepositoryProvider).publicar(datos);
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos conectar. Revisa tu conexion.');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(usuarioProvider);
    final persona = widget.esPersona;

    if (usuario == null) return const _NecesitaSesion();

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(persona ? 'Publicar una persona' : 'Publicar en Comunidad',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  persona
                      ? 'Se publicara para que otros puedan reconocerla.'
                      : 'Lo veran los demas al instante en el muro.',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),

                if (persona) ...[
                  TextFormField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().length < 2
                        ? 'Escribe el nombre.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _edad,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Edad',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<EstadoPersona>(
                          initialValue: _estado,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final e in EstadoPersona.values)
                              DropdownMenuItem(
                                  value: e, child: Text(e.etiqueta)),
                          ],
                          onChanged: (v) =>
                              setState(() => _estado = v ?? _estado),
                        ),
                      ),
                    ],
                  ),
                ] else
                  DropdownButtonFormField<TipoPublicacion>(
                    initialValue: _tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de publicacion',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in TipoPublicacion.values)
                        DropdownMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(t.icono, size: 17, color: t.color),
                              const SizedBox(width: 8),
                              Text(t.etiqueta),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _tipo = v ?? _tipo),
                  ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _cuerpo,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: persona ? 1500 : 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: persona
                        ? 'Senas, ropa, ultima vez que se la vio *'
                        : '¿Que quieres contar? *',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (persona) return null;
                    return t.length < 10 ? 'Escribe un poco mas.' : null;
                  },
                ),
                TextFormField(
                  controller: _lugar,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Lugar',
                    hintText: 'Barrio, ciudad o punto de referencia',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefono de contacto',
                    helperText: 'Sera visible para quien lea la publicacion',
                    border: OutlineInputBorder(),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
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

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _enviando ? null : _enviar,
                    child: _enviando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Publicar'),
                  ),
                ),
                const SizedBox(height: 10),
                // Publicar en una emergencia es un acto publico: quien escribe
                // debe saber que su nombre y su telefono se ven.
                Text(
                  'Se publicara con tu nombre de usuario. No incluyas datos '
                  'que no quieras que vea cualquiera.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NecesitaSesion extends StatelessWidget {
  const _NecesitaSesion();

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 44, color: AppColors.border),
              const SizedBox(height: 14),
              Text('Necesitas una cuenta',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Publicar exige iniciar sesion, para que cada publicacion '
                'tenga a alguien detras.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Entrar o crear cuenta'),
                ),
              ),
            ],
          ),
        ),
      );
}
