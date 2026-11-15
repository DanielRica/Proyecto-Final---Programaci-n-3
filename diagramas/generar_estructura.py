from svgkit import Lienzo

AZUL, NARANJA, VERDE, MORADO, GRIS, AMARILLO = "#1E88E5", "#FB8C00", "#43A047", "#8E24AA", "#607D8B", "#F9A825"

# (sangría, nombre, comentario, color)
filas = [
    (0, "proyecto/", "", "#000000"),
    (1, "util2.ex", "Util2 del profe (se compila con: elixirc util2.ex)", GRIS),
    (1, "persistencia.exs", "guardar / agregar / cargar archivos de texto", GRIS),
    (1, "cargar_procesos.exs", "carga todos los módulos del sistema", GRIS),
    (1, "servidor.exs", "NODO SERVIDOR (arranca el supervisor y recibe comandos)", NARANJA),
    (1, "cliente.exs", "NODO CLIENTE (cada usuario abre uno)", AZUL),
    (1, "cliente_prueba.exs", "cliente mínimo para probar el servidor y apagarlo", AZUL),
    (1, "pruebas.exs", "ejecuta las 87 pruebas (ExUnit)", VERDE),
    (1, "demo_1 ... demo_6 (.exs)", "demostraciones por mandada (usuarios ... supervisión)", GRIS),
    (1, "flujo_1 ... flujo_4 (.txt)", "comandos del flujo de ejemplo del enunciado", GRIS),
    (1, "EXPLICACION_COMPLETA.md", "cómo funciona, cómo correrlo, solución de problemas", GRIS),
    (1, "GUIA_SUSTENTACION.md", "guion del video, preguntas frecuentes, checklist", GRIS),
    (1, "poner_integrantes.exs", "escribe los nombres de los integrantes en todos los archivos", GRIS),
    (1, "dominio/", "LÓGICA PURA (8 módulos)", MORADO),
    (2, "usuarios.exs  zonas.exs  necesidades.exs  recursos.exs", "", "#444444"),
    (2, "albergues.exs  personas.exs  mensajes.exs  mascotas.exs", "", "#444444"),
    (1, "procesos/", "PROCESOS Y COORDINACIÓN (14 archivos)", VERDE),
    (2, "supervisor_principal.exs", "Supervisor + DynamicSupervisor", "#444444"),
    (2, "servidor_usuarios.exs  sesion.exs", "GenServer de usuarios + una Sesion por usuario", "#444444"),
    (2, "servidor_zonas.exs  servidor_necesidades.exs  servidor_recursos.exs", "", "#444444"),
    (2, "servidor_albergues.exs  servidor_personas.exs  servidor_mensajes.exs  servidor_mascotas.exs", "", "#444444"),
    (2, "asignador.exs", "coordina necesidades y recursos", "#444444"),
    (2, "servicio.exs  permisos.exs  presentacion.exs", "comandos, roles y textos de respuesta", "#444444"),
    (1, "pruebas/", "PRUEBAS", VERDE),
    (2, "pruebas_dominio.exs  pruebas_procesos.exs", "60 + 27 pruebas", "#444444"),
    (1, "diagramas/", "imágenes y fuentes de los diagramas", GRIS),
    (1, "datos/", "SE CREA AL EJECUTAR: un archivo .txt por entidad", AMARILLO),
]

ALTO_FILA = 25
L = Lienzo(1250, 100 + ALTO_FILA * len(filas), "Estructura del proyecto")
L.fondo(30, 60, 1190, 30 + ALTO_FILA * len(filas), "#FAFAFA", "#BDBDBD", 12, 1.5)
for i, (nivel, nombre, comentario, color) in enumerate(filas):
    y = 96 + i * ALTO_FILA
    x = 56 + nivel * 36
    if nivel > 0:
        L.texto(x - 20, y, "├─", tam=13, ancla="start", color="#9E9E9E", mono=True)
    carpeta = nombre.endswith("/")
    L.texto(x, y, nombre, tam=13, negrita=carpeta, ancla="start", color=color if carpeta else "#222222", mono=True)
    if comentario:
        L.texto(640 if nivel < 2 else 700, y, "# " + comentario, tam=12, ancla="start", color="#757575")
L.guardar("05_estructura_proyecto.svg")
