# Escritura segura desde Flutter hacia Supabase — investigación y propuesta

> Investigación de apoyo para el plan móvil de "El Mundo Te Busca". Responde al
> hueco confirmado en `supabase/schema.sql` (líneas 588-731 del repo web,
> `C:\Users\angel\Desktop\Elmundotebusca`): hoy solo hay políticas RLS de
> `select` públicas y una de `insert` acotada a `saved_items`
> (`auth.uid() = user_id`). **No hay ninguna política de insert/update pública
> para personas, posts, votos, comentarios, reportes, puntos de ayuda,
> hospitales, mascotas, etc.** Todas esas escrituras hoy pasan exclusivamente
> por Server Actions de Next.js (`src/app/actions.ts`) que usan
> `SUPABASE_SERVICE_ROLE_KEY` (se salta RLS). Ver el bloque de comentarios en
> `supabase/schema.sql:615-619`: *"Antes había inserción pública con la clave
> anon; se quitó porque permitía saltarse Turnstile y la validación, e incluso
> falsear `user_id`"*. Ese antecedente es la razón de fondo de todo lo que
> sigue: ya se probó abrir RLS de par en par y se revirtió a propósito.

No se modificó ningún archivo de `Elmundotebusca` ni de `MundoTebuscaAPP` — son
de solo lectura para esta investigación.

---

## 1. Patrón recomendado: Edge Function con service role, RLS cerrado para escritura

### Los dos patrones que existen hoy en el ecosistema Supabase

**Patrón A — RLS abierto con `with check` + función `security definer`.**
El cliente (Flutter, con la clave `anon` + JWT del usuario) inserta
directamente en la tabla. Una política `with check` valida lo que SQL puede
validar (constraints, `auth.uid() = user_id`, rangos, `auth.jwt() ->> 'role'`
para autorización por rol). Lo que SQL no puede validar bien (lógica de
negocio compleja, límites cruzando tablas, llamadas a servicios externos)
se delega a una función Postgres `security definer` invocada por trigger o
por RPC.

**Patrón B — Edge Function con `service_role`, RLS cerrado para insert/update.**
El cliente nunca escribe directo a la tabla. Llama a una Edge Function HTTPS
(pasando su JWT de sesión), la función valida todo en Deno/TypeScript, y
escribe con `SUPABASE_SERVICE_ROLE_KEY` (que ignora RLS por diseño). Es
exactamente el mismo patrón que ya usa la web hoy, solo que el "servidor" deja
de ser una Server Action de Next.js y pasa a ser una Edge Function que sirve a
ambos clientes.

### Comparación con la documentación y comunidad 2025-2026

- La documentación de Supabase sobre RLS confirma el punto de partida:
  "Enabling Row Level Security on every table before launch is the single
  practice whose absence causes nearly all Supabase exposures" — y el caso
  Lovable (303 endpoints en 170 proyectos con tablas legibles/escribibles por
  cualquiera con la clave `anon` por falta de RLS) es la advertencia estándar
  que se cita en 2025-2026 quand se abre RLS sin cuidado
  ([vibeappscanner.com/best-practices/supabase](https://vibeappscanner.com/best-practices/supabase)).
- La discusión oficial de Supabase sobre Edge Functions + service role
  confirma el patrón B: *"Edge Functions run with service_role by default...
  the service_role bypasses RLS by design — that's its job"*, y la
  recomendación es que la función misma valide autenticación y autorización
  en código antes de escribir
  ([github.com/orgs/supabase/discussions/23172](https://github.com/orgs/supabase/discussions/23172)).
- Sobre el patrón A (RPC + `security definer`), la propia doc de Supabase
  advierte: *"A SECURITY DEFINER function callable by the anon role is
  effectively giving unauthenticated users superuser access to whatever the
  function does"* y exige fijar `search_path` explícitamente para evitar
  hijacking de esquema
  ([supabase.com/docs/guides/database/functions](https://supabase.com/docs/guides/database/functions)).
- Guías de mejores prácticas de RLS en producción (makerkit, GuardLayer)
  coinciden en que RLS es la capa correcta para **lectura multi-tenant** y
  para inserciones triviales de "cada quien lo suyo" (`auth.uid() = user_id`,
  exactamente el caso de `saved_items` que ya existe en el schema), pero no
  para lógica de negocio con validación de forma (regex de cédula, límites de
  longitud, combinaciones condicionales tipo `personSchema.superRefine`),
  anti-abuso, o efectos secundarios (generar un token de gestión, verificar
  Turnstile/attestation, deduplicar por hash de foto)
  ([makerkit.dev/blog/tutorials/supabase-rls-best-practices](https://makerkit.dev/blog/tutorials/supabase-rls-best-practices)).

### Por qué el patrón B es el correcto aquí (y no un híbrido ambicioso)

Este proyecto **ya decidió** (linea 22-23 de `01-arquitectura.md` del plan
móvil) que la validación de escritura se mueve a una Edge Function delgada en
vez de duplicar zod en Dart. Ese es exactamente el patrón B. La pregunta que
faltaba responder era "¿y entonces qué política RLS de insert hace falta?" —
y la respuesta es: **ninguna nueva**. Se deja el schema tal como está hoy
(sin políticas de insert/update públicas, comentario explícito de
`schema.sql:636` "NO se crea política de UPDATE/DELETE para anon"), y **todas**
las escrituras — web y Flutter por igual — pasan por servidores con
`service_role`: Server Actions para la web, Edge Functions para Flutter. Es
literalmente el mismo modelo mental que ya funciona, solo con dos túneles de
entrada en vez de uno.

La única excepción legítima al patrón B es la que ya existe: `saved_items`
(RLS `auth.uid() = user_id`, `schema.sql:723-731`). Ese caso es seguro con
insert RLS directo porque (a) requiere sesión iniciada — no hay anónimos que
falsear, (b) no tiene anti-abuso que perder (guardar/no guardar una
publicación no es un vector de spam de la plataforma), y (c) el `with check`
cubre el 100% de la regla de negocio (que el `user_id` sea el propio). Ese es
el criterio para decidir caso por caso (sección 2).

**Recomendación:** patrón B como regla general, patrón A únicamente para
mutaciones que cumplan las tres condiciones de `saved_items` a la vez.

---

## 2. Qué mutaciones van por Edge Function vs. insert RLS directo

| Mutación | Hoy en `actions.ts` | ¿Por qué? | Recomendación móvil |
|---|---|---|---|
| Crear persona (`registerPersonAction`, `actions.ts:430`) | Turnstile + `personSchema.superRefine` (nombre obligatorio solo si `!isUnidentified`) + genera `ownerToken` + escribe `person_owners` | Validación condicional compleja, anti-bot, genera secreto | **Edge Function obligatoria** |
| Reportar estado (`reportStatusAction`, `actions.ts:502`) | Turnstile + no cambia estado público hasta verificar | Modelo de autoridad — un cliente malicioso podría intentar marcar "localizado" directo | **Edge Function obligatoria** |
| Crear post de comunidad (`createPostAction`, `actions.ts:778`) | Turnstile + zod + genera `ownerToken` | Igual patrón que persona | **Edge Function obligatoria** |
| Registrar punto de ayuda / caravana / hospital / mascota / voluntario / héroe / denuncia | Turnstile + zod + `ownerToken`/`resource_owners` | Mismo patrón en todos | **Edge Function obligatoria** |
| Votos de consenso (`voteAidAvailabilityAction`, `voteHospitalSuppliesAction`) | Dedup por dispositivo/cuenta, actualiza contadores agregados | Requiere lógica atómica (incrementar sin condición de carrera) y límite de frecuencia | **Edge Function obligatoria** (o RPC `security definer` con `unique` constraint en `consensus_votes` como red de seguridad — ver nota abajo) |
| Comentarios (`postCommentAction`) + "me gusta" (`likeCommentAction`, etc.) | `interactionLimiter` (rate limit en memoria, 40/30s) | Es exactamente el caso para el que existe `rateLimit.ts` — sin límite, un script agota la base de datos | **Edge Function obligatoria** (necesita el rate limiting que RLS no puede expresar) |
| Subir foto (hash + Storage) | `compressImage` en cliente, `photoHash` para deduplicar | Storage tiene sus propias políticas RLS (no cubiertas aún, ver nota) | **Edge Function para el registro/hash; Storage upload puede ir directo con política RLS de Storage acotada** (bucket con policy `insert` que solo permite subir a una ruta con el `auth.uid()` o un token de sesión de subida corto) |
| `saved_items` (guardar publicación) | Ya usa RLS directo (`auth.uid() = user_id`) | Cumple las 3 condiciones: requiere sesión, sin anti-abuso que perder, regla 100% expresable en SQL | **Mantener RLS directo, replicar tal cual en Flutter** |
| Reacciones a persona/post (`reactToPersonAction`, `reactToPostAction`) | Sin Turnstile pero sí actualiza contador compartido | Igual riesgo que "me gusta": sin límite es vector de abuso | **Edge Function** (agrupable con la de "me gusta"/votos, ver diseño abajo) |

**Nota sobre `consensus_votes`:** si en el futuro se quiere reducir carga en la
Edge Function, un candidato razonable a patrón híbrido es: insert RLS directo
en `consensus_votes` protegido por `unique(user_id, entity_type, entity_id)` +
`with check (auth.uid() = user_id)`, y un **trigger** `security definer` que
recalcula el contador agregado en `aid_points`/`hospitals`. Elimina la
condición de carrera sin tocar Deno. Pero **requiere sesión obligatoria**
(hoy los votos son también por dispositivo anónimo vía `localStorage`), así
que si se mantiene el voto anónimo en móvil, tiene que seguir siendo Edge
Function (no hay `auth.uid()` que filtrar). Recomendación: mantenerlo en la
Edge Function para no bifurcar el comportamiento anónimo/autenticado.

### Pseudocódigo de la Edge Function delgada (`supabase/functions/mutate/index.ts`)

Diseño de **una sola Edge Function con un router interno por `action`** (en
vez de una función por mutación) para no multiplicar el costo de cold-start y
para centralizar auth + rate limit una sola vez. Reutiliza/replica los mismos
esquemas zod que ya existen en `src/lib/validation.ts` del repo web (zod corre
en Deno sin cambios, es la misma librería):

```typescript
// supabase/functions/mutate/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { z } from "https://esm.sh/zod@3";

// ── Mismo esquema que src/lib/validation.ts:66-106 (personSchema) ──────────
// Se replica aquí (Deno no puede importar directo desde el repo Next.js);
// mantenerlo sincronizado a mano es el costo aceptado del patrón, documentado
// como TODO con referencia al archivo fuente.
const personSchema = z
  .object({
    country: z.enum(["VE", "CO"]).optional(),
    firstName: z.string().trim().max(80).optional().or(z.literal("")),
    lastName: z.string().trim().max(80).optional().or(z.literal("")),
    cedula: z.string().trim()
      .regex(/^[VEJGvejg]?-?\d{5,9}$/u).optional().or(z.literal("")),
    isUnidentified: z.boolean().default(false),
    description: z.string().trim().max(800).optional().or(z.literal("")),
    locationText: z.string().trim().max(160).optional().or(z.literal("")),
    photoHash: z.string().trim().max(64).optional().or(z.literal("")),
    // ...resto igual a validation.ts
  })
  .superRefine((data, ctx) => {
    if (!data.isUnidentified && !data.firstName) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ["firstName"], message: "El nombre es obligatorio" });
    }
  });

const ACTIONS = {
  register_person: { schema: personSchema, handler: handleRegisterPerson, requireAttestation: true },
  report_status:   { schema: statusReportSchema, handler: handleReportStatus, requireAttestation: true },
  create_post:     { schema: postSchema, handler: handleCreatePost, requireAttestation: true },
  vote_aid:        { schema: voteSchema, handler: handleVoteAid, requireAttestation: false },
  like_comment:    { schema: likeSchema, handler: handleLikeComment, requireAttestation: false },
  // ... resto de las ~20 mutaciones de actions.ts
} as const;

serve(async (req) => {
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);

  // 1) Identidad del llamador (sección 4) ──────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader ?? "" } },
  });
  const { data: userData } = await anonClient.auth.getUser(); // null si es anónimo o token inválido
  const userId = userData?.user?.id ?? null;

  const body = await req.json();
  const action = ACTIONS[body.action as keyof typeof ACTIONS];
  if (!action) return json({ ok: false, error: "unknown_action" }, 400);

  // 2) Atestación de dispositivo (sección 3) ───────────────────────────────
  if (action.requireAttestation) {
    const attestOk = await verifyAttestation(body.attestation, req);
    if (!attestOk) return json({ ok: false, error: "attestation_failed" }, 403);
  }

  // 3) Rate limit (sección 5) ───────────────────────────────────────────────
  const rlKey = userId ?? deviceKeyFrom(req); // uuid de shared_preferences si es anónimo
  const allowed = await checkRateLimit(rlKey, body.action);
  if (!allowed) return json({ ok: false, error: "rate_limited" }, 429);

  // 4) Validación de forma (zod, igual que actions.ts) ─────────────────────
  const parsed = action.schema.safeParse(body.payload);
  if (!parsed.success) {
    return json({ ok: false, error: "validation_failed", fieldErrors: parsed.error.flatten() }, 422);
  }

  // 5) Escritura con service role (igual que data.ts, pero en Deno) ────────
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  try {
    const result = await action.handler(admin, parsed.data, userId);
    return json({ ok: true, ...result });
  } catch (e) {
    console.error(e);
    return json({ ok: false, error: "write_failed" }, 500);
  }
});

async function handleRegisterPerson(admin: SupabaseClient, data: z.infer<typeof personSchema>, userId: string | null) {
  // Réplica de createPerson en src/lib/data.ts:818 — mismo shape de tabla,
  // mismo generador de ownerToken (crypto.randomUUID() + hash, o el mismo
  // esquema que newToken() en data.ts).
  const ownerToken = crypto.randomUUID();
  const { data: person, error } = await admin.from("persons").insert({
    first_name: data.firstName || "Sin identificar",
    last_name: data.lastName || null,
    is_unidentified: data.isUnidentified,
    description: data.description || null,
    user_id: userId,
    // ...resto de columnas
  }).select().single();
  if (error) throw error;
  await admin.from("person_owners").insert({ person_id: person.id, token: ownerToken });
  return { id: person.id, ownerToken };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}
```

**Nota de mantenimiento honesta:** este diseño acepta el costo que
`01-arquitectura.md` ya reconoció (línea 23): "mantenerlos 2 veces, se
desincronizan con el tiempo" queda reducido — ya no son *tres* copias
(cliente Dart + Server Action + Edge Function), son *dos* (zod en Next.js,
zod replicado en Deno), porque Flutter nunca duplica la validación, solo
manda el payload crudo y confía en la Edge Function. Si se quiere bajar a
*una* copia, la opción real es publicar `src/lib/validation.ts` como paquete
npm consumido tanto por Next.js como por la Edge Function (Deno soporta
imports npm vía `npm:` specifier, visto arriba) — vale la pena evaluarlo en
una iteración futura, no bloquea el lanzamiento.

---

## 3. Verificación server-side de App Attest / Play Integrity

### App Attest (iOS) — flujo 2025-2026

Documentación oficial: *"Validating apps that connect to your server"* y
*"Attestation Object Validation Guide"*
([developer.apple.com/documentation/devicecheck](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)).
No hay un endpoint HTTP de Apple que verifique el attestation object por ti
en el flujo estándar (a diferencia de Play Integrity) — **la verificación
criptográfica ocurre enteramente en tu servidor**, usando el certificado raíz
público de Apple:

1. El cliente iOS pide un **key ID** nuevo a `DCAppAttestService` y genera
   un **challenge/nonce** que tu servidor le entrega primero (round-trip:
   `POST /attest-init` devuelve un nonce de un solo uso).
2. El cliente llama `attestKey(_:clientDataHash:)` con el hash del nonce y
   obtiene un `attestationObject` en formato **CBOR**.
3. El cliente manda `{ keyId, attestationObject }` a tu servidor.
4. El servidor:
   - Decodifica el CBOR (formato COSE/WebAuthn-like: contiene
     `fmt`, `attStmt` con la cadena de certificados X.509, y `authData`).
   - Verifica la cadena de certificados hasta el **certificado raíz de Apple
     para App Attest** (publicado por Apple, se descarga una vez y se fija en
     el servidor — no es una llamada por-request).
   - Recalcula `clientDataHash = SHA256(challenge)` y confirma que coincide
     con el `nonce` que el propio servidor generó en el paso 1 (evita replay).
   - Extrae el `authData`: compara el hash del **App ID** (Team ID + Bundle
     ID) contra el `rpId` embebido, confirma el contador de firmas (`sign
     count`) para detectar clonado, y extrae la **clave pública** asociada al
     `keyId` — esa clave pública se guarda y se usa para verificar futuras
     *assertions* (llamadas subsecuentes, mucho más baratas que una
     attestation completa).
5. Para llamadas posteriores (no cada mutación necesita una attestation
   completa — es costosa), el cliente usa `generateAssertion(...)` con la
   clave ya registrada, y el servidor solo verifica una firma contra la clave
   pública guardada — mucho más liviano, ideal para el chequeo por-mutación.

Existen dos endpoints reales de Apple, pero son **complementarios**, no
sustitutos de la verificación local: `https://data-development.appattest.apple.com/v1/attestationData`
(sandbox) y su par de producción, que devuelven señales de riesgo de fraude
adicionales sobre un *receipt* — opcional, no bloqueante para el MVP.

Librerías ya maduras para hacer esto en servidor (referencia de
implementación, no para copiar ciego): `veehaitch/devicecheck-appattest`
(Kotlin/JVM) y `node-app-attest` (Node/Deno-compatible) — confirman que el
patrón "descargar root cert de Apple una vez + verificar CBOR/COSE en
servidor" es el estándar de la comunidad, no algo que haya que inventar desde
cero.

Pseudocódigo Deno (usando una librería CBOR/COSE, p. ej. `cbor-x` o
`@levischuck/tiny-cbor` vía `npm:` specifier, más `jose` o Web Crypto nativo
para las firmas):

```typescript
// supabase/functions/_shared/appAttest.ts
import { decode as cborDecode } from "npm:cbor-x@1";

const APPLE_APP_ATTEST_ROOT_PEM = Deno.env.get("APPLE_APPATTEST_ROOT_CA")!; // fijo, descargado una vez de Apple
const APP_ID = Deno.env.get("IOS_APP_ID")!; // "TEAMID.com.elmundotebusca.app"

export async function verifyAppAttest(
  attestationObjectB64: string,
  keyId: string,
  challenge: string, // nonce de un solo uso emitido por /attest-init y consumido aquí
): Promise<{ ok: boolean; publicKey?: CryptoKey }> {
  const attestationObject = cborDecode(base64ToBytes(attestationObjectB64));
  const { fmt, attStmt, authData } = attestationObject;
  if (fmt !== "apple-appattest") return { ok: false };

  // 1) Verificar la cadena de certificados contra el root de Apple.
  const chainOk = await verifyX509Chain(attStmt.x5c, APPLE_APP_ATTEST_ROOT_PEM);
  if (!chainOk) return { ok: false };

  // 2) clientDataHash = SHA256(challenge); debe coincidir con el nonce servido.
  const clientDataHash = await sha256(challenge);
  const nonceOk = await checkNonceEmbedded(attStmt, authData, clientDataHash);
  if (!nonceOk) return { ok: false };

  // 3) authData: rpIdHash debe ser SHA256(APP_ID); sign count = 0 en la 1a attestation.
  const rpIdHashOk = timingSafeEqual(authData.rpIdHash, await sha256(APP_ID));
  if (!rpIdHashOk) return { ok: false };

  // 4) Extraer clave pública para futuras assertions (guardar en tabla `device_keys`).
  const publicKey = await importPublicKeyFromAuthData(authData);
  return { ok: true, publicKey };
}
```

### Play Integrity API (Android) — flujo 2025-2026

Documentación oficial: *"Make a standard API request"*
([developer.android.com/google/play/integrity/standard](https://developer.android.com/google/play/integrity/standard)).
Flujo confirmado:

1. **Cliente Android**: en el arranque de la app llama
   `IntegrityManagerFactory.createStandard(context).prepareIntegrityToken(...)`
   (asíncrono, "calienta" el proveedor de tokens; recomendado también en
   segundo plano antes de necesitarlo). Requiere el **número de proyecto de
   Google Cloud** (`cloudProjectNumber`).
2. Al momento de la mutación sensible: calcula `requestHash = SHA256(payload)`
   (hashear, nunca mandar datos sensibles en claro en ese campo) y pide
   `integrityTokenProvider.request({ requestHash })` → obtiene un token
   firmado y **cifrado** (JWE de un JWS, `ES256`).
3. El cliente manda ese token junto con el payload a la Edge Function.
4. **Servidor (Edge Function en Deno)**: necesita una **cuenta de servicio de
   Google Cloud** (JSON de credenciales) con el scope `playintegrity`, del
   mismo proyecto de Google Cloud vinculado a la app en Play Console. Obtiene
   un access token OAuth2 con esas credenciales y llama:
   ```
   POST https://playintegrity.googleapis.com/v1/{packageName}:decodeIntegrityToken
   Authorization: Bearer <access_token>
   Content-Type: application/json
   { "integrity_token": "<token del cliente>" }
   ```
   Google desencripta y verifica el token en sus propios servidores (el
   servidor de la app **nunca** maneja directamente el material criptográfico
   de verificación — a diferencia de App Attest), y devuelve JSON en claro con
   los veredictos: `deviceIntegrity` (`MEETS_BASIC_INTEGRITY` /
   `MEETS_DEVICE_INTEGRITY` / `MEETS_STRONG_INTEGRITY`), `appIntegrity`
   (`MEETS_DEVICE_INTEGRITY` / `POSSIBLY_MODIFIED` / `TAMPERED`),
   `appLicensing`, y `requestDetails.requestHash` (que el servidor debe
   comparar contra el hash que él mismo esperaba, para descartar payloads
   sustituidos después de generado el token).
5. Protección anti-replay **incluida de fábrica**: reintentar decodificar el
   mismo token una segunda vez devuelve veredictos vacíos/`UNEVALUATED` — no
   hay que implementar nada extra para eso.

```typescript
// supabase/functions/_shared/playIntegrity.ts
import { GoogleAuth } from "npm:google-auth-library@9";

const PACKAGE_NAME = "com.elmundotebusca.app";
const SERVICE_ACCOUNT_JSON = JSON.parse(Deno.env.get("GOOGLE_PLAY_INTEGRITY_SA")!);

const auth = new GoogleAuth({
  credentials: SERVICE_ACCOUNT_JSON,
  scopes: ["https://www.googleapis.com/auth/playintegrity"],
});

export async function verifyPlayIntegrity(
  integrityToken: string,
  expectedRequestHash: string,
): Promise<boolean> {
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();

  const res = await fetch(
    `https://playintegrity.googleapis.com/v1/${PACKAGE_NAME}:decodeIntegrityToken`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ integrity_token: integrityToken }),
      signal: AbortSignal.timeout(6000), // mismo patrón que verifyTurnstile en src/lib/turnstile.ts:26
    },
  );
  if (!res.ok) return false;
  const verdict = await res.json();

  const d = verdict.tokenPayloadExternal;
  if (d.requestDetails.requestHash !== expectedRequestHash) return false;
  if (!["MEETS_DEVICE_INTEGRITY", "MEETS_STRONG_INTEGRITY"].includes(d.deviceIntegrity.deviceRecognitionVerdict?.[0])) {
    return false; // decisión de producto: aceptar solo dispositivos no comprometidos
  }
  if (d.appIntegrity.appRecognitionVerdict === "UNRECOGNIZED_VERSION") return false;
  return true;
}
```

**Secretos que hacen falta, por lado:**
- **iOS**: el certificado raíz público de Apple para App Attest (no es
  secreto, se fija como constante/variable de entorno); el Team ID + Bundle ID
  de la app (público, va en el binario). No hace falta ninguna API key.
- **Android**: una **cuenta de servicio de Google Cloud** con el rol/scope
  `playintegrity` — esta sí es secreta, vive solo en la Edge Function
  (`GOOGLE_PLAY_INTEGRITY_SA` como secret de Supabase, nunca en el APK), y el
  número de proyecto de Google Cloud (público, va en el cliente).

---

## 4. Autenticación del llamado Flutter → Edge Function

Dos casos, alineados con el modelo "cuentas opcionales" que ya tiene la web
(`src/lib/auth.ts`, Supabase Auth con `signInWithPassword`):

**Caso 1 — usuario con sesión iniciada.** `supabase_flutter` ya gestiona el
JWT de Supabase Auth (persistido de forma segura vía `flutter_secure_storage`
internamente, como ya nota `01-arquitectura.md:31`). Al invocar la Edge
Function, el SDK oficial (`supabase.functions.invoke(...)`) **adjunta
automáticamente** el header `Authorization: Bearer <jwt de sesión>` — no hay
que hacer nada especial en el cliente. Dentro de la función, se decodifica ese
JWT creando un cliente Supabase con `ANON_KEY` + ese mismo header y llamando
`auth.getUser()` (patrón mostrado en el pseudocódigo de la sección 2) — es el
patrón oficial recomendado ("client authenticates with Supabase Auth, then
calls Edge Functions with the user's JWT; function validates this JWT").

**Caso 2 — usuario anónimo (publica sin cuenta, como ya permite la web).**
Aquí hay dos sub-opciones reales:
  - **(a) Supabase Auth Anonymous Sign-ins** (`signInAnonymously()`): Supabase
    emite un JWT real de todos modos, con `is_anonymous: true` en los claims.
    Ventaja: mismo mecanismo de auth para ambos casos, `auth.getUser()`
    funciona igual, y da un `user_id` estable para asociar el `ownerToken`
    aunque el usuario nunca haya puesto contraseña — de hecho simplifica el
    modelo de "token de gestión por enlace" mencionado como pendiente de
    decisión en `05-fuente-web-existente.md:195` (el `ownerToken` se podría
    atar a esa sesión anónima en vez de solo a un secreto de un solo uso).
  - **(b) Sin sesión Supabase, solo attestation.** El header `Authorization`
    lleva la `ANON_KEY` (público) y la Edge Function confía únicamente en
    App Attest / Play Integrity para saber que la llamada viene de la app
    real, sin identidad de usuario. Es lo más parecido al comportamiento
    anónimo actual de la web (donde tampoco hay `user_id`, solo el
    `ownerToken` generado al vuelo).

**Recomendación:** usar **(a)**, sign-in anónimo de Supabase Auth desde el
primer arranque de la app (silencioso, sin pantalla de login), y recién pedir
alta de cuenta real cuando el usuario quiera "mis publicaciones
multi-dispositivo" — Supabase soporta convertir una sesión anónima en cuenta
real (`linkIdentity`) sin perder el historial. Esto da un `user_id` desde el
día uno para *todas* las escrituras (incluida la posibilidad futura de mover
más mutaciones al patrón A con `auth.uid()`), y no depende de que
App Attest/Play Integrity estén disponibles en el primer release (attestation
puede fallar en desarrollo/testing/dispositivos rooteados legítimos que Apple
recomienda no bloquear duro, ver "remediation" en la doc de Play Integrity).

---

## 5. Rate limiting / anti-abuso en la Edge Function

El patrón actual (`src/lib/rateLimit.ts`, `src/lib/ipLockout.ts`) es
`Map` en memoria de un solo proceso Node con PM2 — funciona porque hay
**una** instancia persistente. Una Edge Function de Supabase corre sobre Deno
Deploy: **stateless, múltiples instancias/regiones, sin memoria compartida
entre invocaciones** — ese patrón literalmente no puede portarse tal cual
(cada instancia tendría su propio `Map` vacío).

Opciones reales confirmadas en la documentación/comunidad 2025-2026:

1. **Upstash Redis vía REST (recomendado, es la guía oficial de Supabase).**
   Existe una guía dedicada,
   *"Rate Limiting Edge Functions"*
   ([supabase.com/docs/guides/functions/examples/rate-limiting](https://supabase.com/docs/guides/functions/examples/rate-limiting))
   con ejemplo completo en el repo de Supabase
   ([github.com/supabase/supabase/tree/master/examples/edge-functions/supabase/functions/upstash-redis-ratelimit](https://github.com/supabase/supabase/tree/master/examples/edge-functions/supabase/functions/upstash-redis-ratelimit)).
   Usa `@upstash/ratelimit` + `@upstash/redis` (cliente HTTP/REST, hecho a
   propósito para entornos serverless/edge sin conexiones TCP persistentes).
   El ejemplo oficial usa `Ratelimit.slidingWindow(2, "10 s")` con la clave
   derivada del `user.id` del JWT (mismo patrón de `auth.getUser()` de la
   sección 4). Es la opción que más se parece en espíritu al
   `createRateLimiter(max, windowMs)` que ya existe en `rateLimit.ts` — mismo
   concepto (ventana fija/deslizante por clave), solo que el contador vive en
   Redis en vez de en memoria del proceso.
   ```typescript
   // supabase/functions/_shared/rateLimit.ts
   import { Ratelimit } from "npm:@upstash/ratelimit@2";
   import { Redis } from "npm:@upstash/redis@1";

   const redis = new Redis({
     url: Deno.env.get("UPSTASH_REDIS_REST_URL")!,
     token: Deno.env.get("UPSTASH_REDIS_REST_TOKEN")!,
   });

   // Equivalente directo a interactionLimiter (rateLimit.ts:41): 40 cada 30s,
   // pero por clave = userId o deviceId (no hay IP de servidor útil aquí,
   // ver nota abajo), y compartido entre "me gusta"/reacciones/votos.
   export const interactionLimiter = new Ratelimit({
     redis,
     limiter: Ratelimit.slidingWindow(40, "30 s"),
     prefix: "interaction",
   });

   // Equivalente a Turnstile-gated actions: más estricto porque cada llamada
   // implica una escritura "pesada" (persona, post, punto de ayuda).
   export const publishLimiter = new Ratelimit({
     redis,
     limiter: Ratelimit.slidingWindow(5, "60 s"),
     prefix: "publish",
   });
   ```
2. **Tabla de Postgres con contador (sin dependencias externas).** Una tabla
   `rate_limit_hits(key text, window_start timestamptz, count int)` con un
   `upsert ... on conflict do update` atómico, leída/escrita con la misma
   `service_role` que ya usa la función. Ventaja: cero servicios nuevos que
   contratar/monitorear. Desventaja: cada chequeo es un round-trip a Postgres
   (más lento que Redis, pero para el volumen de esta plataforma —cientos, no
   millones de escrituras/día— es sobradamente suficiente), y hay que podar
   filas viejas con un cron o `pg_cron`.
   ```sql
   create table if not exists rate_limit_hits (
     key text not null,
     window_start timestamptz not null,
     count int not null default 1,
     primary key (key, window_start)
   );
   -- Ventana fija de 30s, igual granularidad que interactionLimiter hoy.
   ```
   ```typescript
   async function allow(admin: SupabaseClient, key: string, max: number, windowMs: number) {
     const windowStart = new Date(Math.floor(Date.now() / windowMs) * windowMs).toISOString();
     const { data, error } = await admin.rpc("bump_rate_limit", { p_key: key, p_window_start: windowStart });
     if (error) return false; // fail-closed: si Postgres falla, no se permite (igual criterio que verifyTurnstile en producción)
     return (data as number) <= max;
   }
   ```
   con una función `security definer` `bump_rate_limit` que hace el
   `insert ... on conflict (key, window_start) do update set count = count + 1
   returning count` de forma atómica (una sola sentencia, sin condición de
   carrera entre invocaciones concurrentes de la Edge Function).
3. **Rate limiting nativo de Supabase**: no existe a nivel de Edge Function
   individual (Supabase sí limita invocaciones totales por plan a nivel de
   plataforma, pero no expone un rate-limiter configurable por-usuario/por-IP
   nativo) — no es una opción real hoy, hay que construirlo con (1) o (2).

**Nota importante sobre "billing per invocation":** la comunidad de Supabase
señala que aunque el rate limiter rechace la petición, **la invocación ya se
contó y cobró** antes de que corra tu código
([github.com/orgs/supabase/discussions/36512](https://github.com/orgs/supabase/discussions/36512)).
Para este proyecto (sin fines de lucro, volumen moderado) no es bloqueante,
pero vale la pena que quien decida la cuenta de facturación lo sepa: un
ataque de flood sigue costando dinero aunque cada llamada individual sea
rechazada en 5ms.

**Recomendación:** empezar con la **opción 2 (tabla Postgres + función
`security definer`)** para el lanzamiento — cero servicios nuevos, cero
secretos nuevos que gestionar, y el volumen actual del proyecto no lo
justifica. Migrar a Upstash Redis (opción 1) solo si el volumen de escrituras
crece lo suficiente para que la latencia de Postgres empiece a doler (sería
una señal de éxito, no un bloqueo del MVP).

---

## 6. Riesgo de la clave `anon` embebida en el APK/IPA

Confirmado por múltiples fuentes 2025-2026
([uxcontinuum.com/blog/app-security/anon-key-exposed](https://uxcontinuum.com/blog/app-security/anon-key-exposed),
[guardlayer.io/blog/is-supabase-anon-key-safe](https://www.guardlayer.io/blog/is-supabase-anon-key-safe)):
la clave `anon` está **diseñada para ser pública** — no es un secreto que se
"filtre" al descompilar el APK/IPA, es equivalente a que cualquiera pueda ver
el HTML de una página web. La diferencia real con las claves de servidor web
(`SUPABASE_SERVICE_ROLE_KEY`, que nunca llega al cliente) es que la clave
`anon` **no otorga ningún privilegio por sí sola** — todo lo que protege es
exactamente lo que digan las políticas RLS, ni más ni menos.

**Qué protege realmente contra abuso si alguien decompila la app y llama a
Supabase directo con la clave `anon` (sin pasar por la Edge Function, sin
attestation, con curl):**
- **RLS de lectura** (`public_read_*`): nada que perder — esos datos ya son
  públicos por diseño (personas desaparecidas, puntos de ayuda, etc., son
  información que se busca difundir).
- **RLS de escritura**: con el diseño de este documento, **no existe ninguna
  política de insert/update pública** — exactamente igual que hoy en la web.
  Un atacante con la clave `anon` puro (sin JWT válido, sin pasar por la Edge
  Function) **no puede escribir nada directo a Postgres**, sin importar que
  tenga la clave. Esa es la razón central por la que el patrón B (RLS cerrado
  + Edge Function) es la elección correcta para este proyecto: convierte la
  clave `anon` filtrada en un no-evento para escritura.
- Lo único que la clave `anon` sí permite de por sí es **invocar la Edge
  Function** — ahí es donde vive toda la defensa real: attestation (sección
  3), rate limiting (sección 5), y validación de forma (sección 2). Si un
  atacante decompila la app, extrae la clave `anon` y el endpoint de la
  función, **puede** llamar a la Edge Function directamente sin pasar por la
  UI de Flutter — pero seguiría necesitando (a) un JWT válido o sesión
  anónima real de Supabase Auth, y (b) un token de App Attest/Play Integrity
  válido, que **no se puede falsificar sin un dispositivo real** ejecutando
  el binario firmado real de la app (ese es exactamente el problema que
  App Attest/Play Integrity resuelven — ver sección 3). Puede automatizar
  llamadas *desde un dispositivo real con la app instalada*, que es el mismo
  límite de fricción que ya acepta la web con Turnstile (reduce el abuso
  trivial de script, no lo hace matemáticamente imposible contra un atacante
  con muchos dispositivos reales).

**Qué tan crítico es esto dado que el proyecto ya recibió comentarios
hostiles en redes:** el diseño de este documento no cambia la superficie de
ataque respecto a hoy — hoy la web *ya* depende de RLS cerrado + servidor
propio (Server Actions) como única defensa de escritura, y ya sobrevivió el
escrutinio hostil sin política de insert pública. Extender exactamente el
mismo modelo a móvil (Edge Function como "servidor propio" equivalente) no
introduce una superficie nueva; lo que sí sería crítico es **cualquier
desviación** de esto — por ejemplo, abrir una política de insert directa "para
simplificar" en algún momento de prisa. La recomendación explícita es: si en
algún punto del desarrollo se siente la tentación de abrir una política RLS
de insert "temporal" para no bloquear el desarrollo de Flutter mientras la
Edge Function no está lista, usar en su lugar una Edge Function mínima sin
attestation/rate-limit todavía (solo auth + zod), nunca RLS abierto — es más
rápido de revertir y no dejar ninguna ventana de exposición real, ni
"temporal", en producción.

---

## Recomendación final, accionable

1. **No tocar RLS de escritura.** `supabase/schema.sql` se queda exactamente
   como está (comentarios de las líneas 615-636 siguen siendo la verdad).
   Cero políticas nuevas de `insert`/`update` para personas, posts, votos,
   comentarios, puntos de ayuda, hospitales, mascotas, denuncias, etc.
2. **Una sola Edge Function `mutate`** (Deno) con router interno por
   `action`, service role, que cubre las ~20 mutaciones sensibles de
   `actions.ts` — diseño y pseudocódigo en la sección 2. Reduce cold-starts
   frente a una función por mutación.
3. **Excepción única a RLS cerrado:** `saved_items` sigue con insert RLS
   directo (`auth.uid() = user_id`) tal como ya está — Flutter lo replica
   igual, sin pasar por la Edge Function.
4. **Auth del llamado:** sign-in anónimo de Supabase Auth (`signInAnonymously`)
   desde el primer arranque de la app; el SDK de Flutter adjunta el JWT solo;
   la función valida con `auth.getUser()`. Subir a cuenta real más adelante
   con `linkIdentity`, sin perder historial.
5. **Attestation:** App Attest (iOS, verificación 100% local en la Edge
   Function contra el root cert de Apple) y Play Integrity (Android, llamada
   a `decodeIntegrityToken` con cuenta de servicio de Google Cloud) — solo
   obligatoria en las mutaciones "pesadas" (crear persona/post/recurso,
   reportar estado); las de bajo riesgo (like, voto) solo pasan por rate
   limit, igual que hoy en la web.
6. **Rate limiting: tabla Postgres + función `security definer`** para el
   lanzamiento (cero servicios nuevos); dejar documentada la migración a
   Upstash Redis como paso 2 si el volumen lo justifica.
7. **La clave `anon` en el APK no es el riesgo — RLS cerrado ya lo neutraliza
   para escritura.** El riesgo real y donde hay que invertir esfuerzo de
   verdad es que la Edge Function en sí (auth + attestation + rate limit)
   quede bien hecha desde el primer release, porque *ella* es el nuevo
   perímetro — el equivalente exacto de lo que hoy hacen las Server Actions.

---

## Fuentes

- [Row Level Security | Supabase Docs](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Database Functions | Supabase Docs](https://supabase.com/docs/guides/database/functions)
- [Edge Functions | Supabase Docs](https://supabase.com/docs/guides/functions)
- [Rate Limiting Edge Functions | Supabase Docs](https://supabase.com/docs/guides/functions/examples/rate-limiting)
- [Upstash Redis rate-limit example (repo Supabase)](https://github.com/supabase/supabase/tree/master/examples/edge-functions/supabase/functions/upstash-redis-ratelimit)
- [Edge Function + service_role vs anon policy — discusión oficial Supabase #23172](https://github.com/orgs/supabase/discussions/23172)
- ["Simple rate limiting for almost all services needed" — discusión Supabase #36512 (nota sobre billing por invocación)](https://github.com/orgs/supabase/discussions/36512)
- [Supabase RLS Best Practices: Production Patterns (makerkit.dev)](https://makerkit.dev/blog/tutorials/supabase-rls-best-practices)
- [Supabase Row Level Security: the Complete Guide (GuardLayer)](https://www.guardlayer.io/blog/supabase-row-level-security-complete-guide)
- [Is it safe to expose the Supabase anon key? (GuardLayer)](https://www.guardlayer.io/blog/is-supabase-anon-key-safe)
- [Your Supabase Anon Key Is Public — What That Does and Doesn't Mean (uxcontinuum)](https://uxcontinuum.com/blog/app-security/anon-key-exposed)
- [Supabase Security Best Practices: RLS, API Keys & CVE-2025-48757 (vibeappscanner)](https://vibeappscanner.com/best-practices/supabase)
- [Validating apps that connect to your server | Apple Developer Documentation](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Attestation Object Validation Guide | Apple Developer Documentation](https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide)
- [Preparing to use the app attest service | Apple Developer Documentation](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
- [Establishing your app's integrity | Apple Developer Documentation](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [DCAppAttestService | Apple Developer Documentation](https://developer.apple.com/documentation/devicecheck/dcappattestservice)
- [veehaitch/devicecheck-appattest (librería de referencia server-side, Kotlin)](https://github.com/veehaitch/devicecheck-appattest)
- [Make a standard API request | Play Integrity | Android Developers](https://developer.android.com/google/play/integrity/standard)
- [Make a classic API request | Play Integrity | Android Developers](https://developer.android.com/google/play/integrity/classic)
- [Play Integrity API Setup Guide (Medium)](https://medium.com/@mohamed.ma872/%EF%B8%8F-play-integrity-api-setup-guide-d1aaa0c4f504)

### Archivos del repo web citados como referencia (solo lectura, no modificados)
- `C:\Users\angel\Desktop\Elmundotebusca\supabase\schema.sql` (líneas 561-731: sección RLS)
- `C:\Users\angel\Desktop\Elmundotebusca\src\app\actions.ts` (líneas 430-499: `registerPersonAction`, resto del archivo: ~55 Server Actions)
- `C:\Users\angel\Desktop\Elmundotebusca\src\lib\validation.ts` (líneas 66-108: `personSchema`)
- `C:\Users\angel\Desktop\Elmundotebusca\src\lib\turnstile.ts`
- `C:\Users\angel\Desktop\Elmundotebusca\src\lib\rateLimit.ts`
- `C:\Users\angel\Desktop\Elmundotebusca\src\lib\ipLockout.ts`
- `C:\Users\angel\Desktop\Elmundotebusca\src\lib\data.ts` (líneas 818-926: `createPerson`, patrón `ownerToken`/`person_owners`; línea 723-731 del schema: `saved_items`)
- `C:\Users\angel\Desktop\Elmundotebusca\src\lib\auth.ts` (Supabase Auth: `signInWithPassword`, `getUser`)
- `C:\Users\angel\Desktop\MundoTebuscaAPP\plan-app-movil\01-arquitectura.md`
- `C:\Users\angel\Desktop\MundoTebuscaAPP\plan-app-movil\05-fuente-web-existente.md`
