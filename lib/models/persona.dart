/// Estado de una persona reportada.
///
/// Los valores de cadena son los que la web ya usa como filtro en la URL
/// (`/?status=por_localizar`, `hospitalizado`, `localizado`, `fallecido`), asi
/// que un enlace compartido desde la web abre el mismo filtro en la app.
enum EstadoPersona {
  porLocalizar('por_localizar', 'Por localizar'),
  hospitalizado('hospitalizado', 'En hospital'),
  localizado('localizado', 'A salvo'),
  fallecido('fallecido', 'Fallecido');

  const EstadoPersona(this.wire, this.etiqueta);

  /// Valor tal cual viaja en la base y en los enlaces.
  final String wire;
  final String etiqueta;

  static EstadoPersona? desdeWire(String? v) {
    for (final e in EstadoPersona.values) {
      if (e.wire == v) return e;
    }
    return null;
  }
}

/// Persona publicada en "Se busca".
///
/// Columnas verificadas contra `supabase/schema.sql` del repo web (tabla
/// `persons`, no `personas`) — ver la corrección en
/// `plan-app-movil/06-correcciones-y-reparto.md` §Parte 1. Ojo particular con
/// `estado`: en `persons` esa columna es la región geográfica (ej. "Zulia"),
/// NO el status de búsqueda — `EstadoPersona` lee de la columna `status`.
class Persona {
  const Persona({
    required this.id,
    required this.nombre,
    required this.estado,
    this.edad,
    this.documento,
    this.ubicacion,
    this.fotoUrl,
    this.descripcion,
    this.paisCodigo,
    this.esNoIdentificada = false,
    this.lat,
    this.lng,
    this.actualizadoEn,
    this.genero,
    this.region,
    this.causa,
    this.hospital,
    this.contactoNombre,
    this.contactoTelefono,
    this.contactoCorreo,
    this.verificada = false,
    this.posibleDuplicada = false,
    this.fuenteExterna,
    this.reacciones = const {},
    this.creadaEn,
  });

  final String id;
  final String nombre;
  final EstadoPersona estado;
  final int? edad;
  final String? documento;
  final String? ubicacion;
  final String? fotoUrl;
  final String? descripcion;
  final String? paisCodigo;

  /// Distingue "Busco a alguien" (false) de "Vi/encontré a alguien" (true) —
  /// misma tabla `persons`, es lo que separa "Se busca" de "¿La reconoces?".
  final bool esNoIdentificada;

  /// Nullable en la base: mucha ubicación es solo `ubicacion` (texto libre),
  /// sin coordenadas.
  final double? lat;
  final double? lng;

  final DateTime? actualizadoEn;

  final String? genero;

  /// `estado` en la base: la region geografica, NO el estado de busqueda.
  final String? region;

  /// Por que se busca a esta persona (`cause`), ej. "desastre".
  final String? causa;

  /// Centro donde esta internada, si `status` es hospitalizado.
  final String? hospital;

  /// Datos de quien publico la ficha, para avisarle si se la ve.
  final String? contactoNombre;
  final String? contactoTelefono;
  final String? contactoCorreo;

  /// Revisada por el equipo.
  final bool verificada;

  /// El sistema detecto otra ficha parecida. Importa ensenarlo: dos fichas de
  /// la misma persona dividen los avisos entre ambas.
  final bool posibleDuplicada;

  /// De donde se ingirio, si no se creo aqui.
  final String? fuenteExterna;

  final Map<String, int> reacciones;
  final DateTime? creadaEn;

  /// La web marca aparte a los menores (`/?maxAge=11`); el corte vive aqui
  /// para no repetirlo en cada consulta.
  bool get esMenor => edad != null && edad! <= 11;

  factory Persona.fromMap(Map<String, dynamic> m) {
    final crudas = m['reactions'];
    final reacciones = <String, int>{};
    if (crudas is Map) {
      crudas.forEach((k, v) {
        final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
        if (n > 0) reacciones['$k'] = n;
      });
    }

    final nombre = [m['first_name'], m['last_name']]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
    return Persona(
      id: m['id'].toString(),
      nombre: nombre,
      estado: EstadoPersona.desdeWire(m['status'] as String?) ??
          EstadoPersona.porLocalizar,
      edad: m['age'] as int?,
      documento: m['cedula'] as String?,
      ubicacion: m['location_text'] as String?,
      fotoUrl: m['photo_url'] as String?,
      descripcion: m['description'] as String?,
      paisCodigo: m['country'] as String?,
      esNoIdentificada: m['is_unidentified'] as bool? ?? false,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      actualizadoEn: m['updated_at'] == null
          ? null
          : DateTime.tryParse(m['updated_at'].toString()),
      genero: m['gender'] as String?,
      region: m['estado'] as String?,
      causa: m['cause'] as String?,
      hospital: m['hospital_name'] as String?,
      contactoNombre: m['contact_name'] as String?,
      contactoTelefono: m['contact_phone'] as String?,
      contactoCorreo: m['contact_email'] as String?,
      verificada: m['verified'] as bool? ?? false,
      posibleDuplicada: m['possible_duplicate'] as bool? ?? false,
      fuenteExterna: m['external_source'] as String?,
      reacciones: reacciones,
      creadaEn: m['created_at'] == null
          ? null
          : DateTime.tryParse(m['created_at'].toString()),
    );
  }
}
