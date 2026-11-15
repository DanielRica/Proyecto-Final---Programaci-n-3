# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Carga todos los módulos del sistema. Los scripts principales (servidor, demos)
# solo necesitan llamar a este archivo con:  Code.require_file("cargar_procesos.exs", __DIR__)
# Antes de correr: compilar Util2 una vez, dentro de esta carpeta:  elixirc util2.ex

Code.require_file("persistencia.exs", __DIR__)

Enum.each(
  ["usuarios", "zonas", "necesidades", "recursos", "albergues", "personas", "mensajes", "mascotas"],
  fn modulo -> Code.require_file("dominio/#{modulo}.exs", __DIR__) end
)

Enum.each(
  [
    "sesion",
    "servidor_usuarios",
    "servidor_zonas",
    "servidor_necesidades",
    "servidor_recursos",
    "servidor_albergues",
    "servidor_personas",
    "servidor_mensajes",
    "servidor_mascotas",
    "asignador",
    "permisos",
    "presentacion",
    "servicio",
    "supervisor_principal"
  ],
  fn modulo -> Code.require_file("procesos/#{modulo}.exs", __DIR__) end
)
