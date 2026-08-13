/// Que se pinta sobre el mapa. Cada tipo es una capa que se prende y apaga
/// por separado, igual que en `CrisisMap.tsx`.
enum TipoPunto {
  ayuda('ayuda', 'Punto de ayuda'),
  hospital('hospital', 'Hospital'),
  refugio('refugio', 'Refugio'),
  rescate('rescate', 'Rescate'),
  zona('zona', 'Zona afectada');

  const TipoPunto(this.wire, this.etiqueta);

  final String wire;
  final String etiqueta;

  static TipoPunto? desdeWire(String? v) {
    for (final t in TipoPunto.values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

/// Punto geolocalizado del mapa de la emergencia.
///
/// TODO(schema): contrastar nombres de columna con `supabase/schema.sql` del
/// repo web antes de conectar contra el proyecto real.
class PuntoAyuda {
  const PuntoAyuda({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.lat,
    required this.lon,
    this.descripcion,
    this.direccion,
    this.telefono,
    this.disponible,
    this.actualizadoEn,
  });

  final String id;
  final String nombre;
  final TipoPunto tipo;
  final double lat;
  final double lon;
  final String? descripcion;
  final String? direccion;
  final String? telefono;

  /// El consenso de "si hay" / "se acabo" que la comunidad vota en la web.
  /// `null` = nadie ha reportado todavia, que no es lo mismo que "se acabo".
  final bool? disponible;

  final DateTime? actualizadoEn;

  factory PuntoAyuda.fromMap(Map<String, dynamic> m) => PuntoAyuda(
        id: m['id'].toString(),
        nombre: (m['nombre'] ?? '') as String,
        tipo: TipoPunto.desdeWire(m['tipo'] as String?) ?? TipoPunto.ayuda,
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        descripcion: m['descripcion'] as String?,
        direccion: m['direccion'] as String?,
        telefono: m['telefono'] as String?,
        disponible: m['disponible'] as bool?,
        actualizadoEn: m['updated_at'] == null
            ? null
            : DateTime.tryParse(m['updated_at'].toString()),
      );
}
