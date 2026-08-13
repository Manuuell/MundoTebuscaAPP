/**
 * Proxy del asistente de El Mundo Te Busca.
 *
 * Existe por una sola razon: la OPENAI_API_KEY no puede viajar en la app. Un
 * APK o un IPA se descomprime y se le sacan las cadenas en segundos, y esa
 * llave es facturable. Mismo diseno que `chatbotProxy` de TransCar.
 *
 * Ademas del secreto, el servidor guarda dos cosas que el cliente no debe
 * poder cambiar: el prompt del sistema y los limites de uso.
 *
 * Arranque:
 *   PORT=3210 OPENAI_API_KEY=... SUPABASE_URL=... SUPABASE_ANON_KEY=... node index.js
 */

'use strict';

const http = require('http');

const PUERTO = process.env.PORT || 3210;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const MODELO = process.env.CHAT_MODEL || 'gpt-4.1-mini';

if (!OPENAI_API_KEY) {
  console.error('[asistente] falta OPENAI_API_KEY');
  process.exit(1);
}

// ── Limite de uso ────────────────────────────────────────────────────────────
// Por IP y por minuto. No es a prueba de todo, pero evita que un bucle en un
// cliente se lleve por delante la cuota de OpenAI en una tarde.
const MAX_POR_MINUTO = 12;
const golpes = new Map();

function excedido(ip) {
  const ahora = Date.now();
  const previos = (golpes.get(ip) || []).filter((t) => ahora - t < 60_000);
  previos.push(ahora);
  golpes.set(ip, previos);
  return previos.length > MAX_POR_MINUTO;
}

// Limpieza periodica: sin esto el Map crece sin parar.
setInterval(() => {
  const ahora = Date.now();
  for (const [ip, ts] of golpes) {
    const vivos = ts.filter((t) => ahora - t < 60_000);
    if (vivos.length === 0) golpes.delete(ip);
    else golpes.set(ip, vivos);
  }
}, 120_000).unref();

// ── Prompt del sistema ───────────────────────────────────────────────────────
// Vive aqui y no en el cliente: si viajara en la app, cualquiera podria
// reemplazarlo y usar la cuenta de OpenAI del proyecto para lo que quisiera.
function promptSistema(contexto) {
  return `Eres el asistente de El Mundo Te Busca, una plataforma ciudadana de
busqueda de personas y coordinacion de ayuda ante emergencias, activa hoy para
los terremotos de Colombia y Venezuela.

REGLAS QUE NO PUEDES ROMPER:
- No eres un organismo de socorro. Ante una emergencia en curso, lo primero que
  dices es que llamen a la linea nacional de emergencias del pais activo.
- No inventes cifras, nombres de personas, direcciones ni telefonos. Si no
  tienes el dato en el contexto de abajo, di que no lo tienes y explica donde
  mirarlo dentro de la app.
- No afirmes que una persona concreta esta viva, muerta, localizada o
  desaparecida. Remite siempre a la ficha de esa persona en la seccion
  "Se busca".
- No des diagnosticos medicos ni indicaciones clinicas mas alla de primeros
  auxilios basicos y generales.
- Responde en espanol, en 2 o 3 frases cortas salvo que te pidan detalle.
  Quien escribe puede estar en una situacion angustiosa: ve al grano, con
  calma y sin adornos.

QUE HACE LA APP (para orientar a quien pregunta):
- Inicio: cifras de la emergencia y noticias verificadas.
- Se busca: buscador de personas por nombre, documento o ubicacion, con
  filtros por estado (por localizar, en hospital, a salvo, fallecido) y una
  vista de fichas para repasar una por una.
- Comunidad: muro de publicaciones, voluntarios, caravanas de ayuda y
  denuncias de irregularidades.
- Mapa: puntos de ayuda, hospitales, refugios y zonas afectadas.
- Ajustes: cuenta, emergencia activa y la guia rapida de emergencia, que
  funciona sin conexion.
- Publicar, comentar y reportar todavia no estan habilitados en la app; por
  ahora eso se hace desde el sitio web elmundotebusca.com.

CONTEXTO DE AHORA MISMO (usalo como fuente de verdad para cifras):
${contexto || 'Sin datos de contexto disponibles.'}`;
}


// ── Login por nombre de usuario ──────────────────────────────────────────────
// La app no puede resolver usuario -> correo por su cuenta: RLS no deja que la
// llave anonima lea `profiles`, y con razon —seria la lista de usuarios de una
// plataforma de desaparecidos. El sitio hace la misma consulta en su servidor;
// esto replica ese paso.
//
// Se devuelve la sesion, nunca el correo: filtrarlo permitiria enumerar
// cuentas.

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ANON = process.env.SUPABASE_ANON_KEY;

// Mas estricto que el del chat: aqui se prueban contrasenas.
const intentos = new Map();
const MAX_INTENTOS = 8;
const VENTANA = 15 * 60_000;

function bloqueado(ip) {
  const ahora = Date.now();
  const previos = (intentos.get(ip) || []).filter((t) => ahora - t < VENTANA);
  intentos.set(ip, previos);
  return previos.length >= MAX_INTENTOS;
}

function apuntarFallo(ip) {
  const previos = intentos.get(ip) || [];
  previos.push(Date.now());
  intentos.set(ip, previos);
}

/// Devuelve el perfil del portador del token.
///
/// La app no puede leerlo por su cuenta: `profiles` no tiene politica RLS de
/// lectura para el propio usuario, porque el sitio siempre la consulta desde
/// su servidor. En vez de abrir esa tabla —que es la lista de usuarios de una
/// plataforma de desaparecidos— se resuelve aqui, validando antes el token.
async function manejarPerfil(req, res, cors) {
  const cabecera = req.headers.authorization || '';
  if (!cabecera.startsWith('Bearer ')) {
    return res.writeHead(401, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'sin_token' }));
  }
  const token = cabecera.slice(7);

  try {
    // El token se valida contra Supabase, no se decodifica a mano: firmarlo
    // es lo unico que prueba que la sesion es real.
    const quien = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: ANON, Authorization: `Bearer ${token}` },
    });
    if (!quien.ok) {
      const detalle = await quien.text().catch(() => '');
      console.log(`[perfil] token rechazado: ${quien.status} ${detalle.slice(0, 200)}`);
      return res.writeHead(401, { ...cors, 'Content-Type': 'application/json' })
        .end(JSON.stringify({ error: 'token_invalido' }));
    }
    const usuario = await quien.json();
    console.log(`[perfil] token valido, user_id=${usuario.id}`);

    const fila = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles`
      + `?select=user_id,username,avatar_url,bio,recovery_email,email_notifications`
      + `&user_id=eq.${encodeURIComponent(usuario.id)}&limit=1`,
      { headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}` } },
    );
    if (!fila.ok) {
      const detalle = await fila.text().catch(() => '');
      console.log(`[perfil] consulta fallo: ${fila.status} ${detalle.slice(0, 250)}`);
    }
    const datos = fila.ok ? await fila.json() : [];
    console.log(`[perfil] filas=${datos.length} username=${datos[0]?.username ?? '(ninguno)'}`);

    return res.writeHead(200, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify(datos[0] || null));
  } catch (err) {
    console.error('[perfil] excepcion:', err);
    return res.writeHead(500, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'interno' }));
  }
}

async function manejarLogin(req, res, cors, ip, datos) {
  if (!SUPABASE_URL || !SERVICE_ROLE || !ANON) {
    console.error('[auth] faltan variables de Supabase');
    return res.writeHead(500, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'sin_configurar' }));
  }

  if (bloqueado(ip)) {
    return res.writeHead(429, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'demasiados_intentos' }));
  }

  const usuario = String(datos.username || '').trim().toLowerCase();
  const clave = String(datos.password || '');

  if (!usuario || !clave) {
    return res.writeHead(400, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'faltan_datos' }));
  }

  try {
    // 1) usuario -> login_email, con service role (RLS no aplica).
    const busca = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles`
      + `?select=login_email&username_lower=eq.${encodeURIComponent(usuario)}`
      + '&limit=1',
      { headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}` } },
    );
    const filas = busca.ok ? await busca.json() : [];
    const correo = filas[0]?.login_email;

    // Mismo mensaje exista o no la cuenta: distinguirlos permite averiguar
    // que usuarios existen probando nombres.
    if (!correo) {
      apuntarFallo(ip);
      return res.writeHead(401, { ...cors, 'Content-Type': 'application/json' })
        .end(JSON.stringify({ error: 'credenciales_invalidas' }));
    }

    // 2) Login normal con la llave publica.
    const entrada = await fetch(
      `${SUPABASE_URL}/auth/v1/token?grant_type=password`,
      {
        method: 'POST',
        headers: { apikey: ANON, 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: correo, password: clave }),
      },
    );

    if (!entrada.ok) {
      apuntarFallo(ip);
      return res.writeHead(401, { ...cors, 'Content-Type': 'application/json' })
        .end(JSON.stringify({ error: 'credenciales_invalidas' }));
    }

    const sesion = await entrada.json();
    intentos.delete(ip);

    // Solo los tokens. El correo se queda aqui.
    return res.writeHead(200, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({
        access_token: sesion.access_token,
        refresh_token: sesion.refresh_token,
        expires_in: sesion.expires_in,
      }));
  } catch (err) {
    console.error('[auth] excepcion:', err);
    return res.writeHead(500, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'interno' }));
  }
}


// ── Publicar (post de comunidad o ficha de persona) ──────────────────────────
// La web escribe con service role desde su backend porque quito a proposito la
// escritura publica con `anon` tras sufrir abuso. Aqui se hace lo mismo: el
// cliente manda datos, el servidor decide que columnas se escriben.
//
// La lista blanca de campos no es formalidad: sin ella, cualquiera podria
// mandar `verified: true` o `moderation_status: "approved"` en el cuerpo y
// colar contenido como si lo hubiera revisado alguien.

const publicaciones = new Map();
const MAX_PUBLICA = 5;          // por usuario
const VENTANA_PUBLICA = 600_000; // en 10 minutos

function demasiadasPublicaciones(uid) {
  const ahora = Date.now();
  const previas = (publicaciones.get(uid) || [])
    .filter((t) => ahora - t < VENTANA_PUBLICA);
  if (previas.length >= MAX_PUBLICA) return true;
  previas.push(ahora);
  publicaciones.set(uid, previas);
  return false;
}

const TIPOS_POST = ['necesito', 'ofrezco', 'rescate', 'medico', 'caravana',
  'identificar', 'info'];
const ESTADOS_PERSONA = ['por_localizar', 'hospitalizado', 'localizado',
  'fallecido'];

function texto(v, max) {
  return typeof v === 'string' ? v.trim().slice(0, max) : '';
}

async function manejarPublicar(req, res, cors, datos) {
  const cabecera = req.headers.authorization || '';
  if (!cabecera.startsWith('Bearer ')) {
    return res.writeHead(401, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'sin_sesion' }));
  }

  let uid;
  try {
    const quien = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: ANON, Authorization: cabecera },
    });
    if (!quien.ok) {
      return res.writeHead(401, { ...cors, 'Content-Type': 'application/json' })
        .end(JSON.stringify({ error: 'token_invalido' }));
    }
    uid = (await quien.json()).id;
  } catch {
    return res.writeHead(500, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'interno' }));
  }

  if (demasiadasPublicaciones(uid)) {
    return res.writeHead(429, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'demasiadas_publicaciones' }));
  }

  const pais = ['co', 've'].includes(datos.country) ? datos.country : null;
  if (!pais) {
    return res.writeHead(400, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'pais_invalido' }));
  }

  const autor = texto(datos.author_name, 80) || 'Anonimo';
  let tabla;
  let fila;

  if (datos.tipo === 'post') {
    const cuerpo = texto(datos.body, 2000);
    if (cuerpo.length < 10) {
      return res.writeHead(400, { ...cors, 'Content-Type': 'application/json' })
        .end(JSON.stringify({ error: 'cuerpo_corto' }));
    }
    tabla = 'posts';
    fila = {
      country: pais,
      type: TIPOS_POST.includes(datos.type) ? datos.type : 'info',
      body: cuerpo,
      estado: texto(datos.estado, 80) || null,
      location_text: texto(datos.location_text, 160),
      photo_url: null,
      link_url: texto(datos.link_url, 400) || null,
      author_name: autor,
      contact_phone: texto(datos.contact_phone, 40) || null,
      reactions: { apoyo: 0, corazon: 0, hecho: 0 },
      user_id: uid,
    };
  } else if (datos.tipo === 'persona') {
    const nombre = texto(datos.first_name, 90);
    if (nombre.length < 2) {
      return res.writeHead(400, { ...cors, 'Content-Type': 'application/json' })
        .end(JSON.stringify({ error: 'nombre_corto' }));
    }
    const edad = Number.isInteger(datos.age) && datos.age > 0 && datos.age < 120
      ? datos.age
      : null;
    tabla = 'persons';
    fila = {
      country: pais,
      first_name: nombre,
      last_name: texto(datos.last_name, 90),
      cedula: texto(datos.cedula, 40) || null,
      age: edad,
      gender: texto(datos.gender, 30) || null,
      estado: texto(datos.estado, 80) || null,
      location_text: texto(datos.location_text, 200),
      description: texto(datos.description, 1500),
      photo_url: null,
      status: ESTADOS_PERSONA.includes(datos.status)
        ? datos.status
        : 'por_localizar',
      is_unidentified: false,
      cause: 'desastre',
      contact_name: texto(datos.contact_name, 90) || null,
      contact_phone: texto(datos.contact_phone, 40) || null,
      contact_email: texto(datos.contact_email, 120) || null,
      user_id: uid,
    };
  } else {
    return res.writeHead(400, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'tipo_invalido' }));
  }

  try {
    const alta = await fetch(`${SUPABASE_URL}/rest/v1/${tabla}`, {
      method: 'POST',
      headers: {
        apikey: SERVICE_ROLE,
        Authorization: `Bearer ${SERVICE_ROLE}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      body: JSON.stringify(fila),
    });

    if (!alta.ok) {
      const detalle = await alta.text().catch(() => '');
      console.error(`[publicar] ${tabla} fallo:`, alta.status, detalle.slice(0, 300));
      return res.writeHead(502, { ...cors, 'Content-Type': 'application/json' })
        .end(JSON.stringify({ error: 'no_guardado' }));
    }

    const creada = (await alta.json())[0];
    console.log(`[publicar] ${tabla} id=${creada?.id} uid=${uid}`);
    return res.writeHead(200, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ id: creada?.id }));
  } catch (err) {
    console.error('[publicar] excepcion:', err);
    return res.writeHead(500, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'interno' }));
  }
}

// ── Servidor ─────────────────────────────────────────────────────────────────

const servidor = http.createServer(async (req, res) => {
  if (req.method === 'GET') console.log(`[req] GET ${req.url}`);
  const cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  };

  if (req.method === 'OPTIONS') return res.writeHead(204, cors).end();
  if (req.method === 'GET') {
    if ((req.url || '').startsWith('/auth/profile')) {
      return manejarPerfil(req, res, cors);
    }
    return res.writeHead(200, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ ok: true, modelo: MODELO }));
  }
  if (req.method !== 'POST') {
    return res.writeHead(405, cors).end();
  }

  const ip = (req.headers['x-forwarded-for'] || '').split(',')[0].trim()
    || req.socket.remoteAddress;

  console.log(`[req] ${req.method} ${req.url}`);

  if (excedido(ip)) {
    return res.writeHead(429, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'demasiadas_consultas' }));
  }

  let cuerpo = '';
  for await (const trozo of req) {
    cuerpo += trozo;
    // Corta payloads absurdos antes de gastar memoria en ellos.
    if (cuerpo.length > 60_000) {
      return res.writeHead(413, cors).end();
    }
  }

  let datos;
  try {
    datos = JSON.parse(cuerpo || '{}');
  } catch {
    return res.writeHead(400, cors).end();
  }

  // nginx enruta /api/app-auth aqui como /auth.
  if ((req.url || '').startsWith('/auth/publicar')) {
    return manejarPublicar(req, res, cors, datos);
  }
  if ((req.url || '').startsWith('/auth')) {
    return manejarLogin(req, res, cors, ip, datos);
  }

  const mensajes = Array.isArray(datos.messages) ? datos.messages : [];
  if (mensajes.length === 0 || mensajes.length > 25) {
    return res.writeHead(400, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ error: 'mensajes_invalidos' }));
  }

  // Se descarta cualquier 'system' que mande el cliente: el prompt lo pone el
  // servidor y no se negocia.
  const limpios = mensajes
    .filter((m) => m && typeof m.content === 'string'
      && ['user', 'assistant'].includes(m.role))
    .map((m) => ({ role: m.role, content: m.content.slice(0, 4000) }));

  const contexto = typeof datos.context === 'string'
    ? datos.context.slice(0, 2000)
    : '';

  try {
    const upstream = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: MODELO,
        stream: true,
        temperature: 0.3,
        max_tokens: 600,
        messages: [
          { role: 'system', content: promptSistema(contexto) },
          ...limpios,
        ],
      }),
    });

    if (!upstream.ok) {
      const detalle = await upstream.text().catch(() => '');
      console.error('[asistente] OpenAI respondio', upstream.status, detalle);
      return res.writeHead(502, { ...cors, 'Content-Type': 'application/json' })
        .end(JSON.stringify({ error: 'upstream' }));
    }

    // Se retransmite el SSE tal cual, para que el cliente pinte la respuesta
    // segun llega en vez de esperar al final.
    res.writeHead(200, {
      ...cors,
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    });

    for await (const trozo of upstream.body) {
      res.write(trozo);
    }
    res.end();
  } catch (err) {
    console.error('[asistente] excepcion:', err);
    if (!res.headersSent) {
      res.writeHead(500, { ...cors, 'Content-Type': 'application/json' })
        .end(JSON.stringify({ error: 'interno' }));
    } else {
      res.end();
    }
  }
});

servidor.listen(PUERTO, '127.0.0.1', () => {
  console.log(`[asistente] escuchando en 127.0.0.1:${PUERTO} · modelo ${MODELO}`);
});
