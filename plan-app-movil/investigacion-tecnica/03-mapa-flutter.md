# 03 — Mapa en Flutter: `flutter_map` + tiles CartoDB, marcadores animados, clustering, capas, zonas y offline

> Investigación para el equipo de la app móvil "El Mundo Te Busca". Fuente
> factual del comportamiento web verificada en `C:\Users\angel\Desktop\Elmundotebusca\src\components\map\CrisisMap.tsx`,
> `MapView.tsx` y `src/app/globals.css` (líneas 395-552) el 2026-08-13.
> NO se modificó ningún archivo de los repos de referencia (solo lectura).

---

## 0. Lo que la web hace hoy (verificado en el código, no supuesto)

Archivo: `src/components/map/MapView.tsx`.

```tsx
<TileLayer
  attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
  url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
/>
```

Confirmado: **no es OSM directo, es CartoDB "Voyager"** (raster, vía CDN de
Carto), tal como decía el contexto de la tarea. Punto importante que la
propia atribución del código **no está completa** según las reglas actuales
de Carto (falta el crédito a CARTO, ver §1.3) — algo a corregir también en la
web de paso, aunque no es parte de este encargo.

Otros hechos verificados que cambian el alcance de esta investigación:

- **Las "zonas afectadas" en la web NO son polígonos ni círculos geográficos.**
  Son `Marker` de Leaflet con un `L.divIcon` (`zoneIcon()`, `MapView.tsx:122-131`)
  cuyo tamaño escala con `count` (`Math.sqrt(count)`) y un pulso CSS
  (`.zone-pulse`, `globals.css:409-415`). Es decir: hoy el mapa **no dibuja
  el área del sismo/zona como forma geográfica**, solo un punto pulsante por
  zona con una cifra dentro. `PolygonLayer`/`CircleLayer` (§5) serían una
  **capacidad nueva**, no una réplica de algo que ya exista — útil si el
  equipo quiere sombrear el área afectada más adelante, pero no bloqueante
  para el MVP de paridad con la web.
- El mapa tiene **8 capas activables** vía `LayersControl` de Leaflet (todas
  `checked` por defecto): 🆘 Necesito ayuda, 🤲 Puedo ayudar, 👤 Personas,
  🚨 Rescates, 📦 Puntos de ayuda, 🏥 Hospitales, 🚐 Caravanas, 🔴 Zonas
  afectadas. El epicentro se dibuja siempre (no es una capa togglable).
- Orden de apilado via `zIndexOffset` (más alto = encima): rescates `1000` >
  necesito `600` > puedo-ayudar `500` > personas `400` > el resto sin offset
  explícito (orden de inserción).
- Tres animaciones CSS distintas por tipo de marcador (`globals.css:400-551`),
  con sus keyframes exactos — necesarios para replicar el "look" en Flutter:

  | Marcador | Animación | Duración | Detalle |
  |---|---|---|---|
  | Zona afectada | 1 anillo que crece y se desvanece | `2.4s ease-out infinite` | `scale(0.85)→scale(2.2)`, opacidad `0.8→0` |
  | Rescate urgente | 2 anillos rojos desfasados | `1.4s ease-out infinite`, 2º con `delay: 0.7s` | `scale(0.7)→scale(2.6)`, opacidad `0.9→0` |
  | Epicentro | anillo concéntrico fijo | `2.6s ease-out infinite` | `scale(0.6)→scale(2.4)`, opacidad `0.9→0` |

  Pines normales (`pin-marker`, puntos de ayuda/caravana/necesito/ayudo/persona)
  **no** tienen animación: son un pin de gota (`border-radius` asimétrico +
  `rotate(45deg)`) con color sólido por categoría, coincide con los colores
  que ya tenía el plan: ayuda `#f59e0b`, caravana `#0ea5e9`, necesito
  `#e11d48`, puedo-ayudar `#059669`, persona `#8b5cf6`.

---

## 1. Setup de `flutter_map` con tiles de CartoDB

### 1.1 TileLayer — mismo estilo exacto que la web (Voyager)

`flutter_map` (paquete `fleaflet.dev`, versión estable actual **8.3.1**, API
`MapOptions(initialCenter:, initialZoom:)` desde la v6) usa el mismo patrón de
URL con placeholders que Leaflet:

```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

FlutterMap(
  options: const MapOptions(
    initialCenter: LatLng(10.5, -66.9), // mismo centro que usa CrisisMap hoy
    initialZoom: 9,
  ),
  children: [
    TileLayer(
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      retinaMode: RetinaMode.isHighDensity(context), // resuelve el {r} -> @2x
      maxZoom: 20,
      userAgentPackageName: 'com.elmundotebusca.app', // requerido por flutter_map
    ),
    RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
        ),
        TextSourceAttribution(
          'CARTO',
          onTap: () => launchUrl(Uri.parse('https://carto.com/attributions')),
        ),
      ],
    ),
  ],
)
```

Otras variantes de Carto disponibles con el mismo esquema de URL (por si se
quiere un estilo "claro" en vez de Voyager, p.ej. para modo día/noche):
Positron = `light_all`, Dark Matter = `dark_all`, Voyager = `rastertiles/voyager`
— confirmado contra la configuración de `leaflet-providers`
(`https://{s}.basemaps.cartocdn.com/{variant}/{z}/{x}/{y}{r}.png`).

### 1.2 `userAgentPackageName`

`flutter_map` **exige** este parámetro desde v6 (antes era opcional) porque
muchos proveedores de tiles bloquean requests sin User-Agent identificable.
Usar el `applicationId` real de la app (ej. `com.elmundotebusca.app`).

### 1.3 Atribución obligatoria

Carto exige **dos créditos**, no solo OpenStreetMap (la web hoy solo pone el
de OSM — están incumpliendo la letra de la regla de Carto, aunque es un
descuido común): `© OpenStreetMap contributors © CARTO`
(enlace a `https://carto.com/attributions`). En `flutter_map`, el widget
`RichAttributionWidget` (ejemplo arriba) es el patrón recomendado: se puede
dejar colapsado en una esquina y expandir al tocar, igual que el control de
Leaflet en la web.

### 1.4 Licenciamiento real de los tiles de Carto — hallazgo importante, hay que decidir con el equipo

Esto merece atención porque **no es solo un detalle técnico**, es un riesgo
de producto para una plataforma que ya está en producción y con visibilidad
pública (comentarios hostiles en FB, según la nota de sesiones anteriores).

Investigando la documentación oficial actual de Carto (`docs.carto.com/faqs/carto-basemaps`,
`carto.com/basemaps`, 2026):

> "CARTO Basemaps are available exclusively with an Enterprise license" para
> uso comercial. Uso gratuito está limitado a **CARTO grantees** (programa de
> donación/sin fines de lucro) para aplicaciones no comerciales.

Esto se refiere sobre todo a su oferta **nueva** de basemaps vectoriales GL
(`basemaps.cartocdn.com/gl/voyager-gl-style/style.json`, requiere API key).
La URL que **la web ya usa hoy** (`{s}.basemaps.cartocdn.com/rastertiles/voyager/...`)
es el **CDN raster "legacy"** — el mismo que listan `leaflet-providers` y que
usan miles de proyectos OSS desde hace años sin API key ni cuenta. Carto no
lo ha cortado, pero **tampoco publica hoy un límite gratuito explícito para
ese endpoint legacy** (un límite de "75.000 map views/mes" que circula en
foros viene de un issue de GitHub de 2017, desactualizado y no confiable
para 2026).

**Conclusión honesta, no la descarto porque ya está "decidida":**
- Es razonable **seguir usando el mismo endpoint que ya usa la web** para
  el MVP de la app — consistencia visual total y cero fricción de desarrollo.
- Pero **vale la pena que el equipo, no solo revise esto para la app, sino
  también para la web ya en producción**: como plataforma humanitaria sin
  fines de lucro, probablemente califican para el programa de donación de
  Carto (grantees) — vale la pena solicitarlo formalmente en vez de
  depender de un endpoint legacy sin garantía escrita de continuidad.
- Ventaja concreta de `flutter_map`: **cambiar de proveedor de tiles es
  literalmente cambiar un string** (`urlTemplate`), no hay vendor lock-in de
  arquitectura. Si Carto alguna vez limita o corta el endpoint legacy, el
  reemplazo (MapTiler tiene un estilo "voyager-like" en su free tier con
  atribución, o Stadia Maps con estilos OSM Bright/Alidade, ambos con planes
  gratuitos para bajo tráfico) es un cambio de una línea, no una migración.
- Acción concreta sugerida (no bloqueante para empezar a construir): alguien
  del equipo debería escribirle a Carto o revisar su formulario de "for
  good"/nonprofit antes del lanzamiento público de la app, igual que
  correspondería revisarlo para la web.

---

## 2. Marcadores custom animados

`flutter_map` no trae animación de marcador nativa — el paquete de la propia
organización `fleaflet` para esto es **`flutter_map_animations`** (MIT,
compatible con `flutter_map ^8.3.0`, v0.10.0 es la última). Da
`AnimatedMarkerLayer` + `AnimatedMarker`, que envuelve un `AnimationController`
repetido (`..repeat()`) y reconstruye el marcador con el valor de la animación.

### 2.1 Pulso de "zona afectada" (1 anillo, `2.4s ease-out infinite`)

```dart
class ZonePulseMarker extends StatefulWidget {
  const ZonePulseMarker({super.key, required this.count});
  final int count;

  @override
  State<ZonePulseMarker> createState() => _ZonePulseMarkerState();
}

class _ZonePulseMarkerState extends State<ZonePulseMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = (24 + math.sqrt(widget.count) * 6).clamp(28, 72).toDouble();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // easeOut manual: réplica de la curva CSS ease-out sobre 0..1
        final t = Curves.easeOut.transform(_c.value);
        final scale = 0.85 + t * (2.2 - 0.85);
        final opacity = (1 - t).clamp(0.0, 1.0) * 0.8;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x59F43F5E), // rgba(244,63,94,.35)
                  ),
                ),
              ),
            ),
            Container(
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xE6E11D48), // rgba(225,29,72,.9)
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 1))],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.count > 999 ? '${(widget.count / 1000).round()}k' : '${widget.count}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        );
      },
    );
  }
}
```

Uso dentro de `MarkerLayer` (no necesita `flutter_map_animations` porque el
`AnimationController` vive en el propio widget del marcador — patrón más
simple y suficiente aquí):

```dart
MarkerLayer(
  markers: zones.map((z) => Marker(
    point: LatLng(z.lat, z.lng),
    width: 72, height: 72,
    child: ZonePulseMarker(count: z.count),
  )).toList(),
)
```

### 2.2 Rescate urgente (doble anillo desfasado 0.7s, `1.4s`)

Mismo patrón, con **dos** `Transform.scale` dentro del `AnimatedBuilder`,
uno leyendo `_c.value` directo y el otro leyendo `(_c.value + 0.5) % 1.0`
(el equivalente a "delay: 0.7s" sobre un ciclo de 1.4s = medio ciclo):

```dart
Widget _ring(double t) {
  final tt = Curves.easeOut.transform(t);
  return Transform.scale(
    scale: 0.7 + tt * (2.6 - 0.7),
    child: Opacity(
      opacity: (1 - tt) * 0.9,
      child: Container(
        width: 38, height: 38,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x73DC2626)),
      ),
    ),
  );
}
// dentro del builder:
Stack(alignment: Alignment.center, children: [
  _ring(_c.value),
  _ring((_c.value + 0.5) % 1.0), // delay de medio ciclo == 0.7s sobre 1.4s
  Container(
    width: 26, height: 26,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: const Color(0xFFDC2626),
      border: Border.all(color: Colors.white, width: 2),
    ),
    alignment: Alignment.center,
    child: const Text('🚨', style: TextStyle(fontSize: 13)),
  ),
])
```

### 2.3 Epicentro (anillo concéntrico fijo, `2.6s`)

Mismo patrón de `_ring` con duración `2600ms`, `scale(0.6)→scale(2.4)`,
`opacity(0.9)→0`, borde en vez de relleno (`Border.all(color: Color(0x997C2D12), width: 2)`
sobre un círculo transparente) y el símbolo `⊕` centrado sin fondo. El
epicentro **no** es togglable en la web (siempre visible) — mantener esa
decisión en la app evita que alguien lo oculte sin querer en una emergencia.

### 2.4 Pines simples (sin animación) — puntos de ayuda, caravana, necesito, ayudo, persona

No necesitan `AnimationController`. Basta un `Marker` con un widget "pin de
gota": `Transform.rotate(angle: pi/4)` sobre un contenedor con
`borderRadius` asimétrico (círculo con una esquina recta), y el emoji
contrarrotado adentro — réplica directa de `.pin-marker` / `.pin-marker > span`
de `globals.css:446-460`. Colores exactos ya confirmados en el código web:
`aid #f59e0b`, `march #0ea5e9`, `need #e11d48`, `help #059669`, `person #8b5cf6`.

> Nota de rendimiento: `AnimationController` por marcador (2.1–2.3) es
> aceptable porque **solo las zonas, rescates y el epicentro** animan — son
> pocos elementos (zonas = un puñado; rescates = urgencias activas, no
> cientos). Los pines simples (§2.4, potencialmente cientos) son estáticos
> a propósito, igual que en la web.

---

## 3. Clustering / rendimiento con muchos puntos

Para las capas que sí pueden crecer a cientos de elementos (puntos de ayuda,
personas, "necesito"/"puedo ayudar"), el paquete de referencia es
**`flutter_map_marker_cluster`** (o su fork actualizado
**`flutter_map_marker_cluster_plus`**, compatible con `flutter_map` v8) —
puerto directo de `Leaflet.markercluster`, que es justo la librería que
inspira el patrón visual ya usado en la web.

```dart
MarkerClusterLayerWidget(
  options: MarkerClusterLayerOptions(
    maxClusterRadius: 45,
    size: const Size(40, 40),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(50),
    maxZoom: 15,
    markers: aidPointMarkers, // List<Marker>
    builder: (context, markers) => Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF59E0B), // mismo color que .pin-aid
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '${markers.length}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ),
  ),
)
```

### 3.1 Recomendación de uso — no aplicar a todo por igual

- **Sí clusterizar**: puntos de ayuda, "necesito ayuda", "puedo ayudar",
  personas vistas — son las capas que en un desastre real pueden acumular
  cientos de entradas en zonas urbanas densas.
- **No clusterizar**: hospitales (decenas, no cientos, y cada uno importa
  individualmente para triage), caravanas (pocas), rescates urgentes
  (agrupar un `🚨` en un cluster genérico sería contraproducente — el
  usuario necesita ver cada rescate activo, no un número), epicentro (uno
  solo).
- Rendimiento en gama media: el propio README del paquete no publica
  benchmarks, pero el patrón (spatial index + solo renderizar clusters
  visibles en el viewport actual) es el mismo que usa `Leaflet.markercluster`
  en la web — que hoy ya maneja los mismos volúmenes sin problema en
  navegadores móviles de gama media. Con cientos (no miles) de puntos por
  país, clustering + `MarkerLayer` normal (sin cluster) para las capas
  pequeñas debería ir fluido incluso en un teléfono de gama baja/media; la
  recomendación real de rendimiento es **paginar/filtrar por país y por
  viewport en la consulta a Supabase** (no traer todo el país de una vez),
  más que optimizar el renderer del mapa.

---

## 4. Capas activables/desactivables con Riverpod

Patrón recomendado (y el más simple que replica el `LayersControl` de
Leaflet): un `StateNotifier`/`Notifier` de Riverpod con un `Set<MapLayerKind>`
o un mapa `Map<MapLayerKind, bool>` de visibilidad, y el `FlutterMap` arma su
lista de `children` **condicionalmente** en el `build`, respetando el mismo
orden de apilado que hoy da `zIndexOffset` en la web (el último `children`
en la lista queda **encima** en `flutter_map`, igual que en Leaflet con
z-index más alto):

```dart
enum MapLayerKind { need, help, person, rescue, aid, hospital, march, zone }

final visibleLayersProvider =
    NotifierProvider<VisibleLayersNotifier, Set<MapLayerKind>>(VisibleLayersNotifier.new);

class VisibleLayersNotifier extends Notifier<Set<MapLayerKind>> {
  @override
  Set<MapLayerKind> build() => MapLayerKind.values.toSet(); // todas activas por defecto, igual que la web

  void toggle(MapLayerKind kind) {
    state = state.contains(kind)
        ? {...state}..remove(kind)
        : {...state, kind};
  }
}
```

```dart
class CrisisMap extends ConsumerWidget {
  const CrisisMap({super.key, required this.data});
  final CrisisMapData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(visibleLayersProvider);
    return FlutterMap(
      options: const MapOptions(initialCenter: LatLng(10.5, -66.9), initialZoom: 9),
      children: [
        TileLayer(urlTemplate: cartoVoyagerUrl, subdomains: const ['a','b','c','d']),
        // Orden ascendente de "encima" — mismo criterio que zIndexOffset en la web:
        if (visible.contains(MapLayerKind.zone)) zoneMarkerLayer(data.zones),
        if (visible.contains(MapLayerKind.march)) MarkerLayer(markers: marchMarkers(data.marches)),
        if (visible.contains(MapLayerKind.hospital)) MarkerLayer(markers: hospitalMarkers(data.hospitals)),
        if (visible.contains(MapLayerKind.aid)) MarkerClusterLayerWidget(options: aidClusterOptions(data.aidPoints)),
        if (visible.contains(MapLayerKind.person)) MarkerLayer(markers: personMarkers(data.persons)),
        if (visible.contains(MapLayerKind.help)) MarkerClusterLayerWidget(options: helpClusterOptions(data.helps)),
        if (visible.contains(MapLayerKind.need)) MarkerClusterLayerWidget(options: needClusterOptions(data.needs)),
        if (visible.contains(MapLayerKind.rescue)) rescueMarkerLayer(data.rescues),
        epicenterMarkerLayer(data.epicenter), // siempre visible, sin toggle — igual que la web
        const RichAttributionWidget(attributions: [/* ... */]),
      ],
    );
  }
}
```

El panel de control (equivalente al `LayersControl` colapsable de Leaflet)
es un `BottomSheet` o `Drawer` con un `CheckboxListTile` por
`MapLayerKind`, cada uno llamando a `ref.read(visibleLayersProvider.notifier).toggle(kind)`
— más nativo en móvil que el control flotante de Leaflet, y evita el
problema que tuvo la web con el control nativo de Leaflet (`MapView.tsx:16-44`,
tuvieron que reescribir a mano el manejador de clic porque el control
nativo de Leaflet no soporta abrir/cerrar con clic de forma consistente).
En Flutter este problema no existe porque el panel es un widget propio, no
un control de terceros.

---

## 5. Zonas afectadas (polígonos) y epicentro

Como se estableció en §0, **la web hoy no dibuja polígonos de zona** — solo
puntos pulsantes. Si el equipo quiere agregar esa capacidad (sombrear el
área realmente afectada, no solo un punto por ciudad), el equivalente en
`flutter_map` es directo:

```dart
PolygonLayer(
  polygons: [
    Polygon(
      points: affectedAreaCoords, // List<LatLng> del polígono
      color: const Color(0x33E11D48), // relleno translúcido, mismo rosa/rojo de marca
      borderColor: const Color(0xFFE11D48),
      borderStrokeWidth: 2,
    ),
  ],
)
```

Para un círculo simple (p. ej. "radio estimado de daño" alrededor del
epicentro en vez de un polígono con forma real), `CircleLayer` +
`CircleMarker` con `useRadiusInMeter: true` da el radio en metros reales
(no píxeles, así el círculo escala correctamente al hacer zoom):

```dart
CircleLayer(
  circles: [
    CircleMarker(
      point: epicenter,
      radius: 15000, // metros
      useRadiusInMeter: true,
      color: const Color(0x1A7C2D12),
      borderColor: const Color(0x997C2D12),
      borderStrokeWidth: 2,
    ),
  ],
)
```

Recomendación: tratarlo como **mejora futura, no MVP** — requiere que
alguien defina y mantenga la geometría real del área afectada (no es un dato
que hoy exista en `supabase/schema.sql`), mientras que el punto pulsante por
zona ya cubre la necesidad actual ("¿cuánta gente hay registrada aquí?") sin
depender de geometría adicional.

---

## 6. Offline / mala señal — nota breve, no requisito de Fase 1

`flutter_map` trae **caché de tiles en disco integrada desde la v8.2**
(activada por defecto, sin dependencias extra) — cualquier tile ya visto
queda cacheado localmente sin que el equipo tenga que hacer nada. Esto ya
cubre el caso más común de "conectividad intermitente": si alguien ya abrió
el mapa de su zona una vez con señal, verlo de nuevo sin señal (mismo
viewport) debería funcionar solo.

Para algo más ambicioso — descargar de antemano toda una región para uso
100% offline — existe **`flutter_map_tile_caching`** (FMTC), con
descarga masiva por región y gestión avanzada de caché. Dos cosas a
considerar antes de adoptarlo:

- **Licencia GPL** — puede ser un problema según cómo se vaya a licenciar o
  distribuir la app; toca revisarlo con quien lleve esa decisión antes de
  incorporarlo, no asumir que es un "más" gratis.
- Alternativa más liviana y con licencia MIT: `flutter_map_cache` (más
  simple, sin descarga masiva por región, pero suficiente para "cachear lo
  que ya se vio").

**Evaluación honesta para la Fase 1**: no vale la pena todavía. La caché
integrada de `flutter_map` (v8.2+) ya resuelve el 80% del problema real
("perdí señal pero ya había cargado el mapa") sin ninguna dependencia
nueva. Descarga proactiva de región completa (FMTC) es una funcionalidad de
"modo antes de salir a zona sin señal" — útil, pero es una historia de
usuario específica que puede esperar a una fase posterior, no bloqueante
para el lanzamiento.

**Distinción importante con la regla de "no cachear estado como si fuera
actual"** (`01-arquitectura.md`, sección final): esa regla aplica a **datos
de entidades** (¿esta persona sigue desaparecida? ¿este punto de ayuda sigue
teniendo insumos?) — mostrar eso desactualizado sin avisar es peligroso.
Cachear **tiles del mapa base** (el fondo visual, calles/edificios) es un
caso completamente distinto: no representa "estado actual de una crisis",
es solo cartografía de base que casi nunca cambia. No hay conflicto entre
cachear tiles y la regla de no fingir frescura de datos de personas/recursos
— son capas independientes (fondo del mapa vs. marcadores encima) y deben
tratarse con criterios distintos.

---

## Resumen ejecutivo (para quien no lea todo)

1. **Tiles**: usar el mismo `https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png`
   que ya usa la web, con `RichAttributionWidget` mostrando OSM **y** CARTO
   (la web hoy solo atribuye a OSM, falta el crédito de Carto). Investigar en
   paralelo el programa de donación/nonprofit de Carto — la letra chica
   actual de Carto pide licencia Enterprise para uso comercial y no publica
   garantía escrita para el endpoint legacy que se está usando gratis.
2. **Marcadores animados**: no hace falta un paquete pesado — un
   `AnimationController` por marcador (zona, rescate, epicentro) alcanza y
   es exactamente lo que la web hace con CSS, con los mismos tiempos/curvas.
3. **Clustering**: `flutter_map_marker_cluster` (o `_plus`) para
   ayuda/necesito/puedo-ayudar/personas; hospitales, caravanas, rescates y
   epicentro **sin** clusterizar, por importancia individual.
4. **Capas**: `Set<MapLayerKind>` en un `Notifier` de Riverpod +
   `children` condicionales en `FlutterMap`, con un panel propio (más
   confiable que el control nativo de Leaflet, que ya dio problemas en la
   web).
5. **Polígonos de zona/epicentro**: no existen hoy en la web (son puntos
   pulsantes) — `PolygonLayer`/`CircleLayer` quedan documentados como mejora
   futura opcional, no como paridad requerida.
6. **Offline**: la caché de tiles integrada de `flutter_map` (v8.2+) ya
   alcanza para la Fase 1; FMTC (descarga proactiva por región) es prematuro
   y además GPL — evaluarlo más adelante si de verdad hace falta.

---

## Fuentes

- [flutter_map — pub.dev](https://pub.dev/packages/flutter_map)
- [flutter_map docs — Tile Layer / Offline Mapping](https://docs.fleaflet.dev/tile-servers/offline-mapping)
- [flutter_map docs — Caching](https://docs.fleaflet.dev/layers/tile-layer/caching)
- [flutter_map docs — Polygon Layer](https://docs.fleaflet.dev/layers/polygon-layer)
- [flutter_map docs — Layer Interactivity](https://docs.fleaflet.dev/layers/layer-interactivity)
- [CircleLayer class — pub.dev API docs](https://pub.dev/documentation/flutter_map/latest/flutter_map/CircleLayer-class.html)
- [CircleMarker class — pub.dev API docs](https://pub.dev/documentation/flutter_map/latest/flutter_map/CircleMarker-class.html)
- [flutter_map/example/lib/pages/circle.dart — GitHub](https://github.com/fleaflet/flutter_map/blob/master/example/lib/pages/circle.dart)
- [flutter_map_animations — pub.dev](https://pub.dev/packages/flutter_map_animations)
- [flutter_map_marker_cluster — pub.dev](https://pub.dev/packages/flutter_map_marker_cluster)
- [flutter_map_marker_cluster_plus — pub.dev](https://pub.dev/packages/flutter_map_marker_cluster_plus)
- [lpongetti/flutter_map_marker_cluster — GitHub](https://github.com/lpongetti/flutter_map_marker_cluster)
- [flutter_map_tile_caching — pub.dev](https://pub.dev/packages/flutter_map_tile_caching)
- [flutter_map_cache — pub.dev](https://pub.dev/packages/flutter_map_cache)
- [CARTO Basemaps FAQ — docs.carto.com](https://docs.carto.com/faqs/carto-basemaps)
- [Basemaps — carto.com](https://carto.com/basemaps/)
- [CARTO Basemaps guide — docs.carto.com (CARTO for React)](https://docs.carto.com/carto-for-developers/carto-for-react/guides/basemaps)
- [CartoDB/basemap-styles — GitHub](https://github.com/cartodb/basemap-styles)
- [leaflet-providers.js (configuración de CartoDB) — GitHub, leaflet-extras](https://raw.githubusercontent.com/leaflet-extras/leaflet-providers/master/leaflet-providers.js)

### Archivos verificados en el repo web (solo lectura, sin modificar)
- `C:\Users\angel\Desktop\Elmundotebusca\src\components\map\CrisisMap.tsx`
- `C:\Users\angel\Desktop\Elmundotebusca\src\components\map\MapView.tsx`
- `C:\Users\angel\Desktop\Elmundotebusca\src\app\globals.css` (líneas 395-552: `.zone-marker`, `.pin-marker`, `.rescue-marker`, `.epicenter-marker` y sus `@keyframes`)
