# Pequeña ayuda para dibujar diagramas en SVG (cajas, flechas y textos).
import re
from xml.sax.saxutils import escape

FUENTE = "DejaVu Sans, Verdana, sans-serif"

class Lienzo:
    def __init__(self, ancho, alto, titulo=None):
        self.ancho, self.alto = ancho, alto
        self.partes = []
        self.colores = set()
        self.fondo(0, 0, ancho, alto, "#FFFFFF", "none", 0)
        if titulo:
            self.texto(ancho / 2, 38, titulo, tam=22, negrita=True)

    def _marcador(self, color):
        self.colores.add(color)
        return "flecha_" + color.strip("#")

    def fondo(self, x, y, w, h, relleno, borde, radio=14, grosor=1.5, dash=None):
        extra = f' stroke-dasharray="{dash}"' if dash else ""
        self.partes.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radio}" ry="{radio}" '
            f'fill="{relleno}" stroke="{borde}" stroke-width="{grosor}"{extra}/>')

    def zona(self, x, y, w, h, titulo, relleno, borde):
        self.fondo(x, y, w, h, relleno, borde, 16, 2)
        self.texto(x + 14, y + 22, titulo, tam=13, negrita=True, ancla="start", color=borde)

    def texto(self, x, y, txt, tam=12, negrita=False, ancla="middle", color="#222222", mono=False):
        txt = re.sub(r"^( +)", lambda m: "\u00a0" * len(m.group(1)), txt)
        fam = "DejaVu Sans Mono, monospace" if mono else FUENTE
        peso = "bold" if negrita else "normal"
        self.partes.append(
            f'<text x="{x}" y="{y}" font-family="{fam}" font-size="{tam}" font-weight="{peso}" '
            f'text-anchor="{ancla}" fill="{color}">{escape(txt)}</text>')

    def caja(self, x, y, w, h, lineas, relleno="#FFFFFF", borde="#555555", tam=12, grosor=1.5, dash=None):
        self.fondo(x, y, w, h, relleno, borde, 10, grosor, dash)
        n = len(lineas)
        alto_linea = tam + 4
        y0 = y + h / 2 - (n - 1) * alto_linea / 2 + tam / 3
        for i, linea in enumerate(lineas):
            self.texto(x + w / 2, y0 + i * alto_linea, linea, tam=tam, negrita=(i == 0 and n > 1))

    def flecha(self, puntos, color="#555555", grosor=1.8, dash=None, etiqueta=None, pos=0.5,
               doble=False, sin_punta=False, tam_et=11, desplazar=(0, 0), ancho_et=None):
        m = self._marcador(color)
        pts = " ".join(f"{x},{y}" for x, y in puntos)
        extra = f' stroke-dasharray="{dash}"' if dash else ""
        fin = "" if sin_punta else f' marker-end="url(#{m})"'
        ini = f' marker-start="url(#{m}i)"' if doble else ""
        self.partes.append(
            f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{grosor}"{extra}{fin}{ini}/>')
        if etiqueta:
            (x1, y1), (x2, y2) = puntos[0], puntos[-1]
            if len(puntos) > 2:
                (x1, y1), (x2, y2) = puntos[1], puntos[2] if len(puntos) > 2 else puntos[-1]
            cx = x1 + (x2 - x1) * pos + desplazar[0]
            cy = y1 + (y2 - y1) * pos + desplazar[1]
            self.etiqueta(cx, cy, etiqueta, color, tam_et, ancho_et)

    def etiqueta(self, cx, cy, etiqueta, color="#333333", tam=11, ancho=None):
        lineas = etiqueta.split("\n")
        ancho = ancho or (max(len(l) for l in lineas) * tam * 0.62 + 10)
        alto = len(lineas) * (tam + 3) + 4
        self.partes.append(
            f'<rect x="{cx - ancho / 2}" y="{cy - alto / 2}" width="{ancho}" height="{alto}" fill="#FFFFFF" '
            f'fill-opacity="0.92" rx="4"/>')
        for i, l in enumerate(lineas):
            self.texto(cx, cy - alto / 2 + (tam + 3) * (i + 1) - 1, l, tam=tam, color=color)

    def guardar(self, ruta):
        defs = []
        for c in self.colores:
            n = "flecha_" + c.strip("#")
            defs.append(
                f'<marker id="{n}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
                f'<path d="M0,0 L10,5 L0,10 z" fill="{c}"/></marker>'
                f'<marker id="{n}i" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
                f'<path d="M0,0 L10,5 L0,10 z" fill="{c}"/></marker>')
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.ancho}" height="{self.alto}" '
               f'viewBox="0 0 {self.ancho} {self.alto}"><defs>{"".join(defs)}</defs>{"".join(self.partes)}</svg>')
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(svg)
