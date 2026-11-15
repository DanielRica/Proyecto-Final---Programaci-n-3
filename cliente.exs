# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Nodo CLIENTE. Cada usuario abre una terminal y ejecuta, dentro de la carpeta del
# proyecto (con el servidor ya corriendo en otra terminal):
#
#   elixir --sname nodocliente1@localhost --cookie my_cookie cliente.exs
#
# Con varios usuarios al mismo tiempo, cada terminal debe usar un nombre de nodo
# DIFERENTE (nodocliente1, nodocliente2, ...), pero la misma cookie.
#
# Si el servidor está en otra máquina, cambie @nodo_servidor (por ejemplo
# :nodoservidor@servidor) y revise la ACLARACIÓN sobre el archivo hosts de la guía.
#
# Antes: compilar Util2 una vez con  elixirc util2.ex

defmodule Cliente do
  @nombre_servicio_cliente :servicio_respuesta
  @nodo_servidor :nodoservidor@localhost
  @servicio_servidor {:servicio_emergencias, @nodo_servidor}
  @espera_respuesta 10_000

  # ---------- El "qué" ----------
  def main do
    Process.register(self(), @nombre_servicio_cliente)

    Util2.mostrar("\n=== CLIENTE (emergencias) ===", :mensaje)
    Util2.mostrar("Nodo: #{node()}", :mensaje)

    case Node.connect(@nodo_servidor) do
      true ->
        Util2.mostrar("Conectado a #{@nodo_servidor}. Escriba help para ver los comandos y salir para terminar.\n", :mensaje)
        ciclo(nil)

      false ->
        Util2.mostrar("ERROR: no fue posible conectar con #{@nodo_servidor}. ¿Está corriendo el servidor? ¿Es la misma cookie?", :error)

      :ignored ->
        Util2.mostrar("ERROR: el cliente no se inició como nodo distribuido (falta --sname).", :error)
    end
  end

  # ---------- El "cómo" ----------

  # Lee un comando, lo envía al servidor, muestra la respuesta y repite.
  # `usuario` es el nombre del usuario conectado (o nil si todavía no se ha conectado).
  defp ciclo(usuario) do
    case leer_linea(usuario) do
      :fin -> terminar(usuario)
      linea -> linea |> String.trim() |> atender_linea(usuario)
    end
  end

  defp atender_linea("", usuario), do: ciclo(usuario)
  defp atender_linea(linea, usuario) when linea in ["salir", "exit", "quit"], do: terminar(usuario)

  defp atender_linea(linea, usuario) do
    # OptionParser.split respeta las comillas: "Zona Centro" queda como UN argumento
    case OptionParser.split(linea) do
      [] ->
        ciclo(usuario)

      ["connect" | _argumentos] when usuario != nil ->
        mostrar_respuesta({:error, "Ya está conectado como #{usuario}. Use disconnect antes de cambiar de usuario."})
        ciclo(usuario)

      [comando | argumentos] ->
        respuesta = consultar_servidor({usuario, comando, argumentos})
        mostrar_respuesta(respuesta)
        ciclo(usuario_despues(usuario, comando, argumentos, respuesta))
    end
  end

  # Envía el comando al servidor y espera su respuesta
  defp consultar_servidor(mensaje) do
    send(@servicio_servidor, {{@nombre_servicio_cliente, node()}, mensaje})

    receive do
      {:respuesta, respuesta} -> respuesta
    after
      @espera_respuesta -> {:error, "El servidor no respondió a tiempo."}
    end
  end

  # El usuario cambia solo si connect o disconnect salieron bien
  defp usuario_despues(_usuario, "connect", [nombre_usuario | _resto], {:ok, _texto}), do: nombre_usuario
  defp usuario_despues(_usuario, "disconnect", _argumentos, {:ok, _texto}), do: nil
  defp usuario_despues(usuario, _comando, _argumentos, _respuesta), do: usuario

  # Una sola función que imprime, con una cláusula por cada forma de la respuesta
  defp mostrar_respuesta({:ok, texto}), do: Util2.mostrar(texto <> "\n", :mensaje)
  defp mostrar_respuesta({:error, texto}), do: Util2.mostrar("ERROR: " <> texto <> "\n", :error)

  # Si el usuario sigue conectado, se desconecta antes de salir
  defp terminar(nil), do: Util2.mostrar("Hasta pronto.", :mensaje)

  defp terminar(usuario) do
    consultar_servidor({usuario, "disconnect", []})
    Util2.mostrar("Sesión cerrada. Hasta pronto.", :mensaje)
  end

  # Lee una línea del teclado. IO.gets devuelve :eof cuando no hay más entrada
  # (por ejemplo, al terminar un archivo de comandos que se le pasa con <).
  defp leer_linea(usuario) do
    indicador = if usuario == nil, do: "> ", else: "#{usuario}> "

    case IO.gets(indicador) do
      :eof -> :fin
      {:error, _razon} -> :fin
      linea -> mostrar_eco(linea)
    end
  end

  # Con ECO_COMANDOS=1 se repite el comando leído (útil al usar un archivo de comandos)
  defp mostrar_eco(linea) do
    if System.get_env("ECO_COMANDOS") == "1", do: Util2.mostrar(String.trim(linea), :mensaje)
    linea
  end
end

Cliente.main()
