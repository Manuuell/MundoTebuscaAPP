/// Emergencia activa por pais.
///
/// La app se abre siempre sobre una: el selector de la web
/// (`CountrySwitcher`) se reduce en movil a un control compacto en la barra
/// superior.
class Pais {
  const Pais({
    required this.codigo,
    required this.nombre,
    required this.bandera,
    this.magnitud,
    this.fechaSismo,
    this.lineaEmergencia,
  });

  /// ISO-3166 alpha-2, en minusculas: `co`, `ve`.
  final String codigo;
  final String nombre;
  final String bandera;
  final String? magnitud;
  final DateTime? fechaSismo;

  /// Cambia por pais: 123 en Colombia, 911 en Venezuela. La web ya lo hace.
  final String? lineaEmergencia;

  factory Pais.fromMap(Map<String, dynamic> m) => Pais(
        codigo: (m['codigo'] as String).toLowerCase(),
        nombre: m['nombre'] as String,
        bandera: (m['bandera'] ?? '') as String,
        magnitud: m['magnitud'] as String?,
        fechaSismo: m['fecha_sismo'] == null
            ? null
            : DateTime.tryParse(m['fecha_sismo'].toString()),
        lineaEmergencia: m['linea_emergencia'] as String?,
      );
}

/// Cifras del sismo segun prensa, con su procedencia.
///
/// La fuente y la fecha son parte del dato, no decoracion: la regla de la web
/// (`CRISIS_STAT_FRESHNESS_MS`) es no mostrar nunca una cifra vieja como si
/// fuera reciente. Si `fecha` pasa de 30 dias, la UI degrada al bloque curado.
class CifrasSismo {
  const CifrasSismo({
    this.fallecidos,
    this.heridos,
    this.desaparecidos,
    this.fuente,
    this.fecha,
  });

  final int? fallecidos;
  final int? heridos;
  final int? desaparecidos;
  final String? fuente;
  final DateTime? fecha;

  static const _frescura = Duration(days: 30);

  bool get esReciente =>
      fecha != null && DateTime.now().difference(fecha!) < _frescura;

  factory CifrasSismo.fromMap(Map<String, dynamic> m) => CifrasSismo(
        fallecidos: m['fallecidos'] as int?,
        heridos: m['heridos'] as int?,
        desaparecidos: m['desaparecidos'] as int?,
        fuente: m['fuente'] as String?,
        fecha: m['fecha'] == null
            ? null
            : DateTime.tryParse(m['fecha'].toString()),
      );
}

/// Las 8 cifras deslizables del Inicio (`DashboardStats.tsx:34-59`).
/// Cada una es un enlace a su filtro en "Se busca".
class CifrasPanel {
  const CifrasPanel({
    this.desaparecidos = 0,
    this.enHospitales = 0,
    this.aSalvo = 0,
    this.ninos = 0,
    this.fallecidos = 0,
    this.denuncias = 0,
    this.necesidades = 0,
    this.ofrecenAyuda = 0,
    this.reportesVerificados = 0,
    this.voluntariosActivos = 0,
    this.puntosAyuda = 0,
  });

  final int desaparecidos;
  final int enHospitales;
  final int aSalvo;
  final int ninos;
  final int fallecidos;
  final int denuncias;
  final int necesidades;
  final int ofrecenAyuda;

  // Las del panel "Juntos somos mas fuertes" del hero.
  final int reportesVerificados;
  final int voluntariosActivos;
  final int puntosAyuda;

  int get personasBuscadas => desaparecidos + enHospitales + aSalvo;

  factory CifrasPanel.fromMap(Map<String, dynamic> m) => CifrasPanel(
        desaparecidos: (m['desaparecidos'] ?? 0) as int,
        enHospitales: (m['en_hospitales'] ?? 0) as int,
        aSalvo: (m['a_salvo'] ?? 0) as int,
        ninos: (m['ninos'] ?? 0) as int,
        fallecidos: (m['fallecidos'] ?? 0) as int,
        denuncias: (m['denuncias'] ?? 0) as int,
        necesidades: (m['necesidades'] ?? 0) as int,
        ofrecenAyuda: (m['ofrecen_ayuda'] ?? 0) as int,
        reportesVerificados: (m['reportes_verificados'] ?? 0) as int,
        voluntariosActivos: (m['voluntarios_activos'] ?? 0) as int,
        puntosAyuda: (m['puntos_ayuda'] ?? 0) as int,
      );
}
