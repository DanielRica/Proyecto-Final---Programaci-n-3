# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Nodo SERVIDOR. Se ejecuta en una terminal, dentro de la carpeta del proyecto:
#
#   elixir --sname nodoservidor@localhost --cookie my_cookie servidor.exs
#
# (Antes: compilar Util2 una vez con  elixirc util2.ex )

Code.require_file("cargar_procesos.exs", __DIR__)

defmodule NodoServidor do
  @nombre_servicio :servicio_emergencias

  # ---------- El "qué" ----------
  def main do
    Process.register(self(), @nombre_servicio)

    Util2.mostrar("\n=== NODO SERVIDOR (emergencias) ===", :mensaje)
    Util2.mostrar("Nodo: #{node()}", :mensaje)
    Util2.mostrar("Proceso registrado como: #{@nombre_servicio}", :mensaje)

    case iniciar_procesos() do
      :ok ->
        Util2.mostrar("Procesos iniciados. Esperando solicitudes...\n", :mensaje)
        esperar_mensajes()
        Util2.mostrar("Servidor finalizado.", :mensaje)

      {:error, motivo} ->
        Util2.mostrar("ERROR: no se pudieron iniciar los procesos: #{inspect(motivo)}", :error)
    end
  end

  # ---------- El "cómo" ----------

  defp iniciar_procesos do
    case SupervisorPrincipal.start_link() do
      {:ok, _pid} -> :ok
      {:error, motivo} -> {:error, motivo}
    end
  end

  # Cada solicitud se atiende en un proceso nuevo (`spawn`), así varios
  # clientes pueden ser atendidos al mismo tiempo sin esperar unos a otros.
  # La consistencia de los datos la garantizan los GenServers.
  defp esperar_mensajes do
    receive do
      {cliente, :apagar} ->
        Util2.mostrar("Recibí :apagar. Voy a terminar.", :mensaje)
        send(cliente, :apagado)
        :ok

      {cliente, mensaje} ->
        spawn(fn -> atender(cliente, mensaje) end)
        esperar_mensajes()
    end
  end

  defp atender(cliente, mensaje) do
    Util2.mostrar("Solicitud: #{inspect(mensaje)}", :mensaje)
    send(cliente, {:respuesta, ejecutar_sin_caerse(mensaje)})
  end

  # Red de seguridad: si algo inesperado falla al ejecutar un comando (un error
  # del programa o un servidor que no responde), el cliente recibe un mensaje
  # de error en vez de quedarse esperando. `try/rescue/catch` captura el fallo.
  defp ejecutar_sin_caerse(mensaje) do
    try do
      Servicio.ejecutar(mensaje)
    rescue
      error -> {:error, "Error interno del servidor: #{Exception.message(error)}"}
    catch
      :exit, motivo -> {:error, "Un servicio no respondió: #{inspect(motivo)}"}
    end
  end
end

NodoServidor.main()
