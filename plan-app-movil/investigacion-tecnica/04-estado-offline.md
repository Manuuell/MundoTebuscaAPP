# 04 — Riverpod + Supabase (Fase 1, MVP) y cache offline (Fase 4, NO MVP)

> Investigación de apoyo a [`01-arquitectura.md`](../../../../../../../../Desktop/MundoTebuscaAPP/plan-app-movil/01-arquitectura.md)
> y [`03-roadmap.md`](../../../../../../../../Desktop/MundoTebuscaAPP/plan-app-movil/03-roadmap.md) del plan móvil.
> No modifica ningún repo existente. Todo el código Dart de abajo es ilustrativo
> (greenfield: el repo Flutter aún no existe).

---

## Resumen ejecutivo

- **Frente 1 (Riverpod + repositories) es del MVP de Fase 1**, no opcional: sin
  esto no hay ni siquiera "solo lectura" (roadmap Fase 1).
- **Frente 2 (cache offline con aviso de antigüedad) es de Fase 4.** Se
  investiga ahora para no bloquear decisiones de esquema más adelante, pero
  **no debe implementarse ni empezar a instalarse en Fase 1/2/3.**
- Paquete recomendado para el cache offline: **Drift** (no Isar — abandonado
  por su autor desde enero 2025; no Hive puro — sin mantenimiento, aunque su
  fork `hive_ce` sí sigue vivo). Ver sección 4 para la justificación completa.
- La estrategia de sincronización recomendada para Fase 4 es **deliberadamente
  simple** (refetch completo al reconectar, sin outbox ni resolución de
  conflictos) porque la web **ya decidió no tener escritura offline** — ver la
  "Nota de consistencia" en `01-arquitectura.md`. Construir sync incremental
  con conflictos sería sobre-ingeniería para lo que este proyecto necesita.

---

## FRENTE 1 — Riverpod + repositories (Fase 1, MVP)

### 1. Repository pattern con `riverpod_generator` sobre `supabase_flutter`

**Patrón recomendado 2025-2026:** usar `riverpod_generator` (anotación
`@riverpod`) en vez de providers manuales (`Provider`, `FutureProvider`,
`StateNotifierProvider` escritos a mano). Motivo, según la documentación
oficial y la comunidad: con codegen, Riverpod infiere `autoDispose` y
`family` automáticamente a partir de la firma de la función/clase, evita el
boilerplate de declarar `Ref<T>` por tipo de provider (unificado en Riverpod
3.0 a un solo `Ref`), y es la vía que el propio equipo de Riverpod señala
como "a prueba de futuro" (la documentación oficial dice literalmente que
cuando exista metaprogramación real en Dart, codegen pasará a ser el default).
Riverpod 3.0 (septiembre 2025) además trae reintentos automáticos y
regeneración de notifiers, relevante para una app que va a tener mala señal
en zona de desastre.

Para un proyecto de 3 personas construido con urgencia, la recomendación
encontrada en varias fuentes (Riverpod + repository pattern) es **no crear
una interfaz `abstract class PersonRepository` con múltiples implementaciones**
— es sobre-ingeniería para un equipo chico con un solo backend (Supabase).
Basta una clase concreta inyectada por provider; si algún día hace falta un
mock para tests, se sustituye el provider con `overrideWith` en el test, no
hace falta abstracción previa.

**Ejemplo: `PersonRepository`**, réplica directa (sin la rama de memoria, que
no aplica en producción) de `getPersons`/`getPersonById` de
`src/lib/data.ts:316-390` del repo web:

```dart
// lib/data/models/person.dart
class Person {
  final String id;
  final String country;
  final String firstName;
  final String lastName;
  final String? cedula;
  final int? age;
  final String? gender;
  final String? estado;
  final String locationText;
  final double? lat;
  final double? lng;
  final String description;
  final String? photoUrl;
  final String status; // por_localizar | localizado | hospitalizado | fallecido
  final bool isUnidentified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Person({
    required this.id,
    required this.country,
    required this.firstName,
    required this.lastName,
    this.cedula,
    this.age,
    this.gender,
    this.estado,
    required this.locationText,
    this.lat,
    this.lng,
    required this.description,
    this.photoUrl,
    required this.status,
    required this.isUnidentified,
    required this.createdAt,
    required this.updatedAt,
  });

  // Mapeador fila Supabase (snake_case) -> dominio (camelCase),
  // equivalente a `rowToPerson` en src/lib/data.ts:192-222.
  factory Person.fromRow(Map<String, dynamic> row) {
    return Person(
      id: row['id'] as String,
      country: (row['country'] as String?) ?? 've',
      firstName: row['first_name'] as String,
      lastName: (row['last_name'] as String?) ?? '',
      cedula: row['cedula'] as String?,
      age: row['age'] as int?,
      gender: row['gender'] as String?,
      estado: row['estado'] as String?,
      locationText: (row['location_text'] as String?) ?? '',
      lat: (row['lat'] as num?)?.toDouble(),
      lng: (row['lng'] as num?)?.toDouble(),
      description: (row['description'] as String?) ?? '',
      photoUrl: row['photo_url'] as String?,
      status: row['status'] as String,
      isUnidentified: (row['is_unidentified'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

// lib/data/models/person_query.dart
class PersonQuery {
  final String country;
  final String? search;
  final String status; // 'all' | 'por_localizar' | ...
  final bool excludeUnidentified;
  final bool unidentifiedOnly;
  final String sort; // 'recent' | 'name' | 'estado'
  final int page;
  final int pageSize;

  const PersonQuery({
    this.country = 've',
    this.search,
    this.status = 'all',
    this.excludeUnidentified = false,
    this.unidentifiedOnly = false,
    this.sort = 'recent',
    this.page = 1,
    this.pageSize = 24,
  });

  PersonQuery copyWith({int? page, int? pageSize}) => PersonQuery(
        country: country,
        search: search,
        status: status,
        excludeUnidentified: excludeUnidentified,
        unidentifiedOnly: unidentifiedOnly,
        sort: sort,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );

  // Clave estable para deduplicar/cachear (usada también en Frente 2).
  String get cacheKey =>
      'persons|$country|$status|$excludeUnidentified|$unidentifiedOnly|$sort';
}

class PersonPage {
  final List<Person> items;
  final int total;
  final int page;
  final int pageSize;
  const PersonPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  bool get hasMore => page * pageSize < total;
}
```

```dart
// lib/data/repositories/person_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Excepción de dominio: la UI/los providers reaccionan a esto,
/// no a PostgrestException/AuthException directamente.
class RepositoryException implements Exception {
  final String message;
  final Object? cause;
  RepositoryException(this.message, [this.cause]);
  @override
  String toString() => 'RepositoryException: $message';
}

class PersonRepository {
  PersonRepository(this._client);
  final SupabaseClient _client;

  /// Equivalente a getPersons() en src/lib/data.ts:316-382
  /// (sin la rama de memoria; aquí Supabase es la única fuente).
  Future<PersonPage> getPersons(PersonQuery q) async {
    try {
      var query = _client
          .from('persons')
          .select('*', const FetchOptions(count: CountOption.exact))
          .eq('country', q.country);

      if (q.excludeUnidentified) {
        query = query.eq('is_unidentified', false);
      }
      if (q.unidentifiedOnly) {
        query = query.eq('is_unidentified', true);
      }
      if (q.status != 'all') {
        query = query.eq('status', q.status);
      }
      if (q.search != null && q.search!.trim().isNotEmpty) {
        // Igual que la web (textSearch sobre search_doc), full-text en Postgres.
        query = query.textSearch('search_doc', q.search!.trim(),
            config: 'spanish');
      }

      final from = (q.page - 1) * q.pageSize;
      final to = from + q.pageSize - 1;

      final orderedQuery = switch (q.sort) {
        'name' => query.order('first_name', ascending: true),
        'estado' => query.order('estado', ascending: true),
        _ => query.order('created_at', ascending: false),
      };

      final res = await orderedQuery.range(from, to);
      // supabase_flutter v2: PostgrestResponse expone .count cuando se pidió.
      final rows = res as List<dynamic>;
      return PersonPage(
        items: rows.map((r) => Person.fromRow(r as Map<String, dynamic>)).toList(),
        total: rows.length, // ver nota abajo sobre `.count()`
        page: q.page,
        pageSize: q.pageSize,
      );
    } on PostgrestException catch (e) {
      throw RepositoryException('No se pudo cargar la lista de personas', e);
    } on AuthException catch (e) {
      throw RepositoryException('Sesión inválida', e);
    } catch (e) {
      // Errores de red (SocketException, TimeoutException, etc.)
      throw RepositoryException('Sin conexión o error inesperado', e);
    }
  }

  /// Equivalente a getPersonById() en src/lib/data.ts:384-390
  Future<Person?> getPersonById(String id) async {
    try {
      final row =
          await _client.from('persons').select('*').eq('id', id).maybeSingle();
      return row == null ? null : Person.fromRow(row);
    } on PostgrestException catch (e) {
      throw RepositoryException('No se pudo cargar la persona', e);
    }
  }
}
```

> **Nota honesta sobre el snippet de `getPersons`:** la API exacta de conteo
> (`count: CountOption.exact` + leer `res.count`) cambió entre versiones de
> `supabase_flutter`/`postgrest-dart` (v1 vs v2). Verificar contra la versión
> fijada en `pubspec.yaml` al implementar — el patrón (filtros condicionales
> encadenados, `.range()` para paginar, `.order()` según `sort`) es lo estable
> y lo que importa replicar de `src/lib/data.ts`.

**Manejo de errores — regla concreta:** el repository nunca deja escapar
`PostgrestException`/`AuthException`/excepciones de socket crudas hacia la UI;
las traduce a `RepositoryException` con un mensaje en español ya listo para
mostrar. Los providers (abajo) exponen eso vía `AsyncValue.error`, y la UI solo
necesita manejar `AsyncValue.when(data:, error:, loading:)` — nunca un tipo de
excepción de Supabase.

### 2. Árbol de providers para listas paginadas/filtradas

La web pagina en servidor y filtra por `status`/`estado`/`search` en
`/se-busca` (`PersonQuery` + `getPersons` de `data.ts`). El equivalente
Riverpod recomendado —confirmado por búsqueda: **Riverpod no trae paginación
"de fábrica"** (issue abierto en el repo oficial, discusión #2763 sobre
`AsyncNotifierProvider` + paginación) así que el patrón manual con
`family` + `AsyncNotifier` es lo esperado, no una carencia del proyecto:

```dart
// lib/providers/person_providers.dart
part 'person_providers.g.dart';

@riverpod
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;

@riverpod
PersonRepository personRepository(Ref ref) =>
    PersonRepository(ref.watch(supabaseClientProvider));

/// Filtros activos en la pantalla "Se busca" (sin `page`: la paginación
/// la gestiona el notifier de abajo, no el estado de filtros).
@riverpod
class SeBuscaFilters extends _$SeBuscaFilters {
  @override
  PersonQuery build() => const PersonQuery(excludeUnidentified: true);

  void setStatus(String status) => state = state.copyWith(page: 1);
  void setSearch(String? search) =>
      state = PersonQuery(
        country: state.country,
        search: search,
        status: state.status,
        excludeUnidentified: state.excludeUnidentified,
        sort: state.sort,
      );
}

/// Family: una instancia de notifier por combinación de filtros
/// (misma idea que "family providers" para claves de query).
@riverpod
class PersonSearchNotifier extends _$PersonSearchNotifier {
  static const _pageSize = 24;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<Person>> build(PersonQuery query) async {
    _page = 1;
    _hasMore = true;
    final repo = ref.watch(personRepositoryProvider);
    final result = await repo.getPersons(query.copyWith(page: 1, pageSize: _pageSize));
    _hasMore = result.hasMore;
    return result.items;
  }

  /// "Cargar más" (scroll infinito). No reemplaza `state` con loading global
  /// -- así la lista ya visible no parpadea mientras llega la página siguiente.
  Future<void> loadNextPage() async {
    if (_isLoadingMore || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null) return;
    _isLoadingMore = true;
    try {
      final repo = ref.read(personRepositoryProvider);
      final nextPage = _page + 1;
      final result =
          await repo.getPersons(query.copyWith(page: nextPage, pageSize: _pageSize));
      _page = nextPage;
      _hasMore = result.hasMore;
      state = AsyncData([...current, ...result.items]);
    } catch (_) {
      // Falla "cargar más": se conserva lo ya mostrado, no se pisa el estado.
      // La UI puede mostrar un snackbar aparte leyendo un provider de error puntual.
    } finally {
      _isLoadingMore = false;
    }
  }

  bool get hasMore => _hasMore;
}
```

```dart
// En la UI:
class SeBuscaScreen extends ConsumerWidget {
  const SeBuscaScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(seBuscaFiltersProvider);
    final personsAsync = ref.watch(personSearchNotifierProvider(query));

    return personsAsync.when(
      loading: () => const _SkeletonList(),
      error: (e, _) => _ErrorRetry(onRetry: () => ref.invalidate(personSearchNotifierProvider(query))),
      data: (persons) => ListView.builder(
        itemCount: persons.length + 1,
        itemBuilder: (context, i) {
          if (i == persons.length) {
            // Dispara "cargar más" al llegar al final (patrón scroll infinito).
            ref.read(personSearchNotifierProvider(query).notifier).loadNextPage();
            return const _LoadingMoreIndicator();
          }
          return PersonCard(person: persons[i]);
        },
      ),
    );
  }
}
```

Claves del árbol:
- **`SeBuscaFilters`** (Notifier normal, sin `page`) guarda SOLO los filtros;
  cambiarlos crea una `PersonQuery` nueva.
- **`PersonSearchNotifier` (family sobre `PersonQuery`)**: Riverpod cachea una
  instancia por cada combinación de filtros vista — volver a los mismos
  filtros reutiliza el resultado ya cargado, igual que si fuera una URL con
  query string distinta en la web. `autoDispose` (inferido por el generador)
  libera memoria de combinaciones de filtros que ya no se están mirando.
- El campo `query` dentro del notifier (el parámetro de `build`) queda
  accesible como propiedad de instancia gracias al código generado — así
  `loadNextPage()` puede volver a pedir la repo sin recibir el query como
  argumento. **Verificar el nombre exacto del getter generado en la versión
  de `riverpod_generator` que se use** (el patrón es estable desde 2024-2026,
  el nombre del getter no ha cambiado en las fuentes consultadas).

### 3. Supabase Realtime + Riverpod (reemplazo de `revalidatePath`)

En la web, cada Server Action llama `revalidatePath()` para que Next.js
vuelva a renderizar con datos frescos tras una escritura. En Flutter no hay
equivalente directo — **dos vías, no mutuamente excluyentes**:

**(a) Invalidación simple tras una escritura propia** (recomendado para casi
todas las mutaciones, es lo más parecido a `revalidatePath` y no depende de
tener Realtime habilitado en esa tabla):

```dart
// Tras crear una persona desde el formulario:
await ref.read(personRepositoryProvider).createPerson(input);
ref.invalidate(personSearchNotifierProvider(query)); // fuerza re-fetch
```

**(b) Supabase Realtime vía `.stream()`** — para reflejar cambios de OTROS
usuarios sin que el usuario actual haga nada (ej.: un punto de ayuda que
alguien más marcó "se acabó" mientras la pantalla está abierta; el estado de
una persona seguida que cambia). `supabase_flutter` expone `.stream()` como
combinación de una carga inicial + Postgres Changes por WebSocket:

```dart
@riverpod
Stream<List<Map<String, dynamic>>> aidPointsRawStream(Ref ref, String country) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('aid_points')
      .stream(primaryKey: ['id'])
      .eq('country', country)
      .order('created_at');
}

@riverpod
Stream<List<AidPoint>> aidPointsStream(Ref ref, String country) {
  return ref
      .watch(aidPointsRawStreamProvider(country).stream)
      .map((rows) => rows.map(AidPoint.fromRow).toList());
}
```

```dart
// Seguimiento de UNA persona (ej. pantalla de ficha, para notificar cambio de estado):
@riverpod
Stream<Person?> personStream(Ref ref, String id) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('persons')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .map((rows) => rows.isEmpty ? null : Person.fromRow(rows.first));
}
```

Requisito de infraestructura: **Realtime está deshabilitado por tabla por
defecto en Supabase** — hay que activar "replication" para cada tabla que
necesite `.stream()` (persons, aid_points, hospitals como mínimo) desde el
dashboard o `ALTER PUBLICATION supabase_realtime ADD TABLE ...` en
`supabase/schema.sql`. Esto es un cambio de infraestructura que afecta **al
mismo proyecto Supabase que usa la web** — coordinar con quien mantiene el
repo web antes de activarlo (no lo actives sin avisar: afecta producción).

**Recomendación de alcance para Fase 1-2:** usar solo (a) al inicio (más
simple, cero configuración adicional de Supabase, es lo que ya cubre "refrescar
tras publicar/votar"). Reservar (b) Realtime para casos donde de verdad importa
ver el cambio de otro usuario en vivo sin recargar — puntos de ayuda
(disponibilidad cambia rápido en campo) y el estado de una persona en su
ficha. No es necesario suscribirse a todas las tablas.

---

## FRENTE 2 — Cache offline con aviso de antigüedad (Fase 4, NO MVP)

> Recordatorio explícito: **nada de esta sección se implementa en Fase 1, 2
> o 3.** Se investiga ahora porque el roadmap ya la nombra en Fase 4 y porque
> una mala elección de paquete aquí sería costosa de revertir más tarde
> (migrar datos cacheados de un motor a otro). No instalar Drift/Hive todavía.

### 4. Comparación de paquetes de base de datos local (2025-2026)

| Paquete | Tipo | Estado de mantenimiento (verificado ago-2026) | Web | Encaja con... |
|---|---|---|---|---|
| **Drift** | SQL (SQLite), type-safe, sucesor de Moor | **Activo**, proyecto único (simolus3), sin fork ni fragmentación, guías "2026" recientes lo tratan como opción por defecto para offline-first | Sí (via sqlite3 wasm) | Datos relacionales/tabulares — calza natural con filas de Postgres |
| **Isar** | NoSQL, muy rápido, queries indexadas | **Abandonado por el autor original desde enero 2025** (actualizaciones detenidas); la comunidad forkeó en `isar_community` e `isar_plus`, pero el fork comunitario **sigue buscando activamente más mantenedores** — riesgo real de quedar huérfano otra vez | No | Alto volumen + queries complejas offline (no es el caso aquí) |
| **Hive** (original) | NoSQL clave-valor | **Sin mantenimiento** (mismo destino que Isar: abandonado por `isar` org) | Sí | — |
| **Hive CE** (fork comunitario) | NoSQL clave-valor | **Activo** — última actualización en pub.dev febrero 2026, requiere Dart 3 | Sí | Configuración simple (pares clave-valor), no relacional |
| **`shared_preferences`** | Clave-valor plano | Activo (paquete oficial `flutter.dev`), ya decidido en el plan para el UUID de dispositivo | Sí | Un puñado de valores sueltos, sin listas ni relaciones |

**Recomendación: Drift para las listas cacheadas (personas, puntos de ayuda,
hospitales, caravanas) + `shared_preferences` para metadatos simples
("última sincronización" por lista, ya en la misma familia que el UUID de
dispositivo que el plan ya decidió).**

Justificación:
1. **Isar queda descartado de raíz.** Aunque es rápido, apostar Fase 4 de un
   proyecto construido con urgencia y equipo de 3 personas a un paquete cuyo
   fork comunitario todavía está reclutando mantenedores es un riesgo que no
   compensa la ganancia de velocidad frente a Drift para el volumen de datos
   de esta app (cientos/miles de registros cacheados, no millones).
2. **Hive puro también queda descartado** por la misma razón que Isar
   (abandonado por su organización original); si se quisiera algo tipo
   clave-valor se usaría **Hive CE**, no Hive, — pero ni siquiera hace falta:
   `shared_preferences` ya cubre lo que necesita esta app en esa categoría
   (timestamps, banderas), y ya está decidido en el plan para el UUID de
   dispositivo, así que no suma una tercera dependencia de persistencia.
3. **Drift encaja con la forma real de los datos**: las tablas que hay que
   cachear (`persons`, `aid_points`, `hospitals`, `marches`) son
   exactamente eso — tablas de Postgres con columnas tipadas. Drift permite
   definir esquemas que son casi un calco 1:1 de `supabase/schema.sql`
   (mismo mapeo mental que ya usan los mapeadores `rowToX` de `data.ts`), con
   consultas SQL type-safe si más adelante se necesita filtrar/ordenar el
   cache localmente (ej. "Se busca" con búsqueda de texto sin conexión).
4. Es la opción que más guías "2026" tratan como default razonable para
   offline-first en Flutter, precisamente por ser SQL maduro y no depender de
   un solo mantenedor.

**Costo a tener en cuenta:** Drift exige `build_runner` (generación de
código) y más boilerplate por tabla que Hive. Para un equipo de 3 personas
con prisa, esto es aceptable en Fase 4 (ritmo distinto al MVP), no en Fase 1.

### 5. Patrón "aviso de antigüedad" con Drift

Diseño: una tabla `CacheMeta` genérica con una fila por **clave de cache**
(ej. `"persons|ve|all|true|false|recent"`, la misma que
`PersonQuery.cacheKey` de la sección 2) que guarda cuándo se sincronizó por
última vez esa combinación de filtros — no un timestamp global único, porque
"Se busca" con un filtro y "¿La reconoces?" con otro pueden haberse
refrescado en momentos distintos.

```dart
// lib/data/local/tables.dart
import 'package:drift/drift.dart';

class CachedPersons extends Table {
  TextColumn get id => text()();
  TextColumn get cacheKey => text()(); // a qué lista/filtro pertenece esta fila
  TextColumn get country => text()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get status => text()();
  TextColumn get locationText => text()();
  TextColumn get photoUrl => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id, cacheKey};
}

class CacheMeta extends Table {
  TextColumn get cacheKey => text()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}
```

```dart
// lib/data/local/app_database.dart
@DriftDatabase(tables: [CachedPersons, CacheMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// Guarda una página de resultados y actualiza "sincronizado hace X"
  /// en una sola transacción: si algo falla a mitad, no queda un cache
  /// con datos nuevos pero timestamp viejo (o viceversa).
  Future<void> savePersonsPage(String cacheKey, List<Person> persons) async {
    await transaction(() async {
      await (delete(cachedPersons)..where((t) => t.cacheKey.equals(cacheKey))).go();
      await batch((b) {
        b.insertAll(
          cachedPersons,
          persons.map((p) => CachedPersonsCompanion.insert(
                id: p.id,
                cacheKey: cacheKey,
                country: p.country,
                firstName: p.firstName,
                lastName: p.lastName,
                status: p.status,
                locationText: p.locationText,
                photoUrl: Value(p.photoUrl),
                updatedAt: p.updatedAt,
              )),
        );
      });
      await into(cacheMeta).insertOnConflictUpdate(
        CacheMetaCompanion.insert(cacheKey: cacheKey, syncedAt: DateTime.now()),
      );
    });
  }

  Stream<DateTime?> watchSyncedAt(String cacheKey) {
    final q = select(cacheMeta)..where((t) => t.cacheKey.equals(cacheKey));
    return q.watchSingleOrNull().map((row) => row?.syncedAt);
  }
}
```

```dart
// lib/providers/cache_providers.dart
part 'cache_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) => AppDatabase();

@riverpod
Stream<DateTime?> lastSyncedAt(Ref ref, String cacheKey) {
  return ref.watch(appDatabaseProvider).watchSyncedAt(cacheKey);
}

// Detecta conectividad (paquete connectivity_plus), usado por el banner.
@riverpod
Stream<bool> isOnline(Ref ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));
}
```

```dart
// lib/widgets/stale_data_banner.dart
class StaleDataBanner extends ConsumerWidget {
  const StaleDataBanner({required this.cacheKey, super.key});
  final String cacheKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final syncedAt = ref.watch(lastSyncedAtProvider(cacheKey)).valueOrNull;

    if (online || syncedAt == null) return const SizedBox.shrink();

    final age = DateTime.now().difference(syncedAt);
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF3C7), // ámbar, igual semántica que warning en la web
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFF92400E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Datos de hace ${_formatAge(age)}, sin conexión. Puede haber cambiado.',
              style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAge(Duration age) {
    if (age.inMinutes < 1) return 'un momento';
    if (age.inMinutes < 60) return '${age.inMinutes} min';
    if (age.inHours < 24) return '${age.inHours} h';
    return '${age.inDays} d';
  }
}
```

Este banner **nunca se muestra si hay conexión**, ni siquiera si el dato
técnicamente viene del cache local — la app siempre intenta red primero (ver
patrón "network-first" abajo); el banner es exclusivamente para cuando de
verdad no hay forma de confirmar que el dato está al día. Esto es
directamente la regla que ya fijó `01-arquitectura.md`: "cualquier dato
mostrado sin conexión fresca necesita un aviso visible... nunca presentarse
como estado actual".

**Repository con fallback a cache (network-first):**

```dart
Future<List<Person>> getPersonsWithFallback(PersonQuery q) async {
  final cacheKey = q.cacheKey;
  try {
    final page = await _remote.getPersons(q); // Supabase primero, siempre
    await _db.savePersonsPage(cacheKey, page.items); // refresca cache + syncedAt
    return page.items;
  } on RepositoryException catch (_) {
    // Sin red o error de Supabase: cae al cache. El banner de antigüedad
    // (StaleDataBanner) es responsabilidad de la UI, no de este método —
    // se calcula aparte con `lastSyncedAtProvider`, para no acoplar la
    // presentación al repository.
    return _db.getCachedPersons(cacheKey);
  }
}
```

### 6. Estrategia de sincronización al reconectar — honestidad sobre el alcance

**Lo proporcional para este MVP (hacer esto):**
- Detectar reconexión con `connectivity_plus` + un `StreamProvider` de
  Riverpod (`isOnlineProvider` arriba).
- Al pasar de offline → online, **invalidar los providers de listas visibles**
  (`ref.invalidate(personSearchNotifierProvider(query))`, etc.) para que
  vuelvan a pedir a Supabase — un refetch completo de la página actual, no
  una sincronización incremental.
- Esto es literalmente lo mismo patrón "network-first con fallback a cache"
  ya descrito arriba: no hace falta lógica de sync separada, porque **cada
  vez que hay red, el repository ya intenta la red primero**. "Reconectar"
  no dispara un proceso especial, solo hace que la próxima lectura tenga red
  disponible.

**Lo que NO es proporcional para este MVP (posponer, posiblemente para
siempre):**
- **Sync incremental** (`WHERE updated_at > lastSyncedAt`) para minimizar
  payload: el volumen de datos de esta app (miles de personas por país, no
  millones) hace que un refetch completo de una página de 24-50 filas sea
  trivial en costo comparado con la complejidad de mantener cursores de
  sincronización correctos.
- **Outbox pattern / resolución de conflictos** (escribir offline y
  sincronizar después): esto **no aplica a este proyecto en absoluto**,
  porque la decisión de producto ya tomada (`01-arquitectura.md`, nota de
  consistencia) es que el cache offline es **solo lectura** — nunca se
  edita/publica una persona sin conexión y se sincroniza después. Escribir
  información de una persona desaparecida con datos potencialmente obsoletos
  o en conflicto es exactamente el escenario peligroso que la nota de
  consistencia descarta. Cualquier guía que aparezca sobre "outbox pattern
  con Drift" (existe al menos un paquete, `offline_first_sync_drift`, que lo
  implementa) es **irrelevante para este proyecto** salvo que el producto
  cambie de decisión sobre escritura offline — no es algo a evaluar en Fase 4
  tal como está definida hoy.
- **Múltiples estrategias de expiración por TTL configurable por entidad**:
  para el MVP basta un único criterio simple (mostrar banner si no hay red,
  sin importar cuán "vieja" esté la fila — la antigüedad se muestra, no se
  usa para decidir si el dato es válido o no). Política de expiración más
  fina (ej. borrar cache de más de 7 días) puede esperar a que haya señal
  real de que hace falta.

**Resumen de la Fase 4 realista:** connectivity_plus + invalidar providers al
reconectar + Drift como cache read-through con `CacheMeta.syncedAt` +
`StaleDataBanner`. Nada de outbox, nada de conflictos, nada de sync
incremental — eso sería complejidad que no paga su costo en un MVP construido
con urgencia y que, por decisión de producto, nunca escribe sin conexión.

---

## Fuentes

**Riverpod / repository pattern / codegen:**
- [How to Use Riverpod with Repository Pattern in Flutter](https://chaturadilan.medium.com/how-to-use-riverpod-with-repository-pattern-in-flutter-a-comprehensive-guide-cb840c7daa91)
- [Building a Modular ERP from Scratch with Flutter, Supabase, and Riverpod](https://dev.to/leorasgg/building-a-modular-erp-from-scratch-with-flutter-supabase-and-riverpod-part-1-3jck)
- [Flutter Clean Architecture with Riverpod and Supabase](https://otakoyi.software/blog/flutter-clean-architecture-with-riverpod-and-supabase)
- [How to use Notifier and AsyncNotifier with the new Flutter Riverpod Generator](https://codewithandrea.com/articles/flutter-riverpod-async-notifier/)
- [What's new in Riverpod 3.0 (oficial)](https://riverpod.dev/docs/whats_new)
- [Riverpod 3.0 Key Changes and Practical Usage](https://curogom.dev/riverpod-3-0-key-changes-and-practical-usage-3a0c6957cbf1)
- [Riverpod Tutorials 2026 – Advanced Level Guide](https://flutterfever.com/flutter-riverpod-advanced-guide-2026/)

**Paginación con Riverpod:**
- [Native Lazy-Loading Support for Riverpod Providers (issue oficial #4209)](https://github.com/rrousselGit/riverpod/issues/4209)
- [Pagination with AsyncNotifierProvider (discusión oficial #2763)](https://github.com/rrousselGit/riverpod/discussions/2763)
- [Riverpod — Family (docs oficiales)](https://riverpod.dev/docs/concepts2/family)

**Supabase Realtime + Riverpod:**
- [Flutter: Subscribe to channel (docs oficiales de Supabase)](https://supabase.com/docs/reference/dart/subscribe)
- [Flutter: stream (docs oficiales de Supabase)](https://supabase.com/docs/reference/dart/stream)
- [State Management with Supabase in Flutter](https://medium.com/@nandhuraj/state-management-with-supabase-in-flutter-4038146124fc)
- [Build A Realtime Photo Sharing App with Supabase & Riverpod](https://itnext.io/supabase-riverpod-minicourse-build-a-realtime-photo-sharing-app-98a5e940d4e6)
- [supabase_riverpod_minicourse (repo de ejemplo)](https://github.com/graphicbeacon/supabase_riverpod_minicourse)

**Estado de Isar/Hive:**
- [Is this project still alive? (discusión oficial isar/isar #1581)](https://github.com/isar/isar/discussions/1581)
- [Isar is dead, long live Isar (issue oficial #1689)](https://github.com/isar/isar/issues/1689)
- [FAQ — Isar Database](https://isar.dev/faq.html)
- [isar_plus (fork) — pub.dev](https://pub.dev/packages/isar_plus)
- [hive_ce — pub.dev](https://pub.dev/packages/hive_ce)
- [Future of Isar/Hive (discusión oficial isar/hive #1498)](https://github.com/isar/isar/discussions/1498)
- [Isar vs Hive, what should we be using now? (issue oficial isar/hive #1292)](https://github.com/isar/hive/issues/1292)

**Drift / cache offline / patrón de antigüedad:**
- [Building Offline-First Flutter Apps with Drift — The Complete 2026 Guide](https://flutterstudio.dev/blog/offline-first-flutter-drift.html)
- [Building a Pull-Through Cache in Flutter with Drift, Firestore, and SharedPreferences (gist)](https://gist.github.com/Theaxiom/3d85296d2993542b237e6fb425e3ddf1)
- [Building Offline-First Flutter Apps: A Complete Sync Solution with Drift](https://777genius.medium.com/building-offline-first-flutter-apps-a-complete-sync-solution-with-drift-d287da021ab0)
- [offline_first_sync_drift — pub.dev](https://pub.dev/packages/offline_first_sync_drift) (mencionado solo para descartarlo del alcance de este MVP, ver sección 6)
- [Hive vs Isar vs Drift: Best Flutter Offline Database](https://medium.com/@flutter-app/hive-vs-isar-vs-drift-best-offline-db-for-flutter-c6f73cf1241e)
- [Hive vs Drift vs Floor vs Isar: Best Flutter Databases 2025](https://quashbugs.com/blog/hive-vs-drift-vs-floor-vs-isar-2025)

**Conectividad / reconexión:**
- [Check Internet Connectivity Globally with Connectivity_plus and Riverpod](https://medium.com/@adanlab4/check-internet-connectivity-globally-with-connectivity-plus-and-riverpod-9e354933cff4)
- [Handle Internet Connectivity In Flutter With Riverpod](https://medium.com/@shreebhagwat94/handle-internet-connectivity-in-flutter-with-riverpod-bbde21c187dc)
- [connectivity_plus — pub.dev](https://pub.dev/packages/connectivity_plus)
