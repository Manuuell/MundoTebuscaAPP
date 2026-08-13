import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mundo_te_busca/core/util/freshness.dart';
import 'package:mundo_te_busca/models/pais.dart';
import 'package:mundo_te_busca/models/persona.dart';
import 'package:mundo_te_busca/widgets/cifra_chip.dart';

void main() {
  group('EstadoPersona', () {
    test('los valores wire son los mismos que usa la web en la URL', () {
      // Si estos cambian, los enlaces compartidos desde la web dejan de abrir
      // el filtro correcto en la app.
      expect(EstadoPersona.porLocalizar.wire, 'por_localizar');
      expect(EstadoPersona.hospitalizado.wire, 'hospitalizado');
      expect(EstadoPersona.localizado.wire, 'localizado');
      expect(EstadoPersona.fallecido.wire, 'fallecido');
    });

    test('un estado desconocido no revienta, devuelve null', () {
      expect(EstadoPersona.desdeWire('inventado'), isNull);
      expect(EstadoPersona.desdeWire(null), isNull);
    });
  });

  group('CifrasSismo', () {
    test('una cifra de hace mas de 30 dias no cuenta como reciente', () {
      final vieja = CifrasSismo(
        fallecidos: 132,
        fecha: DateTime.now().subtract(const Duration(days: 45)),
      );
      expect(vieja.esReciente, isFalse);
    });

    test('una cifra de ayer si cuenta como reciente', () {
      final fresca = CifrasSismo(
        fallecidos: 250,
        fecha: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(fresca.esReciente, isTrue);
    });

    test('sin fecha nunca es reciente', () {
      expect(const CifrasSismo(fallecidos: 10).esReciente, isFalse);
    });
  });

  group('Fresh', () {
    test('un dato recien traido no esta viejo', () {
      expect(Fresh.now(const CifrasPanel()).isStale, isFalse);
    });

    test('pasados 5 minutos se marca como viejo', () {
      final f = Fresh(
        const CifrasPanel(),
        DateTime.now().subtract(const Duration(minutes: 6)),
      );
      expect(f.isStale, isTrue);
    });
  });

  testWidgets('CifraChip nunca pinta un numero negativo', (tester) async {
    // Es el defecto que hoy tiene la web al cambiar de pais: el panel muestra
    // "-25 personas buscadas". Una cifra negativa es un error de calculo, y en
    // esta pantalla destruye la credibilidad del tablero entero.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CifraChip(
              valor: -25,
              etiqueta: 'Personas buscadas',
              color: Colors.red,
            ),
          ),
        ),
      ),
    );

    expect(find.text('-25'), findsNothing);
    expect(find.text('0'), findsOneWidget);
  });
}
