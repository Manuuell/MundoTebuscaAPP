import 'package:flutter/material.dart';

/// Llaves globales de los widgets que señala la guía interactiva
/// (`guia_interactiva.dart`).
///
/// Viven en un archivo aparte porque las usan dos lados que no se conocen
/// entre sí: quien PINTA el widget (`HomeShell`, cada pantalla) y quien
/// arma la lista de pasos del recorrido (`guia_rapida_sheet.dart`, o el de
/// cada sección). Son variables de nivel superior — no un campo de estado —
/// porque `GlobalKey` no tiene constructor `const` y solo debe crearse una
/// vez por widget real, nunca en cada `build`.
///
/// Para que cada compañero pueda añadir sus propios pasos (Comunidad,
/// Ayuda, Mapa…): declara aquí la llave del widget que quieres señalar,
/// asígnala con `key: miClave` al widget real, y arma tu `GuiaPaso` en tu
/// propio archivo — no hace falta tocar este.
class GuiaClaves {
  const GuiaClaves._();

  static final tabInicio = GlobalKey(debugLabel: 'tab-inicio');
  static final tabSeBusca = GlobalKey(debugLabel: 'tab-se-busca');
  static final tabComunidad = GlobalKey(debugLabel: 'tab-comunidad');
  static final tabMapa = GlobalKey(debugLabel: 'tab-mapa');
  static final tabAjustes = GlobalKey(debugLabel: 'tab-ajustes');
  static final botonAsistente = GlobalKey(debugLabel: 'boton-asistente');

  // Añadidas por cada sección al integrar su propio tramo del recorrido:
  // static final botonPublicarComunidad = GlobalKey(debugLabel: '...');
  // static final botonFiltrosAyuda = GlobalKey(debugLabel: '...');
}
