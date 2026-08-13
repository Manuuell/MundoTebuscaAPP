import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Tipos de publicacion del muro (`posts.type`, 7 valores).
enum TipoPublicacion {
  necesito('necesito', 'Necesito', Icons.pan_tool_rounded, AppColors.danger500),
  ofrezco('ofrezco', 'Ofrezco', Icons.volunteer_activism_rounded,
      AppColors.success500),
  rescate('rescate', 'Rescate', Icons.emergency_rounded, AppColors.warning500),
  medico('medico', 'Medico', Icons.medical_services_rounded, AppColors.info500),
  caravana('caravana', 'Caravana', Icons.local_shipping_rounded,
      AppColors.brand500),
  identificar('identificar', 'Identificar', Icons.help_outline_rounded,
      AppColors.navy700),
  info('info', 'Informacion', Icons.campaign_rounded, AppColors.brand700);

  const TipoPublicacion(this.wire, this.etiqueta, this.icono, this.color);

  final String wire;
  final String etiqueta;
  final IconData icono;
  final Color color;

  static TipoPublicacion desdeWire(String? v) {
    for (final t in TipoPublicacion.values) {
      if (t.wire == v) return t;
    }
    return TipoPublicacion.info;
  }
}

/// Publicacion del muro de Comunidad (tabla `posts`).
class Publicacion {
  const Publicacion({
    required this.id,
    required this.tipo,
    required this.cuerpo,
    this.autor,
    this.ubicacion,
    this.region,
    this.fotoUrl,
    this.enlaceUrl,
    this.telefono,
    this.fijado = false,
    this.reacciones = const {},
    this.totalReacciones = 0,
    this.origen,
    this.creadoEn,
  });

  final String id;
  final TipoPublicacion tipo;
  final String cuerpo;
  final String? autor;

  /// Texto libre de ubicacion (`location_text`).
  final String? ubicacion;

  /// Region geografica (`estado`) — ojo, no es el estado de una persona.
  final String? region;

  final String? fotoUrl;
  final String? enlaceUrl;
  final String? telefono;
  final bool fijado;

  /// `reactions` es jsonb: {"apoyo": 134, "corazon": 22, "hecho": 0}.
  final Map<String, int> reacciones;
  final int totalReacciones;

  /// `community` si lo escribio alguien aqui; si no, la red de la que se
  /// ingirio (Bluesky, Mastodon).
  final String? origen;

  final DateTime? creadoEn;

  bool get esExterno => origen != null && origen != 'community';

  factory Publicacion.fromMap(Map<String, dynamic> m) {
    final crudas = m['reactions'];
    final reacciones = <String, int>{};
    if (crudas is Map) {
      crudas.forEach((k, v) {
        final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
        if (n > 0) reacciones['$k'] = n;
      });
    }

    return Publicacion(
      id: m['id'].toString(),
      tipo: TipoPublicacion.desdeWire(m['type'] as String?),
      cuerpo: (m['body'] ?? '') as String,
      autor: m['author_name'] as String?,
      ubicacion: m['location_text'] as String?,
      region: m['estado'] as String?,
      fotoUrl: m['photo_url'] as String?,
      enlaceUrl: m['link_url'] as String?,
      telefono: m['contact_phone'] as String?,
      fijado: m['pinned'] as bool? ?? false,
      reacciones: reacciones,
      totalReacciones: (m['reactions_total'] as num?)?.toInt() ?? 0,
      origen: m['origin'] as String?,
      creadoEn: m['created_at'] == null
          ? null
          : DateTime.tryParse(m['created_at'].toString()),
    );
  }
}

/// Denuncia de irregularidad en la ayuda (tabla `complaints`).
class Denuncia {
  const Denuncia({
    required this.id,
    required this.categoria,
    required this.cuerpo,
    this.autor,
    this.ubicacion,
    this.region,
    this.fotoUrl,
    this.apoyos = 0,
    this.creadaEn,
  });

  final String id;
  final String categoria;
  final String cuerpo;
  final String? autor;
  final String? ubicacion;
  final String? region;
  final String? fotoUrl;
  final int apoyos;
  final DateTime? creadaEn;

  /// `desvio_ayuda` -> "Desvio de ayuda".
  String get categoriaLegible {
    if (categoria.isEmpty) return 'Denuncia';
    final t = categoria.replaceAll('_', ' ');
    return t[0].toUpperCase() + t.substring(1);
  }

  factory Denuncia.fromMap(Map<String, dynamic> m) => Denuncia(
        id: m['id'].toString(),
        categoria: (m['category'] ?? '') as String,
        cuerpo: (m['body'] ?? '') as String,
        autor: m['author_name'] as String?,
        ubicacion: m['location_text'] as String?,
        region: m['estado'] as String?,
        fotoUrl: m['photo_url'] as String?,
        apoyos: (m['supports'] as num?)?.toInt() ?? 0,
        creadaEn: m['created_at'] == null
            ? null
            : DateTime.tryParse(m['created_at'].toString()),
      );
}

/// Voluntario inscrito (tabla `volunteers`).
class Voluntario {
  const Voluntario({
    required this.id,
    required this.nombre,
    this.tipo,
    this.disponibilidad,
    this.habilidades,
    this.region,
  });

  final String id;
  final String nombre;
  final String? tipo;
  final String? disponibilidad;
  final String? habilidades;
  final String? region;

  factory Voluntario.fromMap(Map<String, dynamic> m) => Voluntario(
        id: m['id'].toString(),
        nombre: (m['name'] ?? '') as String,
        tipo: m['type'] as String?,
        disponibilidad: m['availability_text'] as String?,
        habilidades: m['skills_text'] as String?,
        region: m['estado'] as String?,
      );
}

/// Caravana / marcha de ayuda (tabla `marches`).
class Caravana {
  const Caravana({
    required this.id,
    required this.titulo,
    this.origen,
    this.destino,
    this.saleEn,
    this.organizador,
    this.telefono,
    this.whatsappUrl,
  });

  final String id;
  final String titulo;
  final String? origen;
  final String? destino;
  final DateTime? saleEn;
  final String? organizador;
  final String? telefono;
  final String? whatsappUrl;

  factory Caravana.fromMap(Map<String, dynamic> m) => Caravana(
        id: m['id'].toString(),
        titulo: (m['title'] ?? '') as String,
        origen: m['origin_text'] as String?,
        destino: m['destination_text'] as String?,
        saleEn: m['depart_at'] == null
            ? null
            : DateTime.tryParse(m['depart_at'].toString()),
        organizador: m['organizer_name'] as String?,
        telefono: m['organizer_phone'] as String?,
        whatsappUrl: m['whatsapp_url'] as String?,
      );
}

/// Comentario de una publicacion (tabla `comments`).
///
/// La tabla es polimorfica: `entity_type` + `entity_id` apuntan a lo comentado
/// (hoy `post`, pero el mismo mecanismo sirve para personas o puntos de ayuda).
class Comentario {
  const Comentario({
    required this.id,
    required this.cuerpo,
    this.autor,
    this.padreId,
    this.fotoUrl,
    this.likes = 0,
    this.usuarioId,
    this.creadoEn,
  });

  final String id;
  final String cuerpo;
  final String? autor;

  /// Respuesta a otro comentario del mismo hilo.
  final String? padreId;

  final String? fotoUrl;
  final int likes;

  /// Hoy siempre null: nadie tiene cuenta todavia. Cuando exista la Fase 3 es
  /// lo que permite saber a quien avisar de una respuesta.
  final String? usuarioId;

  final DateTime? creadoEn;

  bool get esRespuesta => padreId != null;

  factory Comentario.fromMap(Map<String, dynamic> m) => Comentario(
        id: m['id'].toString(),
        cuerpo: (m['body'] ?? '') as String,
        autor: m['author_name'] as String?,
        padreId: m['parent_id']?.toString(),
        fotoUrl: m['photo_url'] as String?,
        likes: (m['likes'] as num?)?.toInt() ?? 0,
        usuarioId: m['user_id']?.toString(),
        creadoEn: m['created_at'] == null
            ? null
            : DateTime.tryParse(m['created_at'].toString()),
      );
}
