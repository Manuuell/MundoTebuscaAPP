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
/// TODO(schema): los nombres de columna salen de lo que expone la web hoy.
/// Antes de conectar contra el proyecto real hay que contrastarlos con
/// `supabase/schema.sql` del repo web — si alguno no coincide, el `fromMap`
/// falla en silencio devolviendo null, no revienta.
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
    this.actualizadoEn,
  });

  final String id;
  final String nombre;
  final EstadoPersona estado;
  final int? edad;
  final String? documento;
  final String? ubicacion;
  final String? fotoUrl;
  final String? descripcion;
  final DateTime? actualizadoEn;

  /// La web marca aparte a los menores (`/?maxAge=11`); el corte vive aqui
  /// para no repetirlo en cada consulta.
  bool get esMenor => edad != null && edad! <= 11;

  factory Persona.fromMap(Map<String, dynamic> m) {
    return Persona(
      id: m['id'].toString(),
      nombre: (m['nombre'] ?? m['name'] ?? '') as String,
      estado: EstadoPersona.desdeWire(m['estado'] as String?) ??
          EstadoPersona.porLocalizar,
      edad: m['edad'] as int?,
      documento: m['documento'] as String?,
      ubicacion: m['ubicacion'] as String?,
      fotoUrl: m['foto_url'] as String?,
      descripcion: m['descripcion'] as String?,
      actualizadoEn: m['updated_at'] == null
          ? null
          : DateTime.tryParse(m['updated_at'].toString()),
    );
  }
}
