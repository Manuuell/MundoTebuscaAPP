# Ícono de la app

Se generan con `dart run flutter_launcher_icons` (config al final de
`pubspec.yaml`). Fuente original: `logoapp.jpeg` en la raíz del repo.

| Archivo | Para qué | Notas |
|---|---|---|
| `icon.png` | iOS, Android legacy, web | 1024×1024, **sin canal alfa** — Apple rechaza íconos con transparencia |
| `icon_foreground.png` | Capa frontal del ícono adaptativo de Android | 1024×1024 con alfa |

## Por qué el ícono no lleva el wordmark

El logo original trae "EL MUNDO TE BUSCA" bajo la marca. En el ícono va **solo
el corazón**, por dos razones:

1. A tamaño real —unos 60 pt en la pantalla de inicio— el texto mide apenas
   unos píxeles de alto: no se lee, se ve como una mancha gris bajo el dibujo.
2. Android e iOS ya pintan el nombre de la app debajo del ícono, así que el
   wordmark sería redundante incluso si se leyera.

El logo completo sí sirve dentro de la app (cabeceras, pantalla de bienvenida),
donde hay espacio para que el texto se lea.

## Por qué el foreground de Android es más pequeño que el ícono de iOS

Dos recortes se aplican en cadena y hay que compensar los dos:

- El XML de `adaptive-icon` que genera flutter_launcher_icons mete un
  `android:inset="16%"`, o sea que la imagen se dibuja en el 68% central.
- Encima, la **máscara del launcher** solo muestra el 66,7% central del lienzo
  (72 dp de 108), y su forma la elige cada fabricante: círculo, squircle, gota.

Por eso la marca ocupa 72% del lienzo en `icon_foreground.png` pero 74% en
`icon.png`: tras el inset acaba en ~49% del lienzo, que es aproximadamente dos
tercios del área visible. Si se pusiera a sangre, un recorte circular se comería
las manos, que son la mitad del significado del logo.

Verificado renderizando el resultado con máscara circular y squircle antes de
darlo por bueno.

## Cambiar el ícono

Reemplazar `logoapp.jpeg` y volver a correr el script de recorte, o sustituir
directamente los dos PNG respetando tamaños y el detalle del alfa. Después:

```bash
dart run flutter_launcher_icons
```
