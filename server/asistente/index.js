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

// ── Servidor ─────────────────────────────────────────────────────────────────

const servidor = http.createServer(async (req, res) => {
  const cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  if (req.method === 'OPTIONS') return res.writeHead(204, cors).end();
  if (req.method === 'GET') {
    return res.writeHead(200, { ...cors, 'Content-Type': 'application/json' })
      .end(JSON.stringify({ ok: true, modelo: MODELO }));
  }
  if (req.method !== 'POST') {
    return res.writeHead(405, cors).end();
  }

  const ip = (req.headers['x-forwarded-for'] || '').split(',')[0].trim()
    || req.socket.remoteAddress;

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
