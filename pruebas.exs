# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Ejecuta TODAS las pruebas del proyecto. Desde la carpeta del proyecto:
#
#   elixirc util2.ex      (una sola vez)
#   elixir pruebas.exs
#
# Usa ExUnit, la librería de pruebas que viene con Elixir (no necesita Mix).
# Las pruebas trabajan en una carpeta temporal: NO tocan la carpeta datos/.

Code.require_file("cargar_procesos.exs", __DIR__)

ExUnit.start()

Code.require_file("pruebas/pruebas_dominio.exs", __DIR__)
Code.require_file("pruebas/pruebas_procesos.exs", __DIR__)
