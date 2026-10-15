# Íconos de músculos

Las imágenes de esta carpeta (y de 2.0x, 3.0x y 4.0x) se generan: no las
edites a mano. Poné los originales en design/muscles y corré

    python tool/resize_muscle_icons.py

que crea una versión achicada por densidad de pantalla, para que se vean
nítidas en vez de borrosas.

Los originales van con estos nombres exactos:

| Archivo              | Ícono          |
| -------------------- | -------------- |
| hombros.png          | Hombros        |
| espalda.png          | Espalda        |
| pecho.png            | Pecho          |
| biceps.png           | Bíceps         |
| triceps.png          | Tríceps        |
| abdominales.png      | Abdominales    |
| gluteos.png          | Glúteos        |
| cuadriceps.png       | Cuádriceps     |
| isquiotibiales.png   | Isquiotibiales |
| aductores.png        | Aductores      |
| abductores.png       | Abductores     |
| gemelos.png          | Gemelos        |

- PNG cuadrado, con fondo transparente, de 192×192 px o más.
- Silueta de un solo color: la app la pinta del marrón del tema, así que
  los colores y los detalles internos se pierden.
- Si falta una imagen, se muestra el ícono del tipo de peso.
- Para agregar un ícono nuevo hay que sumarlo también a `MuscleIcon` en
  lib/models.dart.
