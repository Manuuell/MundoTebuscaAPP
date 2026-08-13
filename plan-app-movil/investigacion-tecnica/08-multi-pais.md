# 08 — Multi-país en la app móvil: cómo implementarlo técnicamente

> Investigación de solo lectura sobre `C:\Users\angel\Desktop\Elmundotebusca` (repo web,
> NO modificado) y `C:\Users\angel\Desktop\MundoTebuscaAPP\plan-app-movil\` (plan móvil,
> NO modificado). La decisión de que la app sea multi-país desde el día uno ya está
> tomada (`05-fuente-web-existente.md:10`); este documento cubre el **cómo**, que el
> plan todavía no detalla.

---

## 0. Resumen de lo que la web ya hace hoy (punto de partida)

Fuente central: `src/lib/countries.ts:1-356` (ver también `src/lib/country-server.ts`,
`src/components/CountrySwitcher.tsx`, `src/components/CountryIntroModal.tsx`,
`src/components/FlagIcon.tsx`, `supabase/schema.sql:99-534`).

- `COUNTRY_CODES = ["ve", "co"] as const` (`countries.ts:12`) — los únicos dos países
  "activos" (con datos reales: mapa, cifras, teléfonos, noticias).
- `COUNTRIES: Record<CountryCode, CountryConfig>` (`countries.ts:141`) — un objeto único,
  toda la configuración por país vive **en código**, no en la base de datos.
- `AMERICAS_COUNTRIES` (`countries.ts:327-355`) — lista amplia de ~26 países de América
  solo para el selector de bienvenida (mostrar "aquí también existimos, aún no activo
  en tu país"); elegir uno de estos **no** cambia el país activo ni carga datos reales.
- Persistencia: **cookie** `emb_country` (`country-server.ts:5`), 1 año de duración,
  leída en servidor (`getActiveCountry()`), sin auto-detección por configuración
  regional del teléfono — confirmado leyendo `CountryIntroModal.tsx`: la pantalla de
  bienvenida es un selector manual, no hay `navigator.language` ni similar en ningún
  archivo del repo.
- Filtrado de datos: cada tabla relevante tiene columna `country text not null default
  've'` + índice (`supabase/schema.sql:101-102`, `266-267`, `292-293`, `322-323`,
  `400-401`, `423-424`, `445-446`, `468-469`, `514-515`, `533-534`) y **cada función**
  de `src/lib/data.ts` repite `.eq("country", country)` a mano (decenas de ocurrencias,
  ver p. ej. `data.ts:322`, `461`, `547`, `604`, `651`) — **no** hay un wrapper central
  del cliente Supabase que inyecte el filtro automáticamente en la web actual.

Esto último es relevante para el punto 4: la web *no* resolvió este problema de forma
elegante — cada `data.ts` function recuerda el filtro manualmente, y el plan móvil no
tiene por qué copiar ese descuido.

---

## 1. Configuración centralizada de país en Dart

Traducción directa de `CountryConfig` (`countries.ts:48-76`) a Dart. Los campos que
existen hoy en la web: `code`, `name`, `demonym`, `flag` (emoji, no usado en UI real —
ver punto 2), `callingCode`, `examplePhone`, `exampleCity`, `regions`, `regionCoords`,
`epicenter`, `quakeInfo` (magnitude/depthKm/epicenterText/date/dateISO/deaths/
injured/mostAffected/alsoAffected/sourceName), `emergency` (nationalLine + groups de
`PhoneGroup`/`PhoneEntry`), `usgsBbox`, `news` (matchPattern/searchQuery/gl — estos tres
son específicos de la ingesta de noticias en servidor, probablemente **no** hacen falta
en el cliente móvil si las noticias se siguen sirviendo pre-calculadas, ver nota al final).

```dart
// lib/core/country/country_config.dart

enum CountryCode { ve, co }

extension CountryCodeX on CountryCode {
  /// Coincide 1:1 con COUNTRY_CODES en countries.ts:12 (texto en minúsculas,
  /// es el valor que se guarda tal cual en la columna `country` de Postgres).
  String get value => name; // 've' / 'co'

  static CountryCode? fromValue(String? raw) {
    for (final c in CountryCode.values) {
      if (c.value == raw) return c;
    }
    return null; // equivalente a isCountryCode() devolviendo false
  }
}

const kDefaultCountry = CountryCode.ve; // countries.ts:15

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

class PhoneEntry {
  final String name;
  final List<String> phones;
  const PhoneEntry({required this.name, required this.phones});
}

class PhoneGroup {
  final String title;
  final String? note;
  final List<PhoneEntry> entries;
  const PhoneGroup({required this.title, this.note, required this.entries});
}

class EmergencyInfo {
  final ({String number, String label}) nationalLine;
  final List<PhoneGroup> groups;
  const EmergencyInfo({required this.nationalLine, required this.groups});
}

class QuakeInfo {
  final String magnitude;
  final int depthKm;
  final String epicenterText;
  final String date;
  final DateTime dateISO;
  final int deaths;
  final int injured;
  final String mostAffected;
  final List<String> alsoAffected;
  final String sourceName;
  const QuakeInfo({
    required this.magnitude,
    required this.depthKm,
    required this.epicenterText,
    required this.date,
    required this.dateISO,
    required this.deaths,
    required this.injured,
    required this.mostAffected,
    required this.alsoAffected,
    required this.sourceName,
  });
}

class CountryConfig {
  final CountryCode code;
  final String name;
  final String demonym;
  final String flagAsset; // ver punto 2: NO usamos el emoji, sino un asset SVG propio
  final String callingCode;
  final String examplePhone;
  final String exampleCity;
  final List<String> regions;
  final Map<String, LatLng> regionCoords;
  final LatLng epicenter;
  final QuakeInfo quakeInfo;
  final EmergencyInfo emergency;

  const CountryConfig({
    required this.code,
    required this.name,
    required this.demonym,
    required this.flagAsset,
    required this.callingCode,
    required this.examplePhone,
    required this.exampleCity,
    required this.regions,
    required this.regionCoords,
    required this.epicenter,
    required this.quakeInfo,
    required this.emergency,
  });
}

// Solo el esqueleto — los valores reales (regiones, coordenadas, cifras del
// sismo, teléfonos) se copian literal de countries.ts:141-303, son datos, no
// lógica; mantenerlos sincronizados a mano entre los dos repos es aceptable
// porque cambian con poca frecuencia (una vez por país activado).
final Map<CountryCode, CountryConfig> kCountries = {
  CountryCode.ve: const CountryConfig(
    code: CountryCode.ve,
    name: 'Venezuela',
    demonym: 'venezolano',
    flagAsset: 'assets/flags/ve.svg',
    callingCode: '+58',
    examplePhone: '+58 4XX 0000000',
    exampleCity: 'Caracas, La Guaira...',
    regions: [/* ... VE_REGIONS, countries.ts:78-103 ... */],
    regionCoords: {/* ... countries.ts:152-176 ... */},
    epicenter: LatLng(10.45, -68.5),
    quakeInfo: QuakeInfo(
      magnitude: '7,2 y 7,5',
      depthKm: 10,
      epicenterText: '≈28 km al SE de Yumare (Yaracuy)',
      date: '24–25 de junio de 2026',
      dateISO: DateTime(2026, 6, 24),
      deaths: 1719,
      injured: 5034,
      mostAffected: 'La Guaira (Caraballeda, Catia La Mar)',
      alsoAffected: ['Falcón', 'Miranda', 'Carabobo (Valencia)', 'Aragua (Maracay)', 'Distrito Capital (Caracas)'],
      sourceName: 'Infobae, Telemundo (29 jun. 2026)',
    ),
    emergency: EmergencyInfo(
      nationalLine: (number: '911', label: 'VEN 9‑1‑1 — Línea única nacional'),
      groups: [/* ... countries.ts:194-222 ... */],
    ),
  ),
  CountryCode.co: const CountryConfig(/* ... countries.ts:232-303 ... */),
};

CountryConfig getCountry(CountryCode? code) => kCountries[code ?? kDefaultCountry]!;
```

Notas de diseño:

- **Un solo archivo, un solo mapa** — exactamente el mismo principio que el comentario
  en `countries.ts:1-8` ("añadir un país nuevo = añadir una entrada aquí"). Igual en
  Dart: nada en el resto de la app debe tener un `if (country == 've')` disperso; todo
  pasa por `kCountries[code]`.
- `AMERICAS_COUNTRIES` (`countries.ts:322-355`, la lista de bienvenida) se traduce como
  una `List<({String code, String name})>` separada — no necesita `CountryConfig`
  completo porque no tiene datos reales detrás (mismo comentario que en la web,
  `countries.ts:314-321`).
- El campo `news` de `CountryConfig` (matchPattern/searchQuery/gl) es un detalle de
  *ingesta* server-side (RSS/GDELT), no de presentación — **no** lo traduzcas a Dart.
  Si la app va a mostrar el mismo carrusel de noticias que la web
  (`VerifiedNewsCarousel.tsx`, mencionado en `02-contenido-y-navegacion.md:66-69`), lo
  natural es que ese contenido se siga generando en el servidor (cron ya existente,
  `GET /api/cron/warm-news`) y la app solo lo lea de una tabla, no que reimplemente la
  búsqueda de noticias en Dart.

---

## 2. Selector de país en la UI móvil

### Patrón recomendado: bottom sheet con banderas, no dropdown de Material

El control compacto de la barra superior (bandera + nombre + chevron,
`02-contenido-y-navegacion.md:44-45`) debe abrir un **modal bottom sheet**
(`showModalBottomSheet`) con la lista de países — es el equivalente nativo directo del
`CountryIntroModal`/`CountrySwitcher` web, que ya usan un modal (`Modal.tsx`) con una
grilla de banderas. Un `DropdownButton` de Material queda mal en iOS (rompe la
convención de la plataforma) y no da espacio para el subtítulo "Activo · M7,2" que hoy
muestra `CountryIntroModal.tsx:143-147`.

```dart
// Control compacto en el AppBar (equivalente a CountrySwitcher.tsx pero
// colapsado, ver 02-contenido-y-navegacion.md:43-45)
class CountryBarControl extends StatelessWidget {
  final CountryCode active;
  final ValueChanged<CountryCode> onChanged;
  const CountryBarControl({required this.active, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    final c = kCountries[active]!;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _openPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SvgPicture.asset(c.flagAsset, width: 22, height: 16),
            ),
            const SizedBox(width: 6),
            Text(c.name, style: Theme.of(context).textTheme.labelLarge),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CountryPickerSheet(active: active, onChanged: onChanged),
    );
  }
}
```

### Paquete/estrategia para las banderas: NO usar emoji

La propia web ya descartó el emoji de bandera por un motivo documentado en
`src/components/FlagIcon.tsx:3-9`: en Windows con Segoe UI Emoji, 🇻🇪/🇨🇴 caen a texto
plano "VE"/"CO" en vez de dibujar la bandera. El mismo problema existe en Android —
peor incluso: Google **deshabilitó intencionalmente** el renderizado de emoji de
bandera nacional en Noto Color Emoji para Android durante años por motivos de
neutralidad política/geográfica en ciertas regiones, mostrando en su lugar las dos
letras del indicador regional sin combinar en un glifo de bandera. El soporte mejoró
con versiones más recientes de Noto Color Emoji (Emoji 15.0, lanzado como fuente
vectorial a color en septiembre de 2022), pero:
- Depende de la versión del **sistema** (Android ≤ 11/12 no puede actualizar la fuente
  de emoji sin una actualización de firmware — la fuente pesa >10 MB), no de la app.
- Distintos fabricantes (Samsung, Xiaomi, etc.) usan sus propias fuentes de emoji con
  comportamiento inconsistente.
- Incluso en dispositivos donde renderiza, el emoji de bandera no permite controlar
  tamaño/nitidez con precisión en un control tan pequeño como el de la barra superior.

**Recomendación**: igual que hizo la web (`FlagIcon.tsx`), usar **SVG propios**, no
emoji ni un paquete de terceros con cientos de banderas innecesarias (solo hacen falta
2 activas + un ícono genérico para el resto de `AMERICAS_COUNTRIES`, igual que
`CountryIntroModal.tsx:135-141` usa una insignia gris con las dos letras para los
países inactivos). Dos caminos, ambos válidos:

1. **Reusar el mismo diseño**: los SVG de `FlagIcon.tsx` (rectángulos de color puro,
   sin detalle fino) son triviales de portar a assets `.svg` estáticos en
   `assets/flags/ve.svg` / `co.svg`, renderizados con el paquete `flutter_svg`
   (https://pub.dev/packages/flutter_svg). Cero dependencias nuevas de terceros para
   banderas, mismo resultado visual en las dos plataformas — coherencia de marca con
   la web.
2. **Paquete `country_flags`** (https://pub.dev/packages/country_flags, ~133k
   descargas, basado en el proyecto `flag-icons`) si se prefiere no mantener SVG a
   mano: `CountryFlag.fromCountryCode('VE', height: 16, width: 22)`. Sirve sobre todo
   si más adelante se activan más países y no se quiere dibujar cada bandera a mano.

Dado que solo hay 2 países activos hoy y la web ya resolvió el diseño exacto, la
opción 1 (portar los mismos SVG) es la de menor esfuerzo y máxima fidelidad visual;
dejar la puerta abierta a migrar a `country_flags` el día que se activen 5+ países.

---

## 3. Persistencia de la selección de país

La web persiste en **cookie de servidor** (`emb_country`, `country-server.ts:5`,
1 año) porque el filtrado por país ocurre en Server Components/Server Actions que
necesitan saber el país en cada request. Ese mecanismo no aplica a una app Flutter que
habla directo con Supabase desde el cliente (decisión ya tomada en
`01-arquitectura.md:3-16`): no hay "request al servidor" que lea una cookie.

**Equivalente móvil**: la misma idea que ya está decidida para el UUID de dispositivo
(`01-arquitectura.md:26`, "UUID de dispositivo generado una vez, guardado en
`shared_preferences`") — usar `shared_preferences`
(https://pub.dev/packages/shared_preferences) para guardar el código de país elegido,
leído una vez al arrancar la app.

```dart
// lib/core/country/country_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

const _kCountryPrefKey = 'active_country'; // equivalente a COUNTRY_COOKIE, country-server.ts:5

class CountryPrefs {
  static Future<CountryCode?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return CountryCodeX.fromValue(prefs.getString(_kCountryPrefKey));
  }

  /// null = nunca eligió país, equivalente a hasChosenCountry() devolviendo
  /// false (country-server.ts:26-29) — dispara la pantalla de bienvenida.
  static Future<bool> hasChosen() async => (await read()) != null;

  static Future<void> write(CountryCode code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCountryPrefKey, code.value);
  }
}
```

### ¿Auto-detectar por configuración regional del teléfono la primera vez?

La web **no** lo hace hoy (confirmado: no hay `navigator.language` ni lógica de
geolocalización en `CountryIntroModal.tsx`, ni en ningún otro archivo revisado) — el
primer visitante ve siempre la misma grilla de ~26 países y elige a mano. Dos razones
por las que probablemente conviene **mantener el mismo criterio manual en móvil**, no
inventar uno nuevo:

1. **Consistencia de producto**: si la web (superficie con más tráfico hoy) no
   autodetecta, que la app sí lo haga crea una experiencia distinta para el mismo
   usuario en dos plataformas sin que haya sido pedido.
2. **Riesgo de detección equivocada > beneficio de un tap ahorrado**: la configuración
   regional de un teléfono (`PlatformDispatcher.instance.locale.countryCode`, vía
   `WidgetsBinding.instance.platformDispatcher.locale`) no siempre coincide con dónde
   está físicamente la persona (idioma del sistema en inglés, teléfono importado,
   región configurada como EE. UU. por costumbre, etc.) — un venezolano con el
   teléfono en "Estados Unidos" caería en un país sin emergencia activa y vería el
   aviso de "aún no activo aquí" (`CountryIntroModal.tsx:68-107`) en vez de entrar
   directo a ver a sus familiares buscados. Dado que esto es una plataforma de
   personas desaparecidas, el costo de una detección incorrecta es alto.

Si de todos modos se quiere usar la señal solo para **pre-seleccionar** (resaltar) una
opción en la grilla sin auto-confirmarla, `PlatformDispatcher.instance.locale` sí es la
API correcta para leerla (`WidgetsBinding.instance.platformDispatcher.locale.countryCode`),
pero seguiría exigiendo el tap explícito del usuario — no cambia la recomendación
anterior de dejarlo 100% manual como hace la web hoy.

---

## 4. Filtrado por país en las queries Supabase desde Flutter

### Cómo se ve un query real

```dart
final rows = await supabase
    .from('persons')
    .select()
    .eq('country', activeCountry.value) // 've' / 'co' — mismo valor que guarda schema.sql:101
    .eq('is_unidentified', false)
    .order('created_at', ascending: false)
    .range(0, 19);
```

(Referencia de la API: https://supabase.com/docs/reference/dart/eq — `PostgrestFilterBuilder`
encadena `eq`/`match`/`range` antes de ejecutar, el mismo patrón que ya usa
`data.ts:322` en la web: `sb.from("persons").select("*", …).eq("country", q.country ?? "ve")`.)

### ¿Repetir el filtro en cada método del repository, o centralizarlo?

La web **no** centralizó esto — cada función de `data.ts` repite `.eq("country", …)`
a mano (decenas de sitios, ver punto 0). Es una deuda técnica tolerada ahí porque el
país llega como parámetro explícito a cada función y el equipo lo revisa en cada PR.
En Flutter, donde el equipo es más chico y el ritmo es alto ("urgencia"), **conviene
no repetir el mismo error** — el riesgo real es el que ya identifica el propio
enunciado: "olvidarlo en alguna [llamada]" muestra datos de un país en otro, que en una
plataforma de personas desaparecidas es un bug serio (alguien ve resultados del país
equivocado y concluye que no hay información).

Recomendación: **capa de repository fina que fuerza el filtro**, no un interceptor
global del cliente `SupabaseClient` (Supabase Dart no expone un hook de query
middleware limpio para esto — el `PostgrestFilterBuilder` se construye por llamada, no
hay un punto único de intercepción antes de `.from()`). El patrón más simple y difícil
de "olvidar" es un wrapper que **exige** el país como argumento del constructor del
repository, para que sea imposible construir una query sin él:

```dart
// lib/data/country_scoped_query.dart
//
// No es un interceptor mágico (Supabase Dart no lo permite limpiamente),
// es una fachada que hace estructuralmente imposible olvidar el filtro:
// cualquier método del repository recibe el país ya resuelto en el
// constructor, no como argumento opcional en cada llamada (que es
// exactamente el patrón que permitió el descuido en data.ts de la web).
class CountryScopedTable {
  final SupabaseClient _client;
  final String _table;
  final CountryCode country;

  CountryScopedTable(this._client, this._table, this.country);

  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return _client.from(_table).select(columns).eq('country', country.value);
  }
}

// lib/data/persons_repository.dart
class PersonsRepository {
  final CountryScopedTable _persons;
  PersonsRepository(SupabaseClient client, CountryCode country)
      : _persons = CountryScopedTable(client, 'persons', country);

  Future<List<Person>> searched({bool unidentified = false}) async {
    final rows = await _persons
        .select()
        .eq('is_unidentified', unidentified)
        .order('created_at', ascending: false);
    return rows.map(Person.fromRow).toList();
  }
}

// Al cambiar de país (CountryBarControl.onChanged), se reconstruye el
// repository con el nuevo CountryCode — no se "actualiza" un filtro interno,
// se crea una instancia nueva. Con Riverpod/Provider esto es un simple
// provider derivado del país activo:
final activeCountryProvider = StateProvider<CountryCode>((ref) => kDefaultCountry);
final personsRepositoryProvider = Provider<PersonsRepository>((ref) {
  final country = ref.watch(activeCountryProvider);
  return PersonsRepository(Supabase.instance.client, country);
});
```

Con este patrón, cambiar de país invalida automáticamente (vía Riverpod/Provider) todos
los repositories dependientes y dispara un refetch de cada pantalla que los observa —
no hay estado de "país" desincronizado entre pantallas, ni una query que se ejecute sin
`.eq('country', …)` porque el método `select()` de `CountryScopedTable` lo aplica
siempre, en un solo lugar.

---

## 5. Internacionalización de texto (idioma, no país)

Los dos países activos hoy (Venezuela, Colombia) hablan español; toda la web está
100% en español (confirmado: `CLAUDE.md` del repo web: "el idioma del producto y de la
comunicación con el usuario es español"; ningún archivo revisado en `countries.ts`,
`emergency.ts`, ni las páginas tiene texto en otro idioma ni claves de traducción).

**Recomendación honesta: no configurar `flutter_localizations` + ARB todavía.** Razones:

- Cero necesidad hoy: los dos países activos y toda la lista `AMERICAS_COUNTRIES`
  (`countries.ts:327-355`) son de habla hispana (única excepción real sería si algún
  día se activaran EE. UU./Canadá/Haití/Jamaica/Surinam/Trinidad y Tobago — territorio
  hipotético, no una decisión tomada).
- El costo de montar `flutter_localizations` + `intl` + archivos `.arb` +
  `l10n.yaml` + generación de código (ver guía oficial:
  https://docs.flutter.dev/ui/internationalization) es real: cada string pasa de un
  literal a una clave con generación de código, revisión de PR más pesada, y un
  paquete completo (`flutter_localizations`) que agrega peso a la app — todo esto para
  una necesidad que no existe hoy.
- El propio contexto del proyecto pide priorizar "salvar vidas, bien hecho" con 3
  personas y urgencia (`CLAUDE.md`, `03-roadmap.md`) — introducir infraestructura de
  i18n sin un segundo idioma real que mostrar es trabajo especulativo.

**Lo que sí conviene hacer ahora, sin costo**: no concatenar strings de forma que haga
difícil migrar después (ej. evitar `"Hay " + n + " personas"` directo en el widget,
mejor una función `_personsLabel(n)` en un solo archivo de textos) — así, el día que
haga falta un segundo idioma, mover esos strings a `.arb` es mecánico. Esto es
disciplina de código, no infraestructura de i18n.

Cuando llegue el día de necesitarlo de verdad, la ruta estándar queda documentada para
referencia futura: `flutter_localizations` (SDK) + paquete `intl`
(https://pub.dev/packages/intl) + archivos `.arb` por idioma + `flutter gen-l10n`.

---

## 6. Teléfonos de emergencia y regiones por país → pantalla SOS

### Cómo lo usa la web hoy

`src/app/emergencias/page.tsx` (`/emergencias`, uno de los 5 tabs primarios según
`02-contenido-y-navegacion.md:25-26`, mapeado 1:1 a "SOS" en el plan móvil):

- Lee el país activo del lado servidor: `const country = await getActiveCountry();`
  (`emergencias/page.tsx:22`), y con eso obtiene
  `const { nationalLine: NATIONAL_LINE, groups: PHONE_GROUPS } = getEmergency(country);`
  (`emergencias/page.tsx:23`, función definida en `src/lib/emergency.ts:18-20` — un
  simple `getCountry(country).emergency`).
- La página se marca `export const dynamic = "force-dynamic"` (`emergencias/page.tsx:14`)
  precisamente **porque** el teléfono depende del país activo — el comentario en el
  código es explícito: "esta página SÍ necesita leer la cookie de país en cada visita
  […] mostrar el teléfono equivocado en una página de emergencias" sería el peor caso.
- Estructura visual: número grande de la línea nacional con `tel:` directo
  (`emergencias/page.tsx:40-51`), botón de compartir por WhatsApp
  (`ShareWhatsApp`, `:53-61`), acordeón de "otras plataformas" (`RECURSOS`, fuera del
  alcance de país), y luego los `PHONE_GROUPS` — para Venezuela son 2 grupos
  (ambulancias + bomberos por municipio, `countries.ts:194-222`, con nota de que
  "pueden cambiar"); para Colombia hoy es un array vacío `groups: []`
  (`countries.ts:294`, con el comentario "Colombia tiene una línea única nacional, a
  diferencia de VE no hay listado fragmentado todavía") — es decir, **el número de
  grupos por país no es fijo, la UI debe soportar cero grupos sin verse rota**.
- `COMMUNITY_GUIDE` (`emergency.ts:23-33`) es una guía de 9 pasos **fija, no varía
  por país** — mismo texto para VE y CO.
- Las `regions` de `CountryConfig` (`countries.ts:78-139`, los 24 estados de VE / 32
  departamentos de CO) no se usan en `/emergencias`; se usan como opciones de
  formulario al publicar una persona/recurso (selector de estado/departamento) y como
  claves de `regionCoords` para centrar el mapa — la pantalla SOS no necesita las
  regiones en sí, solo `emergency.nationalLine` + `emergency.groups`.

### Cómo se replicaría en la pantalla SOS de Flutter

Con el `CountryConfig` del punto 1 ya resuelto, la pantalla SOS es una lectura directa
sin red — no necesita ningún query a Supabase, porque estos datos viven en código
(igual que en la web):

```dart
class SosScreen extends ConsumerWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(activeCountryProvider);
    final emergency = kCountries[country]!.emergency;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NationalLineCard(
          number: emergency.nationalLine.number,
          label: emergency.nationalLine.label,
          onTap: () => launchUrl(Uri(scheme: 'tel', path: emergency.nationalLine.number)),
        ),
        const ShareWhatsAppButton(),
        // Grupos: 0..N, igual que en la web (CO hoy tiene 0)
        for (final group in emergency.groups) PhoneGroupSection(group: group),
        const CommunityGuideSection(steps: kCommunityGuideEs), // fijo, no por país
      ],
    );
  }
}
```

Puntos a preservar de la web (para no perder decisiones de producto ya tomadas):

1. **`tel:` directo** en el número nacional grande — un solo tap para llamar, sin
   pantalla intermedia (`url_launcher` con `Uri(scheme: 'tel', …)` es el equivalente
   exacto al `href="tel:${NATIONAL_LINE.number}"` de `emergencias/page.tsx:41`).
2. **Compartir por WhatsApp** de la página completa — mismo peso que le da la web
   ("Entre más personas vean esta página, más personas pueden estar a salvo",
   `emergencias/page.tsx:56-57`); en móvil, compartir un deep link a la pantalla SOS
   (o al sitio web si no hay deep link resuelto aún, ver `01-arquitectura.md:28`).
3. **Cero grupos es un estado válido**, no un error — Colombia lo prueba hoy.
4. **Nota de "pueden cambiar"** (`emergencias/page.tsx:172-175`) — mantenerla, es una
   decisión deliberada de la web para no prometer exactitud sobre teléfonos de
   terceros.
5. **La guía de 9 pasos NO depende del país** — un solo archivo Dart con la lista fija,
   sin pasar por `CountryConfig`.

---

## Resumen ejecutivo (para el equipo)

| Pregunta | Respuesta corta |
|---|---|
| ¿Estructura de datos por país? | Un `Map<CountryCode, CountryConfig>` en un solo archivo Dart, espejo de `countries.ts` — mismos campos, mismos valores, portados a mano (son datos, cambian poco). |
| ¿Selector de país? | Bottom sheet con banderas SVG propias (portar `FlagIcon.tsx`), NO emoji — Android tiene el mismo problema de renderizado que ya documentó la web para Windows. |
| ¿Dónde se guarda la elección? | `shared_preferences`, misma librería ya decidida para el UUID de dispositivo. Sin auto-detección por configuración regional — la web tampoco lo hace, y el costo de un error es alto en esta app. |
| ¿Cómo se filtra Supabase por país? | `.eq('country', code.value)` en cada query, pero encapsulado en una capa `CountryScopedTable`/repository que lo hace obligatorio por construcción — NO repetir el patrón manual y propenso a olvidos que hoy tiene `data.ts` en la web. |
| ¿Hace falta `intl`/ARB ya? | No. Todo el proyecto es español hoy; configurarlo ahora es trabajo especulativo. Sí vale evitar concatenar strings de forma que dificulte migrar después. |
| ¿Pantalla SOS? | Lectura directa de `CountryConfig.emergency` (línea nacional + 0..N grupos de teléfonos), sin red — mismo patrón que `emergency.ts`/`emergencias/page.tsx` en la web. |

---

## Fuentes

- [country_flags | Flutter package](https://pub.dev/packages/country_flags)
- [flutter_svg | Flutter package](https://pub.dev/packages/flutter_svg)
- [shared_preferences | Flutter package](https://pub.dev/packages/shared_preferences)
- [intl | Dart package](https://pub.dev/packages/intl)
- [Internationalizing Flutter apps (docs.flutter.dev)](https://docs.flutter.dev/ui/internationalization)
- [Supabase Flutter API Reference — eq()](https://supabase.com/docs/reference/dart/eq)
- [supabase-flutter AGENTS.md (GitHub)](https://github.com/supabase/supabase-flutter/blob/main/AGENTS.md)
- [Noto Color Emoji — Google Fonts](https://fonts.google.com/noto/specimen/Noto+Color+Emoji)
- [Support modern emoji | Android Developers](https://developer.android.com/develop/ui/views/text-and-emoji/emoji2)
