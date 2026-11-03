#!/usr/bin/env python3
"""Contraste WCAG 2.x para la app Green Tech.

Uso:
  contrast.py FG BG                 # razón de contraste de texto FG sobre BG
  contrast.py FG BG --tint 0.1      # ...sobre BG teñido con FG al 10 % (píldoras)
  contrast.py --app [colors.dart]   # audita la paleta de estado de AppColors

Los colores van en hex: '#065F46', '065F46' o '0xFF065F46'.
AA pide >= 4.5:1 para texto normal y >= 3:1 para texto grande (>= 18.66 px
en negrita o >= 24 px) e íconos. Sale con código 1 si algo no llega a AA.
"""
import argparse
import re
import sys
from pathlib import Path

AA_TEXTO = 4.5

# Fondos de las tarjetas (NeumorphismDecoration) y alfa de las píldoras de
# estado en lib/widgets/variable_card.dart.
FONDO = {'claro': '#EAEFF5', 'oscuro': '#1E293B'}
TINTE = {'claro': 0.10, 'oscuro': 0.20}


def _rgb(color: str) -> tuple[int, int, int]:
    h = color.strip().lower().removeprefix('#').removeprefix('0x')
    if len(h) == 8:  # 0xAARRGGBB de Flutter
        h = h[2:]
    if not re.fullmatch(r'[0-9a-f]{6}', h):
        raise ValueError(f'color inválido: {color}')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _lum(rgb) -> float:
    def canal(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (canal(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def mezcla(fg, bg, alfa: float):
    return tuple(round(alfa * f + (1 - alfa) * b) for f, b in zip(fg, bg))


def contraste(fg, bg) -> float:
    a, b = sorted((_lum(fg), _lum(bg)), reverse=True)
    return (a + 0.05) / (b + 0.05)


def _fila(nombre, fg, bg, tinte=None):
    sobre = mezcla(fg, bg, tinte) if tinte else bg
    r = contraste(fg, sobre)
    ok = r >= AA_TEXTO
    print(f'  {"OK " if ok else "NO "} {nombre:28} {r:5.2f}:1')
    return ok


def auditar_app(ruta: Path) -> bool:
    """Lee los colores privados _okLight, _warnDark, etc. de AppColors."""
    src = ruta.read_text(encoding='utf-8')
    colores = dict(re.findall(r'static const Color (\w+) = Color\((0x[0-9A-Fa-f]{8})\)', src))
    todo_ok = True
    for modo, sufijo, texto2 in (('claro', 'Light', 'textSecondary'),
                                 ('oscuro', 'Dark', 'darkTextSecondary')):
        bg = _rgb(FONDO[modo])
        print(f'Modo {modo} (tarjeta {FONDO[modo]}, píldora al {TINTE[modo]:.0%}):')
        for estado in ('ok', 'warn', 'crit', 'stale'):
            nombre = f'_{estado}{sufijo}'
            if nombre not in colores:
                print(f'  ??  falta {nombre} en {ruta}')
                todo_ok = False
                continue
            fg = _rgb(colores[nombre])
            todo_ok &= _fila(f'{nombre} tarjeta', fg, bg)
            todo_ok &= _fila(f'{nombre} píldora', fg, bg, TINTE[modo])
        if texto2 in colores:
            todo_ok &= _fila(f'{texto2} tarjeta', _rgb(colores[texto2]), bg)
    return todo_ok


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('fg', nargs='?')
    p.add_argument('bg', nargs='?')
    p.add_argument('--tint', type=float, help='alfa del tinte de FG sobre BG')
    p.add_argument('--app', nargs='?', const='lib/utils/colors.dart',
                   help='audita AppColors (por defecto lib/utils/colors.dart)')
    a = p.parse_args()

    if a.app:
        return 0 if auditar_app(Path(a.app)) else 1
    if not (a.fg and a.bg):
        p.error('indica FG y BG, o usa --app')
    fg, bg = _rgb(a.fg), _rgb(a.bg)
    sobre = mezcla(fg, bg, a.tint) if a.tint else bg
    r = contraste(fg, sobre)
    nivel = 'AA texto' if r >= 4.5 else ('solo texto grande/íconos' if r >= 3 else 'NO cumple')
    print(f'{r:.2f}:1 ({nivel})')
    return 0 if r >= AA_TEXTO else 1


if __name__ == '__main__':
    sys.exit(main())
