import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/state/pais_provider.dart';
import '../core/theme/app_colors.dart';
import 'mt_card.dart';

/// Organizacion que recibe donaciones para la emergencia.
class Organizacion {
  const Organizacion({
    required this.nombre,
    required this.descripcion,
    required this.url,
    required this.icono,
    required this.color,
  });

  final String nombre;
  final String descripcion;
  final String url;
  final IconData icono;
  final Color color;

  String get dominio => Uri.tryParse(url)?.host ?? url;
}

/// Organizaciones por pais.
///
/// Lista corta y verificada a mano. Aqui NO se improvisa: un enlace de
/// donacion equivocado manda dinero a quien no es, y en una emergencia la
/// gente dona rapido y sin comprobar. Si un pais no tiene organizaciones
/// confirmadas, se dice — no se rellena con lo que suene plausible.
const _porPais = <String, List<Organizacion>>{
  'co': [
    Organizacion(
      nombre: 'Cruz Roja Colombiana',
      descripcion:
          'Rescate, primeros auxilios y ayuda humanitaria en la zona afectada.',
      url: 'https://ayuda.cruzrojacolombiana.org/emergencia-colombia-terremoto',
      icono: Icons.local_hospital_rounded,
      color: AppColors.danger500,
    ),
    Organizacion(
      nombre: 'UNICEF Colombia',
      descripcion:
          'Agua, salud y proteccion para ninas y ninos afectados por el sismo.',
      url: 'https://unicef.org.co/terremoto-colombia',
      icono: Icons.child_care_rounded,
      color: AppColors.info500,
    ),
  ],
};

/// Hoja de donaciones.
Future<void> mostrarDonar(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => Consumer(
      builder: (sheetContext, ref, _) {
        final pais = ref.watch(paisProvider);
        final orgs = _porPais[pais.codigo] ?? const <Organizacion>[];

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Donar',
                      style:
                          Theme.of(sheetContext).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Organizaciones que atienden la emergencia en '
                    '${pais.nombre}.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),

                  if (orgs.isEmpty)
                    const _SinOrganizaciones()
                  else ...[
                    for (var i = 0; i < orgs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MTEntrada(
                          indice: i,
                          child: _TarjetaOrg(org: orgs[i]),
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Que quede claro quien cobra: la app no toca el dinero.
                    // Si alguien cree que dono "en la app" y algo sale mal,
                    // reclamara donde no es.
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.bgBase,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 17, color: AppColors.muted),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'La donacion se hace en el sitio de cada '
                              'organizacion. El Mundo Te Busca no recibe ni '
                              'gestiona el dinero.',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _TarjetaOrg extends StatelessWidget {
  const _TarjetaOrg({required this.org});

  final Organizacion org;

  @override
  Widget build(BuildContext context) {
    return MTCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _abrir(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: org.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(org.icono, color: org.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(org.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.navy700)),
                const SizedBox(height: 4),
                Text(org.descripcion,
                    style: const TextStyle(height: 1.35, fontSize: 13.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.open_in_new_rounded,
                        size: 14, color: AppColors.brand700),
                    const SizedBox(width: 6),
                    Text('Donar en ${org.dominio}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.brand700,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Avisa del salto antes de abrir.
  ///
  /// Con dinero de por medio el aviso pesa mas que en una noticia: enseñar el
  /// dominio real es lo que permite a alguien notar que no esta donando donde
  /// cree.
  Future<void> _abrir(BuildContext context) async {
    final seguir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Donar a ${org.nombre}'),
        content: Text(
          'Se abrira ${org.dominio}, el sitio oficial de la organizacion.\n\n'
          'La donacion se hace alli: El Mundo Te Busca no recibe ni gestiona '
          'el dinero.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir')),
        ],
      ),
    );

    if (seguir == true) {
      await launchUrl(Uri.parse(org.url), mode: LaunchMode.externalApplication);
    }
  }
}

class _SinOrganizaciones extends StatelessWidget {
  const _SinOrganizaciones();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Todavia no hay campanas verificadas',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
              'Preferimos no listar enlaces sin confirmar: en una emergencia '
              'circulan campanas falsas y una donacion mal dirigida no se '
              'recupera.',
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35),
            ),
          ],
        ),
      );
}
