from svgkit import Lienzo

AZUL, NARANJA, VERDE, MORADO, GRIS, ROJO, AMARILLO = "#1E88E5", "#FB8C00", "#43A047", "#8E24AA", "#607D8B", "#E53935", "#F9A825"


def secuencia(archivo, titulo, participantes, pasos, ancho_col=215, margen=80):
    """participantes: lista de (lineas_del_titulo, color). pasos: tuplas
       ('msg', desde, hasta, texto, estilo)  estilo: 'sol' (sólida) | 'resp' (punteada) | 'ok' | 'err'
       ('nota', desde, hasta, [lineas], color)
       ('sep', texto)"""
    n = len(participantes)
    ancho = margen * 2 + ancho_col * (n - 1) + 120
    xs = [margen + 60 + i * ancho_col for i in range(n)]

    # Alturas de cada paso
    ys, y = [], 170
    for p in pasos:
        if p[0] == "msg":
            lineas = p[3].count("\n") + 1
            y += 30 + 14 * (lineas - 1)
            ys.append(y)
            y += 18
        elif p[0] == "nota":
            y += 12
            ys.append(y)
            y += 16 * len(p[3]) + 18
        else:
            y += 26
            ys.append(y)
            y += 14
    alto = y + 60
    L = Lienzo(ancho, alto, titulo)

    # Cabeceras y líneas de vida
    for x, (lineas, color) in zip(xs, participantes):
        L.caja(x - 85, 62, 170, 24 + 15 * len(lineas), lineas, color, color, tam=11)
        L.partes[-1 - len(lineas)] = L.partes[-1 - len(lineas)]  # (sin cambios)
        L.flecha([(x, 62 + 24 + 15 * len(lineas)), (x, alto - 40)], "#9E9E9E", 1.4, dash="6,5", sin_punta=True)

    colores = {"sol": "#37474F", "resp": "#78909C", "ok": VERDE, "err": ROJO, "azul": AZUL}
    for p, y in zip(pasos, ys):
        if p[0] == "msg":
            _, a, b, texto, estilo = p
            color = colores[estilo]
            dash = "6,4" if estilo in ("resp",) else None
            L.flecha([(xs[a], y), (xs[b], y)], color, 2, dash=dash)
            lineas = texto.split("\n")
            cx = (xs[a] + xs[b]) / 2
            ancho_et = max(len(l) for l in lineas) * 6.6 + 12
            L.etiqueta(cx, y - 10 - 14 * (len(lineas) - 1) / 2 - 2, texto, color, 11, ancho_et)
        elif p[0] == "nota":
            _, a, b, lineas, color = p
            x1, x2 = min(xs[a], xs[b]) - 70, max(xs[a], xs[b]) + 70
            ancho_txt = max(len(l) for l in lineas) * 6.6 + 40
            if x2 - x1 < ancho_txt:
                centro = (x1 + x2) / 2
                x1, x2 = centro - ancho_txt / 2, centro + ancho_txt / 2
            h = 16 * len(lineas) + 10
            L.fondo(x1, y, x2 - x1, h, "#FFFDE7" if color == AMARILLO else "#F5F5F5", color, 8, 1.6)
            for i, l in enumerate(lineas):
                L.texto((x1 + x2) / 2, y + 17 + i * 16, l, tam=11, color="#333333")
        else:
            L.fondo(30, y - 14, ancho - 60, 24, "#E8EAF6", "#9FA8DA", 6, 1)
            L.texto(ancho / 2, y + 3, p[1], tam=12, negrita=True, color="#3F51B5")
    L.guardar(archivo)


# ============================================================ 3A: conexión y comando normal
participantes = [
    (["Cliente", "cliente.exs (laura)"], AZUL),
    (["servidor.exs", "(un spawn por solicitud)"], NARANJA),
    (["Servicio", "Permisos · Presentacion"], NARANJA),
    (["ServidorUsuarios", "+ SupervisorSesiones"], VERDE),
    (["ServidorZonas"], VERDE),
    (["ServidorNecesidades"], VERDE),
    (["datos/*.txt"], AMARILLO),
]
pasos = [
    ("sep", "1. connect  (el usuario aún no tiene sesión)"),
    ("msg", 0, 1, "{nil, \"connect\", [laura, 1234,\ncoordinador, centro]}", "sol"),
    ("msg", 1, 2, "ejecutar(mensaje)", "sol"),
    ("msg", 2, 3, "conectar(laura, 1234,\ncoordinador, centro)", "sol"),
    ("nota", 3, 3, ["Usuarios.conectar: no existe → se registra", "start_child(Sesion) en el DynamicSupervisor"], VERDE),
    ("msg", 3, 6, "guardar usuarios.txt y actividad.txt", "sol"),
    ("msg", 3, 2, "{:ok, %{como: :registrado}}", "resp"),
    ("msg", 2, 1, "{:ok, \"Usuario nuevo registrado: laura...\"}", "resp"),
    ("msg", 1, 0, "{:respuesta, {:ok, texto}}", "ok"),
    ("sep", "2. register_need  (con la sesión abierta)"),
    ("msg", 0, 1, "{\"laura\", \"register_need\",\n[agua, 30, critica, centro, \"Punto...\"]}", "sol"),
    ("msg", 1, 2, "ejecutar(mensaje)", "sol"),
    ("msg", 2, 3, "sesion(\"laura\")", "sol"),
    ("msg", 3, 2, "{:ok, %{tipo: \"coordinador\", ...}}", "resp"),
    ("nota", 2, 2, ["Permisos.verificar(\"coordinador\", \"register_need\") → :ok", "entero(\"30\") → {:ok, 30}"], NARANJA),
    ("msg", 2, 4, "existe_zona?(\"centro\")", "sol"),
    ("msg", 4, 2, "true", "resp"),
    ("msg", 2, 5, "registrar(agua, 30, critica, centro,\n\"Punto...\", \"laura\")", "sol"),
    ("msg", 5, 6, "guardar necesidades.txt", "sol"),
    ("msg", 5, 2, "{:ok, %{id: \"N001\", estado: \"pendiente\", ...}}", "resp"),
    ("msg", 2, 3, "registrar_actividad(laura, comando)", "sol"),
    ("msg", 3, 6, "agregar a actividad.txt", "sol"),
    ("msg", 2, 1, "{:ok, \"Necesidad registrada: N001 ...\"}", "resp"),
    ("msg", 1, 0, "{:respuesta, {:ok, texto}}", "ok"),
]
secuencia("03a_secuencia_conexion_y_comando.svg", "Diagrama de secuencia 1 — connect y register_need", participantes, pasos)

# ============================================================ 3B: el conflicto de los 50 litros
participantes = [
    (["Cliente laura", "assign_resource N001"], AZUL),
    (["Cliente pedro", "assign_resource N002"], AZUL),
    (["servidor.exs", "+ Servicio + Asignador", "(un proceso por solicitud)"], NARANJA),
    (["ServidorNecesidades", "N001 pide 30 · N002 pide 25"], VERDE),
    (["ServidorRecursos", "R001: 50 litros"], VERDE),
    (["datos/*.txt"], AMARILLO),
]
pasos = [
    ("nota", 0, 1, ["Dos coordinadores piden agua AL MISMO TIEMPO sobre el mismo inventario de 50 litros"], AMARILLO),
    ("msg", 0, 2, "assign_resource N001 agua 30", "sol"),
    ("msg", 1, 2, "assign_resource N002 agua 25", "sol"),
    ("nota", 2, 2, ["spawn: dos procesos distintos atienden las dos solicitudes en paralelo"], NARANJA),
    ("sep", "Paso 1 — reservar en la necesidad (así una necesidad no consume recursos dos veces)"),
    ("msg", 2, 3, "reservar(N001, 30)", "sol"),
    ("msg", 2, 3, "reservar(N002, 25)", "sol"),
    ("msg", 3, 2, "{:ok, ...}  (ambas quedan reservadas)", "resp"),
    ("sep", "Paso 2 — tomar los recursos: ServidorRecursos atiende UN mensaje a la vez"),
    ("msg", 2, 4, "asignar(agua, 30, \"N001\", centro)", "sol"),
    ("msg", 4, 5, "guardar recursos.txt y movimientos.txt", "sol"),
    ("msg", 4, 2, "{:ok, [{\"R001\", 30}]}   → quedan 20 L", "ok"),
    ("msg", 2, 4, "asignar(agua, 25, \"N002\", centro)", "sol"),
    ("nota", 4, 4, ["25 > 20 disponibles: no se descuenta nada"], ROJO),
    ("msg", 4, 2, "{:error, :inventario_insuficiente}", "err"),
    ("sep", "Paso 3 — la solicitud que falló deshace su reserva"),
    ("msg", 2, 3, "revertir(N002, 25)", "sol"),
    ("msg", 3, 2, "{:ok, N002: pendiente, 0 asignado}", "resp"),
    ("msg", 2, 0, "{:ok, \"Se asignaron 30 de agua a N001 (R001: 30).\"}", "ok"),
    ("msg", 2, 1, "{:error, \"No hay inventario suficiente.\"}", "err"),
    ("nota", 0, 1, ["Resultado: solo una solicitud se confirma. Nunca se asignan 55 litros de 50.",
                    "(Si llegara primero la de pedro, se confirmaría esa y fallaría la de laura.)"], VERDE),
]
secuencia("03b_secuencia_conflicto_concurrente.svg", "Diagrama de secuencia 2 — conflicto concurrente de recursos (50 litros)", participantes, pasos, ancho_col=235)
