# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Cliente de PRUEBA para el nodo servidor (el cliente real se hace en la mandada 7).
# En OTRA terminal, con el servidor ya corriendo:
#
#   elixir --sname nodocliente@localhost --cookie my_cookie cliente_prueba.exs


defmodule ClientePrueba do
  @nombre_servicio_cliente :servicio_respuesta
  @nodo_servidor :nodoservidor@localhost
  @servicio_servidor {:servicio_emergencias, @nodo_servidor}

  def main do
    Process.register(self(), @nombre_servicio_cliente)

    Util2.mostrar("\n=== CLIENTE DE PRUEBA ===", :mensaje)
    Util2.mostrar("Nodo: #{node()}", :mensaje)

    case Node.connect(@nodo_servidor) do
      true ->
        Util2.mostrar("Conectado a #{@nodo_servidor}.\n", :mensaje)
        probar_comandos()

      false ->
        Util2.mostrar("ERROR: no fue posible conectar con #{@nodo_servidor}.", :error)

      :ignored ->
        Util2.mostrar("ERROR: el cliente no se inició como nodo distribuido.", :error)
    end
  end

  defp probar_comandos do
    [
      {nil, "ping", []},
      {nil, "connect", ["laura", "1234", "coordinador", "centro"]},
      {nil, "connect", ["laura", "mala", "coordinador", "centro"]},
      {"laura", "comando_inventado", []},
      {"laura", "disconnect", []},
      {"laura", "disconnect", []}
    ]
    |> Enum.each(&enviar_y_mostrar/1)

    send(@servicio_servidor, {{@nombre_servicio_cliente, node()}, :apagar})

    receive do
      :apagado -> Util2.mostrar("\nEl servidor confirmó que se apagó.", :mensaje)
    after
      5_000 -> Util2.mostrar("ERROR: el servidor no confirmó el apagado.", :error)
    end
  end

  defp enviar_y_mostrar(mensaje) do
    Util2.mostrar("Enviando: #{inspect(mensaje)}", :mensaje)
    send(@servicio_servidor, {{@nombre_servicio_cliente, node()}, mensaje})

    receive do
      {:respuesta, resultado} -> Util2.mostrar("  Respuesta: #{inspect(resultado)}", :mensaje)
    after
      5_000 -> Util2.mostrar("  ERROR: no llegó respuesta.", :error)
    end
  end
end

ClientePrueba.main()
