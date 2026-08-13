-- Mapa de Colombia · 2 de 2: coordenadas de puntos de acopio.
--
-- ESTO SI CAMBIA LO QUE SE VE EN LA WEB. Son 6 puntos que ya existen en
-- `aid_points` y que el sitio ya lista; lo unico que cambia es que pasan a
-- tener coordenada, y por tanto pueden salir en su mapa. No es dato nuevo ni
-- sin verificar, pero la decision de publicarlo no es de quien lo genero.
--
-- El fichero 1 no depende de este. Se puede no ejecutar nunca.
--
-- Deshacer:
--   update aid_points set lat = null, lng = null
--     where country = 'co' and lat is not null;

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
