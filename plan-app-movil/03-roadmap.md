# 3. Roadmap por fases

0. **Cimientos** — repo Flutter nuevo y separado (no monorepo: toolchains muy
   distintos). `supabase_flutter` apuntando al mismo proyecto Supabase.
   Riverpod (estado), `go_router` con deep linking configurado desde el
   inicio (los enlaces de gestión lo necesitan desde la Fase 2).
1. **Solo lectura** — Se busca, ¿La reconoces?, mapa, ayuda, hospitales,
   caravanas, comunidad. Sin escritura ni anti-bot todavía. Ya es útil
   instalada en una zona con mala señal.
2. **Escritura** — registrar persona/reporte, votar, comentar, publicar en
   comunidad, subir fotos. Aquí entran App Attest/Play Integrity y la Edge
   Function de validación (ver [arquitectura](01-arquitectura.md)).
3. **Cuentas** — login/registro con Supabase Auth, perfil, avatar,
   "voluntario digital" público (`/perfil`, `/configuracion`,
   `/perfil/publico/[username]` de la web).
4. **Nativo real** — push notifications (FCM/APNs) para avisos de cambio de
   estado en una persona seguida (mejora que la web no puede dar bien);
   cache offline con aviso de antigüedad (ver la nota de consistencia en
   [arquitectura](01-arquitectura.md)).
5. **Publicación** — solo cuando se decida: cuenta Apple Developer de pago,
   revisión de tiendas (Apple es más estricta con contenido generado por
   usuarios sin pre-moderación — documentar que `/admin` ya modera en la web).

Ver también las decisiones abiertas listadas en el [README](README.md).
