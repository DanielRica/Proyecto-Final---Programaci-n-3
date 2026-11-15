from svgkit import Lienzo

AZUL, NARANJA, VERDE, MORADO, TURQ, ROJO, GRIS, AMARILLO = "#1E88E5", "#FB8C00", "#43A047", "#8E24AA", "#00897B", "#E53935", "#607D8B", "#F9A825"
ANCHO_E = 310
COLS = [40, 470, 900, 1330]

entidades = {
  "Usuario": dict(col=1, fila=0, color=AZUL, archivo="usuarios.txt", campos=[
      "PK nombre_usuario: texto", "clave: huella SHA-256 (no texto plano)", "nombre_completo: texto",
      "tipo: ciudadano | voluntario |", "      coordinador | administrador", "zona: zona principal del usuario"]),
  "Actividad": dict(col=0, fila=0, color=GRIS, archivo="actividad.txt", campos=[
      "fecha: ISO 8601", "FK usuario: nombre_usuario", "accion: comando ejecutado"]),
  "Necesidad": dict(col=2, fila=0, color=NARANJA, archivo="necesidades.txt", campos=[
      "PK id: \"N001\"", "tipo: agua | alimentos | medicamentos | ...", "descripcion: texto", "cantidad: entero > 0",
      "cantidad_asignada: entero", "FK zona: codigo de zona", "prioridad: critica | alta | media | baja",
      "FK responsable: nombre_usuario", "estado: pendiente | asignada | en_atencion |", "      atendida | cancelada"]),
  "Movimiento": dict(col=3, fila=0, color=MORADO, archivo="movimientos.txt", campos=[
      "numero: orden en el historial", "FK codigo: recurso afectado", "tipo: registro | entrada | salida |", "      asignacion | liberacion |", "      transferencia_salida / _entrada", "cantidad: entero", "detalle: id de la necesidad o motivo"]),
  "Mensaje": dict(col=1, fila=1, color=TURQ, archivo="mensajes.txt", campos=[
      "PK id: \"MSG001\"", "fecha: ISO 8601", "FK remitente: nombre_usuario", "destinatario: documento de la persona",
      "contenido: texto", "estado: pendiente | entregado"]),
  "Zona": dict(col=2, fila=1, color=VERDE, archivo="zonas.txt", campos=[
      "tipo: zona | sector | punto de atencion", "PK codigo: (ruta zona/sector/punto)", "nombre: texto",
      "nivel: critico | alto | medio | bajo", "personas: estimado afectado", "hijos: LISTA de nodos del mismo tipo",
      "   (recursivo: zona -> sectores -> puntos)"]),
  "Recurso": dict(col=3, fila=1, color=MORADO, archivo="recursos.txt", campos=[
      "PK codigo: \"R001\"", "nombre / categoria: \"agua\"", "cantidad: entero >= 0 (nunca negativo)", "unidad: litros, kg...",
      "ubicacion: centro de acopio o albergue", "FK zona: codigo de zona"]),
  "Persona": dict(col=1, fila=2, color=TURQ, archivo="personas.txt", campos=[
      "PK documento: texto", "nombre: texto", "edad: entero o desconocida", "FK zona: codigo de zona",
      "estado: sin_informacion | reportada | localizada |", "      trasladada | en_albergue | reunificada",
      "historial: LISTA de estados por los que pasó"]),
  "Albergue": dict(col=2, fila=2, color=VERDE, archivo="albergues.txt", campos=[
      "PK codigo: \"A01\"", "nombre: texto", "FK zona: codigo de zona", "capacidad: entero > 0",
      "ocupacion: entero (<= capacidad)", "personas: MapSet de documentos alojados"]),
  "Mascota": dict(col=3, fila=2, color=ROJO, archivo="mascotas.txt", campos=[
      "PK id: \"PET001\"", "tipo: perdida | encontrada", "especie / nombre / color / tamano", "caracteristicas: texto",
      "FK zona: codigo de zona", "contacto: texto", "estado: activa | posible_coincidencia |", "      resuelta",
      "coincidencia: id del reporte pareja (o \"-\")"]),
}

# Altura de cada caja y posición de cada fila
for e in entidades.values():
    e["alto"] = 40 + 17 * len(e["campos"])
y_fila = [80]
for f in range(3):
    alto_fila = max(e["alto"] for e in entidades.values() if e["fila"] == f)
    y_fila.append(y_fila[-1] + alto_fila + 78)
for e in entidades.values():
    e["x"], e["y"], e["ancho"] = COLS[e["col"]], y_fila[e["fila"]], ANCHO_E

ALTO_TOTAL = y_fila[3] - 78 + 50
L = Lienzo(1760, ALTO_TOTAL, "Modelo de datos — entidades, atributos y relaciones")

# ---- Dibujar entidades ----
for nombre, e in entidades.items():
    x, y, w, h = e["x"], e["y"], e["ancho"], e["alto"]
    L.fondo(x, y, w, h, "#FFFFFF", e["color"], 10, 2)
    L.fondo(x, y, w, 30, e["color"], e["color"], 10, 2)
    L.texto(x + w / 2, y + 20, f"{nombre}", tam=13, negrita=True, color="#FFFFFF")
    L.texto(x + w - 8, y + 20, e["archivo"], tam=9, ancla="end", color="#FFFFFF")
    for i, campo in enumerate(e["campos"]):
        negrita = campo.startswith("PK")
        L.texto(x + 10, y + 50 + i * 17, campo, tam=11, negrita=negrita, ancla="start")

def borde(n, lado, desplazo=0):
    e = entidades[n]
    x, y, w, h = e["x"], e["y"], e["ancho"], e["alto"]
    return {"izq": (x, y + 55 + desplazo), "der": (x + w, y + 55 + desplazo),
            "arr": (x + w / 2 + desplazo, y), "aba": (x + w / 2 + desplazo, y + h)}[lado]

def relacion(p1, p2, c1, c2, etiqueta=None, color="#444444", dash=None, ruta=None):
    puntos = [p1] + (ruta or []) + [p2]
    L.flecha(puntos, color, 2, dash=dash, sin_punta=True)
    for (a, b), c in (((p1, puntos[1]), c1), ((p2, puntos[-2]), c2)):
        dx, dy = b[0] - a[0], b[1] - a[1]
        d = max((dx * dx + dy * dy) ** 0.5, 1)
        L.etiqueta(a[0] + dx / d * 16 + (0 if abs(dx) > abs(dy) else 12), a[1] + dy / d * 16 + (-10 if abs(dx) > abs(dy) else 0), c, "#B71C1C", 11, 22)
    if etiqueta:
        mx, my = (puntos[len(puntos) // 2 - 1][0] + puntos[len(puntos) // 2][0]) / 2, (puntos[len(puntos) // 2 - 1][1] + puntos[len(puntos) // 2][1]) / 2
        L.etiqueta(mx, my, etiqueta, "#333333", 10, len(etiqueta) * 6.4 + 10)

# ---- Relaciones ----
relacion(borde("Usuario", "izq"), borde("Actividad", "der"), "1", "N", "realiza")
relacion(borde("Usuario", "der"), borde("Necesidad", "izq"), "1", "N", "reporta")
relacion(borde("Necesidad", "der"), borde("Movimiento", "izq"), "1", "N", "recibe")
relacion(borde("Movimiento", "aba"), borde("Recurso", "arr"), "N", "1", "afecta")
relacion(borde("Zona", "der"), borde("Recurso", "izq"), "1", "N", "tiene")
relacion(borde("Zona", "arr"), borde("Necesidad", "aba"), "1", "N", "tiene")
relacion(borde("Zona", "aba"), borde("Albergue", "arr"), "1", "N", "tiene")
relacion(borde("Albergue", "izq"), borde("Persona", "der"), "N", "N", "aloja")
relacion(borde("Usuario", "aba"), borde("Mensaje", "arr"), "1", "N", "envía")
relacion(borde("Mensaje", "aba"), borde("Persona", "arr"), "N", "1", "va para")
relacion((entidades["Zona"]["x"], entidades["Zona"]["y"] + entidades["Zona"]["alto"] - 20),
         (entidades["Persona"]["x"] + ANCHO_E, entidades["Persona"]["y"] + 30), "1", "N", None, "#2E7D32", "6,4",
         ruta=[(entidades["Zona"]["x"] - 40, entidades["Zona"]["y"] + entidades["Zona"]["alto"] - 20),
               (entidades["Zona"]["x"] - 40, entidades["Persona"]["y"] + 30)])
relacion((entidades["Zona"]["x"] + ANCHO_E, entidades["Zona"]["y"] + entidades["Zona"]["alto"] - 8),
         (entidades["Mascota"]["x"], entidades["Mascota"]["y"] + 30), "1", "N", None, "#2E7D32", "6,4",
         ruta=[(entidades["Zona"]["x"] + ANCHO_E + 40, entidades["Zona"]["y"] + entidades["Zona"]["alto"] - 8),
               (entidades["Zona"]["x"] + ANCHO_E + 40, entidades["Mascota"]["y"] + 30)])
# Mascota perdida <-> encontrada (autorrelación)
m = entidades["Mascota"]
L.flecha([(m["x"] + m["ancho"], m["y"] + 70), (m["x"] + m["ancho"] + 30, m["y"] + 70), (m["x"] + m["ancho"] + 30, m["y"] + 130), (m["x"] + m["ancho"], m["y"] + 130)],
         "#444444", 2, sin_punta=True)
L.etiqueta(m["x"] + m["ancho"] + 30, m["y"] + 100, "coincide\n(1 a 1)", "#333333", 10, 62)

# ---- Recuadro de estructuras ----
x, y = COLS[0], y_fila[1]
L.fondo(x, y, ANCHO_E, 300, "#F9FBE7", "#9E9D24", 12, 2)
L.texto(x + 14, y + 26, "Estructuras de datos usadas", tam=13, negrita=True, ancla="start", color="#827717")
estructuras = [
    "MAPA por identificador:", "  %{\"N001\" => %{...}}  (usuarios, necesidades,", "  recursos, albergues, personas, mensajes, reportes)",
    "ÁRBOL con listas de hijos (maps anidados):", "  zona -> sectores -> puntos de atención",
    "LISTA: historial de estados, movimientos", "MAPSET: documentos alojados, palabras comunes",
    "TUPLAS: {:ok, valor} / {:error, motivo}", "  y {codigo_recurso, cantidad} en las asignaciones",
    "ARCHIVO de texto por entidad: campos con ;"]
for i, linea in enumerate(estructuras):
    L.texto(x + 14, y + 54 + i * 22, linea, tam=11, ancla="start")
L.texto(x, y + 330, "Leyenda: PK = identificador único · FK = referencia a otra entidad", tam=11, ancla="start", color="#555555")
L.texto(x, y + 350, "Líneas punteadas verdes: relación con la zona (1 zona : N elementos)", tam=11, ancla="start", color="#2E7D32")

L.guardar("02_modelo_de_datos.svg")
