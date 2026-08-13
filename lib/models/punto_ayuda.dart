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
/// Columnas verificadas contra `supabase/schema.sql` del repo web (tabla
/// `aid_points`, no `puntos_ayuda`) — ver la corrección en
/// `plan-app-movil/06-correcciones-y-reparto.md` §Parte 1.
///
/// `tipo` aquí es la CAPA del mapa (ayuda/hospital/refugio/rescate/zona, como
/// en `CrisisMap.tsx`), no la columna real `types` de `aid_points` (que es un
/// array de categorías del punto: comida/agua/medicina/... — dominio de
/// valores distinto). Todo lo que sale de `aid_points` es la capa `ayuda`;
/// hospitales/refugios/rescates/zonas vienen de otras tablas que
/// `AyudaRepository` todavía no conecta (Parte 2, Persona B).
class PuntoAyuda {
  const PuntoAyuda({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.lat,
    this.lng,
    this.descripcion,
    this.direccion,
    this.telefono,
    this.disponible,
    this.paisCodigo,
    this.actualizadoEn,
  });

  final String id;
  final String nombre;
  final TipoPunto tipo;

  /// Nullable en la base: mucha ubicación es solo `direccion` (texto libre),
  /// sin coordenadas.
  final double? lat;
  final double? lng;
  final String? descripcion;
  final String? direccion;
  final String? telefono;

  /// El consenso de "si hay" / "se acabo" que la comunidad vota en la web.
  /// `null` = nadie ha reportado todavia, que no es lo mismo que "se acabo".
  final bool? disponible;

  final String? paisCodigo;

  final DateTime? actualizadoEn;

  factory PuntoAyuda.fromMap(Map<String, dynamic> m) => PuntoAyuda(
        id: m['id'].toString(),
        nombre: (m['name'] ?? '') as String,
        // Fila de `aid_points`: siempre capa "ayuda" (ver nota de clase).
        tipo: TipoPunto.ayuda,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        descripcion: m['description'] as String?,
        direccion: m['location_text'] as String?,
        telefono: m['contact_phone'] as String?,
        disponible: m['available'] as bool?,
        paisCodigo: m['country'] as String?,
        actualizadoEn: m['updated_at'] == null
            ? null
            : DateTime.tryParse(m['updated_at'].toString()),
      );
}
