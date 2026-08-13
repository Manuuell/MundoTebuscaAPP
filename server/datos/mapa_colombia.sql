-- Mapa de Colombia: hospitales de referencia y coordenadas de acopio.
-- Generado el 2026-08-13. Ejecutar en el editor SQL de Supabase.
--
-- La PARTE 1 es solo para la app: crea `hospitals_osm`, una tabla que el
-- codigo de la web no nombra en ningun sitio. Meter esto en `hospitals`
-- lo publicaria en elmundotebusca.com, porque su listado no filtra por
-- `verified` (src/lib/data.ts:4004).
--
-- La PARTE 2 sí toca datos que la web ya muestra. Va aparte a proposito:
-- se puede ejecutar solo la 1 y dejar la 2 para cuando se decida.


-- ─── PARTE 1: hospitales, solo app ────────────────────────────────────

begin;

create table if not exists hospitals_osm (
  id            uuid primary key,
  name          text not null,
  estado        text,
  location_text text,
  lat           double precision not null,
  lng           double precision not null,
  contact_phone text,
  -- OSM marca con `emergency=yes` los centros con servicio de urgencias.
  -- Es lo unico parecido a una capacidad que trae la fuente, y despues de
  -- un sismo es justo lo que importa. No dice si hoy estan recibiendo.
  has_emergency boolean not null default false,
  country       text not null default 'co',
  -- Identificador del objeto en OpenStreetMap, para poder volver a la
  -- fuente de cualquier fila y corregirla alli si esta mal.
  osm_ref       text,
  updated_at    timestamptz not null default now()
);

create index if not exists hospitals_osm_country_idx on hospitals_osm (country);

-- Sin RLS, PostgREST deja a la anon key escribir en una tabla nueva. Se
-- enciende y solo se abre la lectura: la app lee, nadie mas escribe.
alter table hospitals_osm enable row level security;
drop policy if exists "public_read_hospitals_osm" on hospitals_osm;
create policy "public_read_hospitals_osm" on hospitals_osm
  for select using (true);

-- El id es un uuid5 del identificador OSM: reejecutar no duplica nada.
insert into hospitals_osm
  (id, name, estado, location_text, lat, lng, contact_phone,
   has_emergency, country, osm_ref)
values
  ('ac9406a5-eed3-5281-bb4f-8295b2cd6afc', 'IPS ESE Hospital San Vicente de Paúl', 'Risaralda', null, 5.298254, -75.883309, null, true, 'co', 'node/3511596005'),
  ('bf34e802-2050-5b1c-a879-6bcc8a7ac21c', 'Unidad intermedia Centro ESE Salud Pereira', 'Risaralda', 'Carrera 7 #40, Pereira', 4.817173, -75.7123, null, true, 'co', 'node/10782655735'),
  ('89bb0d03-a692-58bc-a772-2c878f60b1dd', 'Hospital Universitario Clínica San Rafael', 'Risaralda', 'Calle 11 24-30, Pereira', 4.798689, -75.6894, null, false, 'co', 'node/10783326828'),
  ('9e0cf434-be95-51b3-852d-e7e9c7edf7fc', 'IPS ESE Hospital San Vicente de Paúl', 'Risaralda', null, 4.879498, -75.62473, null, true, 'co', 'way/347972748'),
  ('f1951843-3c98-545e-8c7a-c198cfda3057', 'IPS ESE Hospital San José', 'Risaralda', 'Calle 5 CARRERA 13, Belén de Umbría', 5.201854, -75.870966, null, true, 'co', 'way/375704155'),
  ('e7ad07eb-6753-5283-8d82-339824e71255', 'IPS ESE Hospital San Vicente de Paúl', 'Risaralda', null, 5.105199, -75.943105, null, true, 'co', 'way/376737021'),
  ('bf003997-ce1f-5f3b-a963-9f5a290eecd4', 'Hospital San José', 'Risaralda', null, 4.94027, -75.737841, null, false, 'co', 'way/409611080'),
  ('33723ae1-c3e0-5ba2-ad90-39b4545acb66', 'IPS ESE Hospital Santa Ana', 'Risaralda', null, 5.315839, -75.796563, null, true, 'co', 'way/577791962'),
  ('e80cac25-a641-5e92-bd21-0585470283a2', 'Hospital Mental Universitario de Risaralda', 'Risaralda', null, 4.811878, -75.754964, null, false, 'co', 'way/946551606'),
  ('a1d33baf-762e-5433-8cb2-6a0ca4a5dc1b', 'ESE Hospital Cristo Rey', 'Risaralda', null, 4.951315, -75.959192, null, true, 'co', 'way/1049151079'),
  ('382c4540-f829-55aa-b85e-7bdb052fccf9', 'ESE Hospital San José', 'Risaralda', null, 5.002188, -76.002845, null, true, 'co', 'way/1049776584'),
  ('2a459d34-c4b5-520c-81eb-c506a0572eff', 'Hospital San Rafaél', 'Risaralda', null, 5.219612, -76.031989, null, false, 'co', 'way/1050668499'),
  ('346d42bb-ecfc-5271-b668-f2b67f246ca8', 'IPS ESE Hospital San Vicente de Paul', 'Risaralda', null, 5.071481, -75.963288, null, true, 'co', 'way/1050896391'),
  ('463a3dd8-2849-595f-aa29-5c8655458a73', 'Clínica Santa Clara', 'Risaralda', null, 4.865615, -75.622563, null, false, 'co', 'way/1182584186'),
  ('cd011662-8658-58a0-8ef8-dbe5505d41ad', 'Urgencias Clinica San rafael Sede Pinares', 'Risaralda', 'Calle 12 18 - 50, Pereira', 4.803822, -75.689802, null, true, 'co', 'way/1321867155'),
  ('c056329f-ee52-5ed4-8ffd-b1b808463e49', 'Urgencias Clinica Los nevados', 'Risaralda', 'Calle 20 5 - 21, Pereira', 4.816204, -75.694929, null, true, 'co', 'way/1321873693'),
  ('af17ce55-2518-522c-99d9-9b0477770584', 'Hospital', 'Valle del Cauca', null, 3.255657, -77.417808, null, false, 'co', 'node/1180767035'),
  ('7a0d1ca4-95cd-5b23-8bdc-20f6fe1b22b8', 'Centro Médico Familiar La Flora', 'Valle del Cauca', null, 3.48458, -76.515444, '+57 6026087000', false, 'co', 'node/1230821143'),
  ('000ac053-f17e-5749-8344-ca013986b74e', 'CLÍNICA INTERNACIONAL DEL OZONO - PORTAL DA SAUDE I.P.S.', 'Valle del Cauca', null, 3.475894, -76.523988, '+57 2 6838908', false, 'co', 'node/1230822758'),
  ('224a7bfe-f590-51d4-b26b-d680490d3048', 'Centro Medico Burgos', 'Valle del Cauca', null, 3.452433, -76.493878, '+57 2 4433973', false, 'co', 'node/1230823307'),
  ('b02cc934-8cc8-59a8-b721-85880c5ee858', 'CLÍNICA DE OFTALMOLOGÍA DE CALI S.A. SEDE SANTA MÓNICA', 'Valle del Cauca', null, 3.468199, -76.529793, '+57 2 5520890', false, 'co', 'node/1230823712'),
  ('b2f1e158-7bf6-5370-b700-93ab70a794b6', 'CLÍNICA DE ALERGIAS Y TERAPÉUTICAS ALTERNATIVAS FUNDALERGIAS LTDA', 'Valle del Cauca', null, 3.434568, -76.546119, '+57 2 5583737', false, 'co', 'node/1230824649'),
  ('d36f02f4-44b7-5ec5-8114-ccf384d965dd', 'CLÍNICA SANTIAGO DE CALI', 'Valle del Cauca', null, 3.461728, -76.527743, '+57 2 6600303', false, 'co', 'node/1230825005'),
  ('e2ee4c77-951e-5889-bea8-a7375c9446b8', 'Centro Medico Ip Salud Ltda', 'Valle del Cauca', null, 3.418065, -76.494097, '+57 2 4365309', false, 'co', 'node/1230825278'),
  ('96cbff01-2625-5bb2-a03d-30b01cfa4a86', 'CENTRO MEDICO IMBANACO CMI SEDE No.7', 'Valle del Cauca', null, 3.419977, -76.544927, '+57 2 6821000', false, 'co', 'node/1230825929'),
  ('6d3cf779-5e6e-5229-b14b-ef2f16b27133', 'CLÍNICA NUEVA SONRISA ALFONSO LÓPEZ E.U.', 'Valle del Cauca', null, 3.464894, -76.48371, '+57 2 6621452', false, 'co', 'node/1230826180'),
  ('2959071d-188e-59a8-8235-75f31f0dc218', 'CLÍNICA BASILIA S.A.', 'Valle del Cauca', null, 3.419116, -76.543916, '+57 2 5242202', false, 'co', 'node/1230826306'),
  ('b34cf11c-8577-5652-b221-5f51b6331bb9', 'Centro Medico Familiar Pasoancho Cruz Blanca Eps S.a.', 'Valle del Cauca', null, 3.409517, -76.534227, '+57 2 6087000 Ext: 2303', false, 'co', 'node/1230827046'),
  ('109a3648-8410-5541-9d28-451ec7261da2', 'CLÍNICA LOS ANDES S.A.', 'Valle del Cauca', null, 3.418711, -76.54165, '+57 2 6812424', false, 'co', 'node/1230827660'),
  ('fa30bdca-a2b8-5a62-8618-f50ef2d1ad51', 'Centro Medico Ocupacional Santa Clara Limitada', 'Valle del Cauca', null, 3.462841, -76.523218, '+57 2 6604489', false, 'co', 'node/1230827795'),
  ('5fac6fc7-b5f7-5914-9fca-658a2404b47d', 'HOSPITAL JOAQUÍN PAZ BORRERO', 'Valle del Cauca', 'Carrera 7A Bis 7a-00, Comuna 7', 3.465272, -76.482211, '6024184747', true, 'co', 'node/1230829026'),
  ('238715aa-43c2-5f6e-ab42-27857faf9d68', 'Centro Medico Ocupacional Porvenir Ltda', 'Valle del Cauca', null, 3.46959, -76.522987, '+57 2 6806685', false, 'co', 'node/1230829291'),
  ('1dc5defb-af15-530e-b964-5d014ae94509', 'CLÍNICA ORIENTE LTDA SEDE VILLACOLOMBIA', 'Valle del Cauca', null, 3.447481, -76.499071, '+57 2 4480315', false, 'co', 'node/1230829559'),
  ('e591af05-cc3f-5b46-9fd0-398a5d026405', 'CLÍNICA DE OFTALMOLOGÍA DE CALI S.A. SEDE EL PRADO', 'Valle del Cauca', null, 3.435861, -76.517025, '+57 2 5520890', false, 'co', 'node/1230829812'),
  ('e2fad314-f6ef-5ba6-bc8a-475cb8d6d0ef', 'Centro Medico Cemed', 'Valle del Cauca', null, 3.444918, -76.502487, '+57 2 6800662', false, 'co', 'node/1230831858'),
  ('2cbc2619-56ff-5c8f-8653-28c23f0bce7a', 'CLÍNICA EXCELLENCE S.A.', 'Valle del Cauca', null, 3.364166, -76.534213, '+57 2 3320234', false, 'co', 'node/1230832410'),
  ('dd392c87-b04b-5b93-9c0f-bb3c61f04ffc', 'CLÍNICA CANDELARIA SIES SALUD', 'Valle del Cauca', null, 3.460927, -76.527693, '+57 3133490010', false, 'co', 'node/1230832474'),
  ('471cc525-cf55-5458-8b45-7b62663e91c0', 'CLÍNICA NUEVA SONRISA S.A. CLINIDENT', 'Valle del Cauca', null, 3.384952, -76.539301, '+57 2 3147740', false, 'co', 'node/1230832620'),
  ('043e8c0c-8bdb-5902-8f21-0618f6b50cf6', 'CENTRO MEDICO SAN NICOLÁS Y CIA', 'Valle del Cauca', null, 3.453694, -76.527369, '+57 2 8821208', false, 'co', 'node/1230832745'),
  ('dc3768e4-5557-56de-9edc-0168e2aa2e8d', 'Hospital Departamental San Antonio', 'Valle del Cauca', 'Carrera 10 9-519, Roldanillo', 4.404619, -76.152114, null, true, 'co', 'node/2362600645'),
  ('83918bf0-9ef3-567c-b1de-605ab4accb65', 'Hospital La Buena Esperanza', 'Valle del Cauca', null, 3.581488, -76.491732, null, true, 'co', 'node/2409031676'),
  ('c1964ca6-01d6-510e-a47c-2c6d09f99869', 'Centro Médico Versalles', 'Valle del Cauca', null, 3.58299, -76.49018, null, false, 'co', 'node/2411195210'),
  ('98b748cd-9e99-577a-902b-725064a634d7', 'Clínica Santa Isabel', 'Valle del Cauca', null, 3.58192, -76.491523, null, true, 'co', 'node/2411195213'),
  ('9883ccf4-39d5-5848-b61f-2b11f8c8e96e', 'SOS Comfandi', 'Valle del Cauca', null, 3.581812, -76.487203, null, true, 'co', 'node/2411195361'),
  ('4347d4fe-11af-58d9-9f0d-413136c78714', 'Centro Médico de Yumbo', 'Valle del Cauca', null, 3.58148, -76.491583, null, false, 'co', 'node/2411195400'),
  ('853b5cf2-a2f4-5221-8760-b71a4afaef93', 'IPS Clínica Guadalajara', 'Valle del Cauca', null, 3.89534, -76.304413, null, true, 'co', 'node/2440856827'),
  ('98bcd706-50d2-58a6-9131-62357aa13480', 'Hospital Materno Infantil', 'Valle del Cauca', null, 3.699761, -76.442291, null, true, 'co', 'node/2727468795'),
  ('28d509c6-be62-54b7-abe0-2fc888622c41', 'Hospital Santa Ana de los Caballeros', 'Valle del Cauca', null, 4.798572, -75.996733, null, true, 'co', 'node/3100442923'),
  ('04e2b1be-6910-5678-9cab-827389e55e7c', 'Hospital Santa Margarita', 'Valle del Cauca', 'Carrera 7 Calle 5, La Cumbre', 3.651255, -76.569241, '+57(2)2459200', true, 'co', 'node/4192511008'),
  ('de762d89-4015-59a8-ab1d-baa596a891d7', 'Hospital Santa Ana', 'Valle del Cauca', null, 4.339997, -76.184174, null, false, 'co', 'node/4241540342'),
  ('ce534572-6e7d-5991-aa2f-b5cf107f0f3e', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud Bosques de Maracaibo', 'Valle del Cauca', null, 4.104598, -76.205828, null, false, 'co', 'node/4392703458'),
  ('764d5d66-1fc6-5bce-8de8-0c920e257f63', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud La Independencia', 'Valle del Cauca', null, 4.099032, -76.203664, null, false, 'co', 'node/4392703459'),
  ('1798fca8-ce73-5fae-b8af-dfa2d9eb46df', 'Hospital benjamin barney', 'Valle del Cauca', null, 3.321716, -76.226403, null, false, 'co', 'node/4728698694'),
  ('4562fedf-10ca-5bc7-967f-ad517d1020cb', 'Clínica de Fracturas', 'Valle del Cauca', null, 3.895739, -76.303023, null, false, 'co', 'node/4785270521'),
  ('7d571360-2251-5d21-84b9-09a354bdf422', 'Hospital centenario sevilla', 'Valle del Cauca', 'Calle 56 43', 4.26886, -75.928151, '+57 2 2196013', false, 'co', 'node/4789273025'),
  ('63f577ab-e179-5186-b4cf-9b40ec9e333a', 'Centro Médico Jamundí', 'Valle del Cauca', 'Carrera 11 13-15, Jamundí, Valle del Cauca, Jamundi', 3.263753, -76.539291, null, true, 'co', 'node/4872201175'),
  ('4ca871c0-1091-5ebe-bd11-fc96bb9162aa', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud San Rafael', 'Valle del Cauca', null, 4.094305, -76.041572, null, false, 'co', 'node/5489847572'),
  ('066408f3-0d2a-5e8f-af4f-37fb2258a604', 'IPS ESE Hospital Municipal Ruben Cruz Velez - Puesto de Salud La Santa Cruz', 'Valle del Cauca', null, 4.089959, -76.17226, null, false, 'co', 'node/5489850294'),
  ('dcc60e30-6112-5290-9bb0-9ad556081b37', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud Farfán', 'Valle del Cauca', null, 4.092041, -76.215957, null, false, 'co', 'node/5524097936'),
  ('df842897-49a1-5594-be24-053421cc2e29', 'IPS ESE Hospital Municipal Ruben Cruz Velez - Puesto de Salud Victoria', 'Valle del Cauca', null, 4.080146, -76.190687, null, false, 'co', 'node/5524107081'),
  ('6166234a-7cdb-5fbd-85bc-b81a626b4afb', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud Portales del Río', 'Valle del Cauca', null, 4.104036, -76.198582, null, false, 'co', 'node/5534399544'),
  ('025d88b0-a95e-5e5b-8a94-4b3376dc0cb1', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud San Antonio', 'Valle del Cauca', null, 4.095071, -76.194979, null, false, 'co', 'node/5534410759'),
  ('b7685616-049b-54b0-9272-7a02befa5251', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud Villa Colombia', 'Valle del Cauca', null, 4.098871, -76.200931, null, false, 'co', 'node/5534460890'),
  ('cb91848f-d9e6-556c-a11f-74ba46dc9620', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud Nariño', 'Valle del Cauca', null, 4.094665, -76.237223, null, false, 'co', 'node/5534485178'),
  ('041574b4-3562-52c6-b790-9b7ec52d0e31', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud Tres Esquinas', 'Valle del Cauca', null, 4.11807, -76.220566, null, false, 'co', 'node/5534492989'),
  ('6f295fb6-f034-5514-8ebf-d18367eb7ccf', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud La Marina', 'Valle del Cauca', null, 4.045287, -76.108733, null, false, 'co', 'node/5534524761'),
  ('405f274a-d3e3-5aaa-ada1-db8afed12c9f', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud Aguaclara', 'Valle del Cauca', null, 4.113768, -76.195153, null, false, 'co', 'node/5534560582'),
  ('9f65cc23-e44b-5650-a02f-5181fb26b4d3', 'IPS Clínica Médico Quirúrgica Alvernia', 'Valle del Cauca', null, 4.08297, -76.189932, null, true, 'co', 'node/6215071032'),
  ('636e8a90-c4c9-5515-8281-b16bc3e135ae', 'Hospital ortopédico', 'Valle del Cauca', 'Calle 5E', 3.419681, -76.543692, null, false, 'co', 'node/6505200485'),
  ('221bfd09-96f5-566e-8c96-e52a82d1e49d', 'Hospital Luis Ablanque de la Plata', 'Valle del Cauca', 'Calle 5 4-04, Buenaventura', 3.882234, -77.064865, null, true, 'co', 'node/8060549949'),
  ('e1c23688-a6d2-5cfe-a379-eeb2be9469b4', 'Hospital de Candelaria', 'Valle del Cauca', null, 3.411688, -76.3485, null, false, 'co', 'node/9382649467'),
  ('ba78cf6d-44f4-5dac-bcad-20a1c7ba4cd6', 'IPS ESE Hospital Departamental Tomás Uribe Uribe', 'Valle del Cauca', null, 4.081945, -76.188091, null, true, 'co', 'way/109287204'),
  ('8508fa9c-ce09-52e5-9196-794744b21f2f', 'IPS Clínica Fundacion ESENSA - Cali', 'Valle del Cauca', null, 3.415609, -76.538017, null, false, 'co', 'way/207051972'),
  ('35768b2f-3c2e-53ee-8a4c-5b800446e739', 'IPS Fundacion Hospital San José de Buga', 'Valle del Cauca', null, 3.906295, -76.292163, null, true, 'co', 'way/236009721'),
  ('6d9d8476-b843-5c9e-ba99-27b4a4cf0a58', 'IPS ESE Hospital Municipal San Roque', 'Valle del Cauca', null, 3.764893, -76.335496, null, true, 'co', 'way/236349236'),
  ('59e53e70-348c-5483-aa13-828ddcf9d59a', 'IPS Clínica Urgencias Médicas S.A.S', 'Valle del Cauca', null, 3.900111, -76.309412, null, true, 'co', 'way/238182200'),
  ('d4ef283f-56b9-58e2-b6ed-a1d27c77dddd', 'IPS ESE Hospital Local de Yotoco', 'Valle del Cauca', 'Calle 5 4 - 25', 3.861648, -76.384914, null, true, 'co', 'way/239020181'),
  ('928adb77-2f64-5fac-873a-22d7c1eb4a99', 'IPS Clínica Mariangel - Dumian Medical', 'Valle del Cauca', null, 4.083538, -76.185354, null, true, 'co', 'way/267281485'),
  ('70b5f234-f668-528d-97c1-7acf796f7e53', 'IPS ESE Hospital Santander', 'Valle del Cauca', null, 4.331305, -75.823422, null, true, 'co', 'way/310597375'),
  ('d16200dd-8b45-5383-b0ac-333b5eae25b3', 'IPS ESE Hospital Divino Niño', 'Valle del Cauca', null, 3.915035, -76.296039, null, true, 'co', 'way/344328138'),
  ('5ef2ee3a-ae3f-5d3a-b8c6-7bda8a1317f0', 'Clínica colombia', 'Valle del Cauca', 'Carrera 46 9C -58', 3.414906, -76.538092, '+57 602 3850285', false, 'co', 'way/356112630'),
  ('1f41da54-c166-5085-a53c-70547b83b5d6', 'IPS ESE Hospital San Jorge', 'Valle del Cauca', null, 3.931363, -76.481948, null, true, 'co', 'way/358953001'),
  ('4aabb367-9fbc-5b32-8f4c-df0384295a81', 'Centro Médico María Gay Tibau La Nave', 'Valle del Cauca', null, 3.423551, -76.552377, null, false, 'co', 'way/387033090'),
  ('7cd1f95b-a0ce-53bb-9878-6fc5b3fd8665', 'Hospital San Roque', 'Valle del Cauca', null, 3.417359, -76.245268, null, true, 'co', 'way/447107733'),
  ('bdfc1acb-0a46-5955-a2b5-01833f0f9d9f', 'IPS ESE Hospital San Vicente de Paúl', 'Valle del Cauca', null, 4.676211, -75.77681, null, true, 'co', 'way/447130363'),
  ('26a83921-4037-503a-b177-12f493fd93aa', 'ESE Hospital Raul Orejuela Bueno - IPS Centro de Salud Rozo', 'Valle del Cauca', null, 3.616854, -76.390384, null, false, 'co', 'way/470297821'),
  ('df23ae46-90df-58ff-af26-7a5629eee8ba', 'ESE Hospital Raul Orjuela Bueno - Puesto de Salud Matapalo', 'Valle del Cauca', null, 3.584, -76.425665, null, false, 'co', 'way/470307685'),
  ('079316ee-4b96-5190-8ed7-ae96d551279b', 'IPS ESE Hospital Departamental San Rafael', 'Valle del Cauca', null, 4.390009, -76.07217, null, true, 'co', 'way/507831538'),
  ('db6c5d19-e5ff-5990-9ab6-09aec73197bf', 'IPS ESE Hospital Departamental San Rafael - Centro de Salud La Paila', 'Valle del Cauca', null, 4.317875, -76.071531, null, false, 'co', 'way/507841278'),
  ('2e272bd1-abf0-5b6c-901c-ff54336bf00d', 'ESE Hospital Ulpiano Tascón Quintero', 'Valle del Cauca', null, 3.993864, -76.227783, null, true, 'co', 'way/509345707'),
  ('13721245-2e45-5411-ad06-3498f8214015', 'IPS ESE Hospital San Vicente Ferrer', 'Valle del Cauca', null, 4.169822, -76.16662, null, true, 'co', 'way/510335918'),
  ('d8c5019a-9d99-5330-80dd-1cd8f9c3a276', 'Clínica Palma Real', 'Valle del Cauca', 'Carrera 28 44-35, Palmira', 3.540271, -76.297496, null, true, 'co', 'way/552954227'),
  ('eaf5da70-ca53-5adb-9709-622f4f908ea5', 'Hospital Carlos Holmes Trujillo', 'Valle del Cauca', 'Calle 72U', 3.418731, -76.494096, null, true, 'co', 'way/563569237'),
  ('72ce5f05-e511-5644-a1a5-181583bb4c2c', 'IPS ESE Hospital San Bernabé', 'Valle del Cauca', null, 4.213032, -76.157824, null, true, 'co', 'way/568514076'),
  ('02d19de1-051a-5fc1-b404-9611be153f7b', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Puesto de Salud San Pedro Claver', 'Valle del Cauca', null, 4.091961, -76.210667, null, false, 'co', 'way/571102735'),
  ('1f62e5ca-1d22-5160-b8f9-87a016128a0a', 'Centro Medico San José', 'Valle del Cauca', 'Calle 7, Cali', 3.430577, -76.537576, null, false, 'co', 'way/572129805'),
  ('c4b20cb2-059c-5d55-bec1-a0f8a89d0c32', 'Clínica Cristo Rey', 'Valle del Cauca', 'Avenida 4 Norte', 3.462523, -76.527051, null, false, 'co', 'way/572197651'),
  ('072f2092-d24a-5d58-ad53-2b5c2f172ec8', 'Clínica Compostela', 'Valle del Cauca', 'Avenida 4 Norte', 3.461674, -76.527693, null, false, 'co', 'way/572197652'),
  ('ccdd1449-80a7-5a70-a98e-f23c1e99aec0', 'Hospital Sagrado Corazón de Jesús', 'Valle del Cauca', null, 4.751586, -75.903157, null, true, 'co', 'way/575720026'),
  ('805e5bc7-4e5e-5c36-bacd-37874266e113', 'IPS Clínica San Francisco - Únidad de Salud Mental', 'Valle del Cauca', null, 4.083811, -76.190981, null, true, 'co', 'way/576483085'),
  ('1207852f-60bc-5bfb-b75b-9c998b2a03ed', 'IPS Clínica San Francisco - Torre Principal', 'Valle del Cauca', null, 4.083713, -76.19045, null, true, 'co', 'way/576483087'),
  ('5f73cc7d-33ef-5adf-8797-0ab9ca577550', 'IPS Clínica San Francisco - Torre Consulta Externa', 'Valle del Cauca', null, 4.083645, -76.191021, null, false, 'co', 'way/576483089'),
  ('cb076fb8-aa12-5a97-b8d2-8daaa5ea45e9', 'IPS ESE Hospital Municipal Rubén Cruz Vélez - Sede Principal', 'Valle del Cauca', null, 4.092092, -76.203091, null, true, 'co', 'way/577266335'),
  ('f4dad3d4-5b0a-56b4-9661-aa2e8ed3e144', 'IPS Clínica Oriente', 'Valle del Cauca', null, 4.084976, -76.192415, null, true, 'co', 'way/577319946'),
  ('e8ea620e-0ebc-5cdd-a248-1ed86dec2944', 'IPS ESE Hospital San Rafael - Puesto de Salud Villanueva', 'Valle del Cauca', null, 4.96981, -76.038925, null, false, 'co', 'way/577568262'),
  ('3bd7b6b4-0d6e-5c91-93fe-0704c50aa4d8', 'Hospital Raul Orejuela Bueno', 'Valle del Cauca', '39-51 carrera 29, Palmira', 3.53636, -76.298429, null, true, 'co', 'way/615073077'),
  ('ffadd8a7-88d3-54ed-b6d2-73298a1b9965', 'Clínica Sebastian de Belalcazar', 'Valle del Cauca', 'Avenida 4 Norte 7N - 81', 3.454823, -76.53719, null, true, 'co', 'way/626953471'),
  ('65cc40b0-4349-5cd3-8444-e30ca0f283d7', 'IPS ESE Hospital Gonzalo Contreras', 'Valle del Cauca', null, 4.53714, -76.102965, null, true, 'co', 'way/674543456'),
  ('2d449c8e-6584-5745-b67d-b3eea8d69aea', 'IPS ESE Hospital Nuestra Señora de los Santos', 'Valle del Cauca', null, 4.52537, -76.037994, null, true, 'co', 'way/676888723'),
  ('5e34b98f-2716-5b05-9785-95d00ec7af2c', 'IPS Clínica de Rehabilitación del Valle', 'Valle del Cauca', null, 4.084152, -76.192719, null, false, 'co', 'way/684895388'),
  ('8f91239d-1557-5a78-a617-365c83c87fb8', 'IPS ESE Hospital Local de Obando', 'Valle del Cauca', null, 4.577667, -75.973308, null, true, 'co', 'way/706452619'),
  ('81b1ede3-7b05-5316-a487-d56cbaabfc52', 'Hospital Local Pedro Sáenz Díaz', 'Valle del Cauca', null, 4.701669, -75.735483, null, false, 'co', 'way/910554129'),
  ('027bc95f-319c-5f68-ad50-97a9fcfff9f6', 'Clinica Santa Sofia', 'Valle del Cauca', null, 3.880516, -77.020098, null, false, 'co', 'way/935940713'),
  ('50bea649-82ad-59f7-8978-6ebc55cc21d2', 'Corporacion IPS Saludcoop - Clínica Cali Norte', 'Valle del Cauca', null, 3.469438, -76.52171, null, true, 'co', 'way/946619587'),
  ('33003a0c-c4c1-5531-9267-22ee1dbfbafe', 'Clínica Social de Ortodoncia', 'Valle del Cauca', null, 3.485957, -76.501272, '+57 2 4470547', false, 'co', 'way/1094687993'),
  ('2608b383-a413-5e54-8ecc-01b9095c41ec', 'Unidad Quirurgica Calida', 'Valle del Cauca', null, 3.419866, -76.547303, null, true, 'co', 'way/1094721497'),
  ('e7a3eb6c-c698-5c1b-8e4a-cc5e35df43d5', 'Centro Medico Por Salud', 'Valle del Cauca', null, 3.440515, -76.501976, '+57 2 4419060', false, 'co', 'way/1095080220'),
  ('a43355b7-106e-534e-8dc2-48716ed43996', 'Centro Medico Jamundi', 'Valle del Cauca', null, 3.256584, -76.536272, null, false, 'co', 'way/1282714436'),
  ('457d0ecd-befd-5e14-a28c-a805cca7261c', 'Hospital Luis Ablanque De La Plata', 'Valle del Cauca', null, 3.879649, -77.020619, null, false, 'co', 'way/1424644988'),
  ('565a011d-0e3e-55b6-9cb6-a96352821dea', 'IPS ESE Hospital San José de Tadó', 'Chocó', null, 5.265162, -76.555744, null, true, 'co', 'node/4602114719'),
  ('2d7dcd6b-1e60-57d9-b8a1-a8661bbd69aa', 'Hospital Juradó', 'Chocó', 'Jurado', 7.107255, -77.766318, null, false, 'co', 'way/525378529'),
  ('1b93908a-b56a-5a80-8e7e-cf00bf53a4eb', 'Hospital Bojaya', 'Chocó', null, 6.556615, -76.884179, null, false, 'co', 'way/803414040'),
  ('3e0656b1-c4fb-531a-a022-ab691bb96d2d', 'Hospital San Francisco de Asís', 'Chocó', 'Carrera 1, Quibdó', 5.696211, -76.661139, null, true, 'co', 'way/865414483'),
  ('f0f53ca0-5d21-5980-be4c-f1dd45b41748', 'Hospital', 'Chocó', null, 8.511639, -77.275658, null, false, 'co', 'way/981026722'),
  ('98eb2a47-567b-55b5-ba1f-7ab084d59bcb', 'Hospital Eduardo Santos', 'Chocó', null, 5.158975, -76.687805, null, false, 'co', 'way/1086709076'),
  ('c5d137e1-b695-5412-a16c-8158b826e782', 'Clínica del Parque', 'Quindío', null, 4.544628, -75.662995, '+57 6 7464920', false, 'co', 'node/318898690'),
  ('9cb03942-27f2-53e2-a91d-78a9ffca5359', 'Hospital San Vicente de Paul', 'Quindío', 'Calle 7, Salento', 4.636479, -75.570895, null, false, 'co', 'node/532613802'),
  ('b94374c9-332e-544d-a836-ff2ad0921260', 'Clínica La Providencia', 'Quindío', null, 4.551405, -75.659327, null, false, 'co', 'node/1394834665'),
  ('c2f332a7-9a76-53a2-8567-87b581d42eed', 'Hospital San Juan de Dios', 'Quindío', null, 4.556073, -75.656152, null, true, 'co', 'way/266072201'),
  ('3b2895f2-f3d9-5835-9d49-b6d02ed9cc4f', 'Sociedad Cardiovascular del Eje Cafetero', 'Quindío', null, 4.547252, -75.662324, null, true, 'co', 'way/295539299'),
  ('4600dd46-3bbc-5596-980f-d345341abe5a', 'Hospital Mental de Filandia', 'Quindío', null, 4.543459, -75.670095, null, false, 'co', 'way/301997330'),
  ('a97232fa-fe4f-56ca-aa61-4ea4edfb4402', 'Hospital Roberto Quintero Villa', 'Quindío', 'Montenegro', 4.558272, -75.748621, null, false, 'co', 'way/436969637'),
  ('aabbb205-2f2b-5820-990d-a46584c7c912', 'Hospital San Vicente de Paul', 'Quindío', null, 4.61877, -75.637669, null, false, 'co', 'way/438906546'),
  ('988d3c39-6f04-56e7-9a14-585bed03a5ba', 'Hospital San Vicente de Paul', 'Quindío', null, 4.209492, -75.787329, null, false, 'co', 'way/471994438'),
  ('5d18c6e5-a7bf-50af-af99-adeaa4080577', 'Hospital La Misericordia', 'Quindío', null, 4.533309, -75.64087, null, false, 'co', 'way/585528372'),
  ('b73d7fbe-a54a-5a03-ab9b-2057a16c676c', 'Clínica La Sagrada Familia', 'Quindío', null, 4.53861, -75.668175, null, false, 'co', 'way/1389547245'),
  ('3c8963fe-18e7-509b-9982-19270212dd18', 'Hospital Mental de Filandia', 'Quindío', null, 4.6771, -75.658565, null, false, 'co', 'way/1435619493'),
  ('96243246-35fe-5910-809d-32961235e591', 'Clínica Santa Ana', 'Quindío', null, 4.53045, -75.70196, null, false, 'co', 'way/1444620500'),
  ('896ffde4-b99a-58a9-a802-e7bcfc22d652', 'Clínica Versalles', 'Caldas', null, 5.062827, -75.497807, null, true, 'co', 'node/579737157'),
  ('e3114af7-eca7-5cf8-9288-2da214d3c8ea', 'Hospital San Antonio', 'Caldas', null, 5.046083, -75.515039, null, true, 'co', 'node/871146539'),
  ('26983983-018b-5be8-a8d1-27eb8b912dae', 'Clínica de la Policía', 'Caldas', null, 5.057207, -75.47932, null, false, 'co', 'node/946273087'),
  ('e856b677-9ee2-522f-adf1-48653c72606f', 'Clínica Flavio Restrepo', 'Caldas', null, 5.051165, -75.485102, null, false, 'co', 'node/1616704927'),
  ('51a4d6b6-4861-5542-b24d-8162734f66dc', 'Clínica Santillana', 'Caldas', null, 5.060525, -75.491779, null, true, 'co', 'node/1616704932'),
  ('f2943270-267e-5c20-829a-e74342e77a20', 'Hospital de Florencia', 'Caldas', null, 5.522795, -75.042084, null, false, 'co', 'node/4971438024'),
  ('2c97172a-593a-57f4-a124-8f2599596a0c', 'Hospital San Cayetano', 'Caldas', null, 5.293803, -75.05383, null, false, 'co', 'node/5110083742'),
  ('d3e20fd2-eecd-570f-974e-4df3c4507f7e', 'Hospital Local, San Juan de Dios', 'Caldas', null, 5.379504, -75.166381, null, false, 'co', 'node/5859763750'),
  ('e77b085d-d9df-500d-a737-1faf764106e5', 'Hospital Infantil Universitario Rafael Henao Toro', 'Caldas', null, 5.063846, -75.498733, null, false, 'co', 'way/52099333'),
  ('e328ddf5-d64b-5a41-9542-148e27ae142e', 'E.S.E Hospital San Jose', 'Caldas', null, 5.411157, -74.992659, null, true, 'co', 'way/321358458'),
  ('9336f1a4-8570-542f-9cc9-b7b323418140', 'IPS ESE Hospital San Félix', 'Caldas', null, 5.4508, -74.663893, null, true, 'co', 'way/418374965'),
  ('bda0f584-bd87-505e-8621-137e66ae02eb', 'Clínica Psiquiátrica San Juan de Dios', 'Caldas', null, 5.048769, -75.492659, null, false, 'co', 'way/494839849'),
  ('9a81df6b-4c63-5c22-8cc6-e0d39e9a4e2a', 'Hospital de Caldas', 'Caldas', null, 5.06263, -75.500445, null, true, 'co', 'way/498802653'),
  ('a8e94ba1-d895-5d21-84bd-52cddaa0fd33', 'Clínica de La Presentación', 'Caldas', null, 5.065866, -75.501701, '+5768860549', true, 'co', 'way/499707233'),
  ('88bb6c34-9565-51b7-8f52-17052965362f', 'ESE Hospital Departamental Universitario Santa Sofía de Caldas', 'Caldas', null, 5.057991, -75.529584, null, true, 'co', 'way/499715045'),
  ('23752c65-9ca0-5230-a1f3-164417f135b5', 'IPS ESE Hospital Departamental San Juan de Dios', 'Caldas', null, 5.428824, -75.703125, null, true, 'co', 'way/508295564'),
  ('57ec066c-9ba5-5a55-9876-d6b91ad18843', 'Hospital San Rafael', 'Caldas', null, 5.166064, -75.766451, null, false, 'co', 'way/509339238'),
  ('4a284701-49d9-57ba-914c-0db78653f388', 'IPS ESE Hospital San Marcos - Sede Arauca', 'Caldas', null, 5.109586, -75.701895, null, false, 'co', 'way/510258222'),
  ('8994e2f8-3045-5e92-8760-dd03ad389baf', 'Hospital San Juan de Dios', 'Caldas', null, 5.379184, -75.16649, '+57 6 8555306', false, 'co', 'way/511539059'),
  ('5fdc3de4-860d-52d7-8973-cd96b38996be', 'IPS ESE Hospital San Marcos - Sede Chinchiná Principal', 'Caldas', null, 4.983969, -75.610429, null, true, 'co', 'way/535356469'),
  ('5a578318-10dd-5007-aae3-acd237d16eb7', 'IPS ESE Hospital San Vicente de Paúl', 'Caldas', null, 5.225073, -75.78953, null, true, 'co', 'way/548784168'),
  ('1d920fc4-d11c-58b5-8d73-5776833c5c88', 'IPS ESE Hospital San Marcos - Sede Palestina', 'Caldas', null, 5.017022, -75.626991, null, true, 'co', 'way/559810651'),
  ('6707be84-1fce-5955-90c8-2240ac96da8f', 'IPS ESE Hospital San José', 'Caldas', null, 5.06525, -75.869915, null, true, 'co', 'way/567502023'),
  ('5b8a060a-64b6-5e87-aa86-8ff39e505e1c', 'IPS ESE Hospital San Lorenzo', 'Caldas', null, 5.450353, -75.649443, null, true, 'co', 'way/577855149'),
  ('57fa1837-5a75-5fb1-881b-a0a7e6f50dcb', 'IPS ESE Hospital San José', 'Caldas', null, 5.605546, -75.451677, null, false, 'co', 'way/577864422'),
  ('6e96cb4e-a216-55ef-8df8-4399987a8ab0', 'Cruz Roja', 'Caldas', 'Calle 14 2-29, chinchina', 4.988944, -75.606264, null, true, 'co', 'way/652455583'),
  ('db6539e5-ef2c-5976-8b98-57b94e82c999', 'Hospital Sagrado Corazón', 'Caldas', 'Calle 9A, Norcasia', 5.573982, -74.887377, '+57 3136155448', false, 'co', 'way/697510761'),
  ('76e1ade6-0a14-51e3-8f90-be475934396a', 'Hospital Geriátrico San Isidro', 'Caldas', null, 5.096226, -75.529022, null, false, 'co', 'way/931593582'),
  ('d80a591a-1b45-5b4a-a35e-1041b743f582', 'IPS ESE Hospital San José', 'Caldas', null, 4.989137, -75.812975, null, true, 'co', 'way/1083567700')
on conflict (id) do nothing;

commit;

-- Comprobacion:
--   select estado, count(*) from hospitals_osm group by estado order by 2 desc;


-- ─── PARTE 2: coordenadas de acopio (esto SI se ve en la web) ─────────
--
-- Son 6 puntos que ya existen y que la web ya lista; lo unico que cambia
-- es que pasan a tener coordenada y por tanto pueden salir en su mapa.
-- Ninguno es dato nuevo ni sin verificar. Si aun asi se prefiere que la
-- web no cambie hoy, basta con no ejecutar este bloque.

begin;
update aid_points set lat = 4.6142765, lng = -74.0632805 where id = '302121d0-ba53-435b-9e07-27d0c1ebf6ed' and lat is null;  -- Universidad Francisco José de Caldas
update aid_points set lat = 4.6070836, lng = -74.0675481 where id = '5b989e7f-4b76-4adf-8a7f-06fab7e5bfc6' and lat is null;  -- Universidad Jorge Tadeo Lozano
update aid_points set lat = 10.4019402, lng = -75.5054963 where id = 'f0fe7a04-30ab-41b8-bedf-3b75ba677330' and lat is null;  -- Universidad de Cartagena
update aid_points set lat = 10.4252358, lng = -75.5366822 where id = '221cf673-8892-4d76-8fd1-3e495ec4f01e' and lat is null;  -- Coliseo Bernardo Caraballo
update aid_points set lat = 3.3016718, lng = -76.5434546 where id = 'da71986d-85f8-4f1d-8ddb-f5d1be350024' and lat is null;  -- Centro Deportivo Luz Mery Tristán
update aid_points set lat = 3.4550187, lng = -76.5348007 where id = 'edcb3c81-65db-465b-8930-14522539dccf' and lat is null;  -- Plazoleta Jairo Varela
commit;

-- Comprobacion:
--   select count(*) from aid_points where country='co' and lat is not null;
