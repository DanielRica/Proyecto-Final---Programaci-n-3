from svgkit import Lienzo

L = Lienzo(1500, 800, "Árbol de procesos y supervisión (OTP)")
AZUL, NARANJA, VERDE, GRIS, AMARILLO = "#1E88E5", "#FB8C00", "#43A047", "#607D8B", "#F9A825"

# Proceso principal del nodo servidor
L.caja(490, 70, 520, 70, ["servidor.exs  (proceso principal del nodo servidor)",
                          "Process.register(:servicio_emergencias) · receive",
                          "arranca SupervisorPrincipal y atiende mensajes"], "#FFF3E0", NARANJA, tam=12)
L.caja(1090, 78, 330, 54, ["atender (proceso efímero)", "un spawn por solicitud → Servicio"], "#F5F5F5", GRIS, tam=11, dash="5,3")
L.flecha([(1010, 105), (1090, 105)], GRIS, 1.6, dash="5,3", etiqueta="spawn", ancho_et=44, pos=0.5)

# Supervisor raíz
L.caja(490, 190, 520, 70, ["SupervisorPrincipal  (Supervisor)",
                           "estrategia :one_for_one",
                           "max_restarts: 5 en max_seconds: 10"], "#C8E6C9", VERDE, tam=12, grosor=2.5)
L.flecha([(750, 140), (750, 190)], NARANJA, 2.2, etiqueta="start_link", ancho_et=80, pos=0.5)

# Fila de hijos
x0 = 77
dyn_x, dyn_w = x0, 190
ancho, hueco = 135, 8
sx = [x0 + dyn_w + 20 + i * (ancho + hueco) for i in range(8)]
y_hijos = 340

L.caja(dyn_x, y_hijos, dyn_w, 70, ["SupervisorSesiones", "DynamicSupervisor", "(se llena en ejecución)"], "#C8E6C9", VERDE, tam=11, grosor=2.5)
nombres = [("ServidorUsuarios", ["usuarios.txt", "actividad.txt"]), ("ServidorZonas", ["zonas.txt"]),
           ("ServidorNecesidades", ["necesidades.txt"]), ("ServidorRecursos", ["recursos.txt", "movimientos.txt"]),
           ("ServidorAlbergues", ["albergues.txt"]), ("ServidorPersonas", ["personas.txt"]),
           ("ServidorMensajes", ["mensajes.txt"]), ("ServidorMascotas", ["mascotas.txt"])]
for x, (n, _) in zip(sx, nombres):
    L.caja(x, y_hijos, ancho, 70, [n.replace("Servidor", "Servidor\n").split("\n")[0], n.replace("Servidor", "")], "#FFFFFF", VERDE, tam=11, grosor=2)

# Barra de supervisión
centros = [dyn_x + dyn_w / 2] + [x + ancho / 2 for x in sx]
L.flecha([(750, 260), (750, 300)], VERDE, 2.4, sin_punta=True)
L.flecha([(centros[0], 300), (centros[-1], 300)], VERDE, 2.4, sin_punta=True)
for c in centros:
    L.flecha([(c, 300), (c, y_hijos)], VERDE, 2.0)
L.etiqueta(750, 300, "supervisa: los arranca en este orden y los reinicia si mueren", VERDE, 11, 420)

# Sesiones dinámicas
L.caja(dyn_x + 10, 470, 170, 48, ["Sesion  laura", "(coordinador)"], "#E8F5E9", VERDE, tam=11, dash="5,3")
L.caja(dyn_x + 10, 540, 170, 48, ["Sesion  andres", "(ciudadano)"], "#E8F5E9", VERDE, tam=11, dash="5,3")
L.flecha([(dyn_x + 95, y_hijos + 70), (dyn_x + 95, 470)], VERDE, 1.8, dash="5,3", etiqueta="start_child", ancho_et=80, pos=0.5)
L.flecha([(dyn_x + 95, 518), (dyn_x + 95, 540)], VERDE, 1.8, dash="5,3")
L.texto(dyn_x + 10, 612, "restart: :temporary — si una sesión", tam=10, ancla="start", color="#2E7D32")
L.texto(dyn_x + 10, 626, "muere, no se reinicia; el usuario", tam=10, ancla="start", color="#2E7D32")
L.texto(dyn_x + 10, 640, "se conecta de nuevo.", tam=10, ancla="start", color="#2E7D32")
# ServidorUsuarios crea las sesiones
L.flecha([(sx[0] + 20, y_hijos + 70), (sx[0] + 20, 440), (dyn_x + 190, 440), (dyn_x + 190, 494), (dyn_x + 180, 494)], VERDE, 1.4, dash="2,3")
L.etiqueta(sx[0] + 75, 440, "ServidorUsuarios pide crear/terminar sesiones", VERDE, 10, 285)

# Archivos de cada servidor
for x, (_, archivos) in zip(sx, nombres):
    alto = 22 * len(archivos) + 8
    L.caja(x + 5, 470, ancho - 10, alto, archivos, "#FFFDE7", AMARILLO, tam=11)
    L.flecha([(x + ancho / 2, y_hijos + 70), (x + ancho / 2, 470)], AMARILLO, 1.8, doble=True)
L.etiqueta(sx[4] + ancho / 2, 440, "init/1 carga el archivo · después de cada cambio se guarda", "#B8860B", 11, 380)

# Recuadro explicativo
L.fondo(330, 600, 1090, 150, "#F9FBE7", "#9E9D24", 12, 2)
L.texto(350, 626, "Qué pasa si un servidor se cae (Process.exit(pid, :kill))", tam=13, negrita=True, ancla="start", color="#827717")
lineas = [
    "1. El SupervisorPrincipal detecta que el proceso murió y lo reinicia (solo ese: estrategia :one_for_one).",
    "2. El proceso nuevo ejecuta init/1, que carga su archivo de texto: recupera el estado que tenía.",
    "3. Los demás procesos ni se enteran. Si ServidorUsuarios es el que cae, se cierran las sesiones huérfanas.",
    "4. Si hubiera más de 5 reinicios en 10 segundos, el supervisor se rinde (algo anda muy mal).",
    "Los GenServers procesan un mensaje a la vez: por eso no hay inconsistencias con solicitudes simultáneas.",
]
for i, l in enumerate(lineas):
    L.texto(350, 652 + i * 20, l, tam=12, ancla="start", color="#333333")

L.guardar("04_arbol_procesos_otp.svg")
