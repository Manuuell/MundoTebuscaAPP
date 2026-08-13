# 13. Refinamiento visual fase 2, guía interactiva y SOS de punta a punta

Escrito después de revisar los commits reales del equipo (login por usuario,
"Se busca" rediseñado con `MTSearchBar`+FAB "Publicar persona", QR de marca,
ficha de persona completa). Documento de **instrucciones directas**, no de
investigación: dice exactamente qué ya quedó hecho y qué le toca a cada quien
para terminar el pulido tipo iOS pedido — buscadores/filtros/paginado
compactos, asistente flotante, guía interactiva y la Red de auxilio lista para
la demo en vivo.

---

## 0. Ya implementado y en `main` (no repetir)

**Widgets compartidos — `lib/widgets/mt_search_bar.dart`** (nuevos, para
que nadie vuelva a inventar un buscador a toda altura):

- `MTSearchBar`: fila compacta de 40px con buscador + botón de filtros
  (embudo, con insignia si hay filtros activos) + espacio para un `trailing`
  opcional. Reemplaza los `TextField` de 48-52px que había en cada pantalla.
- `mostrarHojaFiltros(...)`: hoja estándar "título + contenido + Limpiar +
  Aplicar" — cada pantalla arma su propio contenido (chips, switches) y se la
  pasa. Los filtros ya NO van sueltos a la vista, igual que en la web.
- `MTPaginationButton`: botón del mismo alto que el buscador, despliega un
  menú (10/20/50 — 10 por defecto) del mismo ancho que él mismo, tal como se
  pidió.

**Referencia de uso real: [`lib/features/se_busca/se_busca_screen.dart`](../../lib/features/se_busca/se_busca_screen.dart).**
Cópienle el patrón literal, no lo reinventen:
`MTSearchBar(controller:…, filtrosActivos: contarActivos(), alTocarFiltros: () => mostrarHojaFiltros(...), trailing: MTPaginationButton(...))`.
El segmentado "Lista / ¿La reconoces?" también se hizo más chico (34px de alto
en vez del original) — mismo criterio: si un control no es el protagonista de
la pantalla, no debería medir lo mismo que el buscador.

**Asistente — burbuja flotante**, ya no ícono de cabecera. Vive en
[`lib/widgets/asistente_sheet.dart`](../../lib/widgets/asistente_sheet.dart)
(`BotonAsistenteFlotante`) y se engancha una sola vez en
[`lib/features/shell/home_shell.dart`](../../lib/features/shell/home_shell.dart),
apoyada sobre la esquina de la tab bar. **No la agreguen de nuevo en ninguna
pantalla individual** — es global, ya aparece en todas partes.

**Guía interactiva** — motor nuevo en
[`lib/widgets/guia_interactiva.dart`](../../lib/widgets/guia_interactiva.dart):
resalta un widget real (vía `GlobalKey`) con un spotlight y difumina el resto,
con tarjeta de texto que se acomoda arriba o abajo según el espacio. Soporta
pasos que viven en OTRA pantalla/pestaña (`GuiaPaso.alEntrar`, que puede hacer
`context.go(...)` o cambiar de tab antes de medir el objetivo). Ahora mismo
hay un recorrido de 6 pasos sobre toda la tab bar
(`iniciarRecorridoGuiado` en
[`lib/widgets/guia_rapida_sheet.dart`](../../lib/widgets/guia_rapida_sheet.dart)),
lanzado desde el botón "Recorrido guiado por la app" dentro de la guía rápida
existente (ícono `?` de la cabecera). **Esto es solo el esqueleto — falta que
cada sección añada SU tramo.** Ver §1/§2 abajo cómo.

**SOS de punta a punta** (para la prueba en vivo):

- Sondeo cada 6s (mientras la app está abierta) de si el dispositivo tiene un
  check-in pendiente — no hay push real todavía (FCM/APNs no está
  configurado), así que esto es lo que hace que la demo funcione HOY sin esa
  infraestructura. Ver `_sondearCheckin` en
  [`lib/app.dart`](../../lib/app.dart).
- Pantalla completa `CheckinAlertaScreen` ("¿Estás bien?") con vibración +
  sonido en pulso cada 1.4s, sin botón de "cerrar" (hay que responder). Botones
  Sí/No llaman a la Edge Function.
- Pantalla `NecesitanAyudaScreen`, accesible desde Ajustes → "Necesitan
  ayuda": lista para cuentas con el nuevo rol `volunteer` (ver §3), muestra
  nombre, tipo de sangre y ubicación de quien no respondió o dijo que no está
  bien, con toque para abrir Google Maps.
- Edge Function `safety-optin` (repo web) tiene 2 acciones nuevas: `poll`
  (el propio dispositivo) y `list-needs-help` (voluntario autenticado, valida
  el rol server-side).

**Pendiente manual — solo quien tenga acceso al proyecto Supabase real**:

1. Correr el SQL nuevo de `supabase/schema.sql` (rol `volunteer` en
   `app_roles`, columna `blood_type` en `profiles`).
2. `supabase functions deploy safety-optin` de nuevo (tiene las 2 acciones
   nuevas).
3. Para la demo: asignar el rol `volunteer` a mano a la cuenta del compañero
   que hace de "rescatista" —
   `insert into app_roles (user_id, role) values ('<uuid>', 'volunteer');`
   — y ponerle un `blood_type` a la cuenta de quien hace de "víctima" para que
   se vea en la tarjeta.

---

## 1. Para Manuu — Comunidad (muro/voluntarios/caravanas/denuncias) + Personas

**El botón "+" que quitaste de Comunidad quedó bien** — no lo repongan, las
secciones que colgaban de ahí ya viven en Ajustes.

1. **Buscador/filtros/paginado compactos.** Cada subsección de Comunidad
   (muro, voluntarios, caravanas, denuncias) que tenga su propio buscador o
   fila de chips de filtro debe pasar al patrón de `MTSearchBar` +
   `mostrarHojaFiltros` + `MTPaginationButton`, copiando literal lo que se
   hizo en `se_busca_screen.dart`. Si alguna subsección no tiene buscador
   propio todavía, no hace falta inventárselo — solo aplica donde ya existe.

2. **Tu tramo de la guía interactiva.** En
   [`lib/core/util/guia_claves.dart`](../../lib/core/util/guia_claves.dart)
   agrega las `GlobalKey` de lo que quieras señalar en Comunidad (p.ej. el FAB
   de publicar de cada subsección, el selector de pestañas
   muro/voluntarios/caravanas/denuncias). Ponle `key: GuiaClaves.tuClave` al
   widget real, y encadena tus `GuiaPaso` después de los 6 que ya existen en
   `iniciarRecorridoGuiado` (mismo archivo, `guia_rapida_sheet.dart`) — no
   hace falta un motor nuevo, es la misma función, solo se le agregan más
   pasos a la lista.

3. **Perfil: campo de tipo de sangre.** Se agregó `profiles.blood_type` al
   esquema (ve §0) para que la Red de auxilio lo muestre a un voluntario.
   Falta el campo en la UI de edición de perfil (`perfil_screen.dart`, que ya
   es tuyo) — un selector simple de 8 valores (`O-`, `O+`, `A-`, `A+`, `B-`,
   `B+`, `AB-`, `AB+`), opcional, que llame a como sea que ya actualizas el
   perfil hoy (probablemente falta también el endpoint/Edge Function de
   perfil — si no existe, avísame y lo armo yo, es el mismo patrón de
   `safety-optin`).

---

## 2. Para jerdiaz — Ayuda, Hospitales, Mascotas, Mapa

1. **Mismo patrón de buscador/filtros/paginado.** Ayuda y Hospitales
   seguramente tienen chips de filtro sueltos (tipo de recurso, disponibilidad,
   etc.) — muévanlos a `mostrarHojaFiltros` detrás del botón de embudo, igual
   que Se busca. Mascotas si tiene buscador, mismo trato. El mapa no necesita
   `MTSearchBar` en el lienzo, pero si tiene una barra de búsqueda de lugares
   flotando arriba, aplica el mismo criterio de altura compacta (40px) que el
   resto de la app — no la dejen a la altura vieja de 48-52px.

2. **Tu tramo de la guía interactiva.** Mismo mecanismo que en §1.2: agrega
   tus `GlobalKey` en `guia_claves.dart`, engánchalas a los widgets reales de
   Ayuda/Hospitales/Mapa, y encadena tus `GuiaPaso` a `iniciarRecorridoGuiado`.

3. **Mapa.** Si el mapa muestra pines de la Red de auxilio en algún momento
   (fase futura, no ahora), la Edge Function ya devuelve `lat`/`lng` en
   `list-needs-help` — no hace falta tocar nada del backend cuando llegue ese
   momento, solo consumir el repositorio `SafetyRepository.listarNecesitanAyuda()`.

---

## 3. Revisión rápida de lo subido hasta ahora (arquitectura/fluidez/seguridad)

- **Login por usuario + perfil por servidor (Manuu)**: bien resuelto, sigue
  el mismo patrón de Edge Function que el resto — no hay escritura directa a
  `profiles` desde el cliente.
- **"Se busca" con FAB "Publicar persona" que abre el sitio web**: decisión
  correcta y ya documentada en el propio código — publicar es una escritura y
  la Edge Function de escrituras genéricas todavía no existe (ver
  [`01-escritura-segura.md`](01-escritura-segura.md), sigue siendo el
  bloqueador #1 para que Comunidad/Ayuda/Mascotas puedan publicar *dentro* de
  la app en vez de saltar al sitio).
- **Ficha de persona completa + guía de voluntariado**: no la revisé a fondo
  línea por línea todavía — pendiente para la próxima pasada si quieren una
  revisión de seguridad específica de esa pantalla (mismo criterio de
  privacidad de `persons` que ya se documentó en
  [`12-revision-2026-08-13.md`](12-revision-2026-08-13.md) — ojo con qué
  campos se muestran sin filtro).
- **Nada de lo nuevo en esta sesión (SOS, guía interactiva, buscadores)
  requirió tocar Edge Functions ajenas ni RLS de otras tablas** — cambios
  aislados, sin riesgo de pisar el trabajo de nadie más en `main`.

---

## Fuentes

Ninguna externa nueva — este documento es instrucciones internas sobre código
ya escrito en este repo y en `Elmundotebusca/supabase/`.
