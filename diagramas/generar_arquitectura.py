from svgkit import Lienzo

L = Lienzo(1500, 1130, "Arquitectura de módulos — Sistema distribuido de gestión de emergencias")

AZUL, NARANJA, VERDE, MORADO, GRIS, AMARILLO = "#1E88E5", "#FB8C00", "#43A047", "#8E24AA", "#607D8B", "#F9A825"

# ---------- Zonas ----------
L.zona(40, 70, 1420, 120, "NODOS CLIENTE (uno por usuario: --sname nodocliente1@localhost, nodocliente2...)", "#E3F2FD", AZUL)
L.zona(40, 230, 1420, 215, "NODO SERVIDOR — entrada y coordinación (--sname nodoservidor@localhost)", "#FFF3E0", NARANJA)
L.zona(40, 490, 1420, 250, "PROCESOS — cada GenServer atiende UN mensaje a la vez y guarda su archivo después de cada cambio", "#E8F5E9", VERDE)
L.zona(40, 780, 1420, 125, "DOMINIO — funciones puras (reciben datos y devuelven datos; no tienen procesos)", "#F3E5F5", MORADO)
L.zona(40, 945, 1420, 100, "SOPORTE", "#ECEFF1", GRIS)

# ---------- Cliente ----------
L.caja(540, 105, 420, 66, ["cliente.exs", "leer comando · OptionParser.split · enviar · mostrar respuesta"], "#FFFFFF", AZUL)

# ---------- Servidor: entrada ----------
L.caja(70, 275, 340, 70, ["servidor.exs", "Process.register(:servicio_emergencias)", "un spawn por solicitud"], "#FFFFFF", NARANJA)
L.caja(480, 275, 400, 70, ["Servicio", "sesión → permisos → validar datos →", "llamar al servidor → anotar actividad"], "#FFFFFF", NARANJA)
L.caja(950, 275, 330, 70, ["Asignador", "reservar en la necesidad → tomar recursos", "→ deshacer la reserva si falla"], "#FFFFFF", NARANJA)
L.caja(480, 375, 190, 50, ["Permisos", "rol → comandos"], "#FFFFFF", NARANJA)
L.caja(690, 375, 190, 50, ["Presentacion", "datos y errores → texto"], "#FFFFFF", NARANJA)

# ---------- Procesos ----------
L.caja(70, 540, 250, 56, ["SupervisorPrincipal", "Supervisor · one_for_one"], "#C8E6C9", VERDE)
L.caja(70, 625, 250, 56, ["SupervisorSesiones", "DynamicSupervisor"], "#C8E6C9", VERDE)
L.caja(70, 690, 250, 38, ["Sesion (una por usuario conectado)"], "#C8E6C9", VERDE, tam=11)

nombres = ["Usuarios", "Zonas", "Necesidades", "Recursos", "Albergues", "Personas", "Mensajes", "Mascotas"]
ancho, hueco, x0 = 122, 10, 400
xs = [x0 + i * (ancho + hueco) for i in range(8)]
for x, n in zip(xs, nombres):
    L.caja(x, 600, ancho, 56, ["Servidor", n], "#FFFFFF", VERDE, tam=12)

# ---------- Dominio ----------
dominio = ["Usuarios", "Zonas\n(árbol recursivo)", "Necesidades", "Recursos", "Albergues", "Personas", "Mensajes", "Mascotas"]
for x, n in zip(xs, dominio):
    L.caja(x, 820, ancho, 56, n.split("\n"), "#FFFFFF", MORADO, tam=12)

# ---------- Soporte ----------
L.caja(400, 975, 380, 56, ["Persistencia", "guardar · agregar · cargar · validar_campos · a_entero"], "#FFFFFF", GRIS)
L.caja(840, 975, 380, 56, ["Util2 (del profe)", "mostrar · ordenar · convertir_coleccion_mensaje"], "#FFFFFF", GRIS)

# ---------- Archivos ----------
L.caja(330, 1070, 840, 46,
       ["datos/*.txt  —  usuarios · actividad · zonas · necesidades · recursos · movimientos · albergues · personas · mensajes · mascotas"],
       "#FFFDE7", AMARILLO, tam=12)

# ---------- Flechas ----------
# Cliente -> servidor.exs (mensaje entre nodos) y respuesta de vuelta
L.flecha([(560, 171), (560, 200), (190, 200), (190, 275)], AZUL, 2.6)
L.etiqueta(375, 200, "mensaje {usuario, comando, argumentos} entre nodos (misma cookie)", AZUL, 11, 395)
L.flecha([(330, 275), (330, 224), (860, 224), (860, 171)], AZUL, 1.8, dash="6,4")
L.etiqueta(595, 224, "respuesta {:ok | :error, texto}", AZUL, 11, 215)
# servidor.exs -> Servicio
L.flecha([(410, 310), (480, 310)], NARANJA, 2.2)
# Servicio -> Asignador, Permisos, Presentacion
L.flecha([(880, 310), (950, 310)], NARANJA, 2.0)
L.flecha([(560, 345), (560, 375)], NARANJA, 1.8)
L.flecha([(790, 345), (790, 375)], NARANJA, 1.8)
# Servicio -> GenServers (barra)
L.flecha([(680, 345), (680, 466), (xs[0] + ancho / 2, 466)], VERDE, 2.0, sin_punta=True)
L.fondo(xs[0] + ancho / 2, 464, xs[-1] - xs[0], 4, VERDE, VERDE, 2, 1)
for x in xs:
    L.flecha([(x + ancho / 2, 468), (x + ancho / 2, 600)], VERDE, 1.6)
L.etiqueta(1010, 482, "GenServer.call(servidor, mensaje): Servicio llama a cada servidor", VERDE, 11, 420)
# Asignador -> Necesidades / Recursos
L.flecha([(1115, 345), (1115, 420), (xs[2] + ancho / 2 + 20, 420), (xs[2] + ancho / 2 + 20, 600)], NARANJA, 1.8, dash="5,3")
L.flecha([(1180, 345), (1180, 436), (xs[3] + ancho / 2 + 20, 436), (xs[3] + ancho / 2 + 20, 600)], NARANJA, 1.8, dash="5,3")
L.etiqueta(1115, 402, "reservar / revertir", NARANJA, 10, 120)
L.etiqueta(1235, 436, "asignar", NARANJA, 10, 60)
# Supervisor: vigila a los 8 servidores (barra punteada) y a las sesiones
L.flecha([(320, 568), (360, 568), (360, 592), (xs[0] + ancho / 2, 592)], VERDE, 1.8, dash="5,3", sin_punta=True)
L.flecha([(xs[0] + ancho / 2, 592), (xs[-1] + ancho / 2, 592)], VERDE, 1.8, dash="5,3", sin_punta=True)
L.etiqueta(1010, 592, "supervisa y reinicia a cada servidor (one_for_one)", VERDE, 11, 335)
L.flecha([(195, 596), (195, 625)], VERDE, 1.6, dash="5,3", sin_punta=True)
L.flecha([(195, 681), (195, 690)], VERDE, 1.6, dash="5,3")
# ServidorUsuarios crea y termina sesiones a través del DynamicSupervisor
L.flecha([(xs[0], 640), (320, 653)], VERDE, 1.6, dash="2,3", etiqueta="crea\nsesión", ancho_et=48, pos=0.5, tam_et=9, desplazar=(0, -14))
# GenServer -> dominio
for x in xs:
    L.flecha([(x + ancho / 2, 656), (x + ancho / 2, 820)], MORADO, 1.6)
L.etiqueta(xs[4] + ancho / 2, 740, "cada servidor llama a su módulo de dominio", MORADO, 11, 290)
# Dominio -> Persistencia / Util2
L.flecha([(590, 876), (590, 975)], GRIS, 2.0, etiqueta="cargar / guardar", pos=0.45, ancho_et=120)
L.flecha([(1030, 876), (1030, 975)], GRIS, 1.6, dash="5,3", etiqueta="ordenar", pos=0.45, ancho_et=70)
# Persistencia -> archivos
L.flecha([(590, 1031), (590, 1070)], AMARILLO, 2.2, etiqueta="File.read / File.write", pos=0.5, desplazar=(90, 0), ancho_et=150)

L.guardar("01_arquitectura_modulos.svg")
