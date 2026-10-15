"""Genera los íconos de músculos de assets/muscles a partir de los originales
de design/muscles (PNG grandes, con fondo transparente).

Crea una imagen por densidad de pantalla (1x, 2x, 3x y 4x) para que Flutter
use la que corresponde en vez de achicar la grande en el momento, que deja
los trazos finos y borrosos. En los tamaños chicos además engrosa el trazo
para que no desaparezca.

Uso: python tool/resize_muscle_icons.py
"""

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'design' / 'muscles'
DST = ROOT / 'assets' / 'muscles'

# Tamaño lógico del ícono (en la app se usa entre 18 y 24).
BASE = 24

# Densidad -> cuánto engrosar el trazo (tamaño del filtro, impar) antes de
# achicar. Los originales tienen trazos de ~6 px en 192 px.
VARIANTS = {1: 7, 2: 5, 3: 3, 4: 3}


def main():
    sources = sorted(SRC.glob('*.png'))
    if not sources:
        raise SystemExit(f'No hay imágenes en {SRC}')
    for src in sources:
        image = Image.open(src).convert('RGBA')
        alpha = image.getchannel('A')
        for ratio, grow in VARIANTS.items():
            a = alpha.filter(ImageFilter.MaxFilter(grow)) if grow > 1 else alpha
            size = BASE * ratio
            a = a.resize((size, size), Image.LANCZOS)
            # Solo importa la forma: la app la pinta del color del tema.
            out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            out.putalpha(a)
            folder = DST if ratio == 1 else DST / f'{ratio}.0x'
            folder.mkdir(parents=True, exist_ok=True)
            out.save(folder / src.name, optimize=True)
        print(src.name)


if __name__ == '__main__':
    main()
