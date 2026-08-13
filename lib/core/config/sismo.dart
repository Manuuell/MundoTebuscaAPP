import 'package:latlong2/latlong.dart';

/// Epicentro de la emergencia, para dibujarlo en el mapa.
///
/// No sale de la base: es un hecho fijo del evento, no un dato que la
/// comunidad edite. Los valores son los del catalogo de USGS, que es la
/// fuente que publica magnitud y coordenadas revisadas.
///
/// Solo esta Colombia. Se busco el equivalente venezolano en el mismo
/// catalogo (M4.5+ entre el 20 de julio y el 14 de agosto de 2026, ventana
/// 7N-13.5N / 74O-59O) y el mayor evento es un M4.5 en Yumare, que no
/// corresponde a la emergencia que describe el contenido del sitio. Antes que
/// dibujar un epicentro inventado sobre Venezuela, ese pais no tiene capa: el
/// mapa simplemente no la pinta hasta que alguien traiga la referencia buena.
class Sismo {
  const Sismo({
    required this.centro,
    required this.magnitud,
    required this.lugar,
    required this.cuando,
    required this.radioAfectadoKm,
  });

  final LatLng centro;
  final double magnitud;
  final String lugar;
  final DateTime cuando;

  /// Radio que se sombrea en el mapa. Es una ayuda visual para situar la zona,
  /// no un limite de danos: los danos de un sismo siguen la geologia y no un
  /// circulo. Se eligio para cubrir los departamentos con desaparecidos
  /// registrados (Risaralda, Valle del Cauca, Choco, Quindio, Caldas).
  final double radioAfectadoKm;

  String get titulo => 'Epicentro M$magnitud';
}

final sismosPorPais = <String, Sismo>{
  'co': Sismo(
    centro: const LatLng(4.8436, -76.2422),
    magnitud: 7.4,
    lugar: '5 km al sur de San José del Palmar, Chocó',
    cuando: DateTime.utc(2026, 8, 10, 12, 34),
    radioAfectadoKm: 120,
  ),
};
