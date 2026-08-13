import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Destino del enlace de gestion que llega por correo:
/// `/persona/{id}/gestion?token=...`
///
/// El token NO se valida en el cliente. La comprobacion equivalente a
/// `verifyResourceOwner` (`src/lib/data.ts:1219` en el repo web) tiene que
/// correr en el servidor —Edge Function o RLS—, porque cualquier cosa que
/// decida el telefono se puede saltar editando la peticion.
class PersonaGestionScreen extends StatelessWidget {
  const PersonaGestionScreen({super.key, required this.id, this.token});

  final String id;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final sinToken = token == null || token!.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar publicacion')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            sinToken
                ? 'Este enlace no trae token de gestion. Abre el enlace '
                    'completo que te llego por correo.'
                : 'Pendiente: validar el token contra el servidor y permitir '
                    'actualizar el estado de la persona $id.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}
