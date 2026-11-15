# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

Code.require_file("persistencia.exs", __DIR__)
Code.require_file("dominio/usuarios.exs", __DIR__)

defmodule Demo1Usuarios do
  # ---------- El "qué" ----------
  def main do
    Util2.mostrar("=== DEMO MANDADA 1: USUARIOS Y PERSISTENCIA ===\n", :mensaje)

    %{}
    |> probar_conexion("laura", "1234", "coordinador", "centro")   # => registrado
    |> probar_conexion("laura", "1234", "coordinador", "centro")   # => autenticado
    |> probar_conexion("laura", "9999", "coordinador", "centro")   # => contraseña incorrecta
    |> probar_conexion("pedro", "abc", "jefe", "norte")            # => tipo inválido
    |> probar_conexion("ana;x", "abc", "ciudadano", "norte")       # => carácter inválido
    |> probar_conexion("andres", "xyz", "ciudadano", "norte")      # => registrado
    |> guardar_y_recargar()
    |> probar_actividad()
  end

  # ---------- El "cómo" ----------

  # Prueba un comando connect, muestra el resultado y devuelve los usuarios actualizados.
  defp probar_conexion(usuarios, nombre, contrasena, tipo, zona) do
    Util2.mostrar("connect #{nombre} #{contrasena} #{tipo} #{zona}", :mensaje)

    resultado = Usuarios.conectar(usuarios, nombre, contrasena, tipo, zona)
    mostrar_resultado(resultado)

    usuarios_actualizados(resultado, usuarios)
  end

  defp usuarios_actualizados({:ok, nuevos_usuarios, _usuario, _como}, _anteriores),
    do: nuevos_usuarios

  defp usuarios_actualizados({:error, _motivo}, anteriores), do: anteriores

  defp guardar_y_recargar(usuarios) do
    Util2.mostrar("\n--- Guardar en archivo y volver a cargar ---", :mensaje)

    with :ok <- Usuarios.guardar(usuarios),
         {:ok, recargados} <- Usuarios.cargar() do
      Util2.mostrar("Guardados: #{map_size(usuarios)}. Recargados: #{map_size(recargados)}.", :mensaje)
      Util2.mostrar("¿Son iguales? #{usuarios == recargados}", :mensaje)
      recargados
    else
      {:error, razon} ->
        Util2.mostrar("ERROR de archivo: #{inspect(razon)}", :error)
        usuarios
    end
  end

  defp probar_actividad(usuarios) do
    Util2.mostrar("\n--- Actividad ---", :mensaje)
    Usuarios.registrar_actividad("laura", "register_need agua 30 critica centro")
    Usuarios.registrar_actividad("laura", "summary")
    Usuarios.registrar_actividad("andres", "report_person 123 Andres norte localizada")

    {:ok, registros} = Usuarios.consultar_actividad("laura")
    Util2.mostrar("Acciones de laura: #{length(registros)}", :mensaje)

    registros
    |> Enum.map(fn [_fecha, _usuario, accion] -> " - #{accion}" end)
    |> Enum.each(&Util2.mostrar(&1, :mensaje))

    usuarios
  end

  # Una sola función que imprime, con una cláusula por cada forma del resultado.
  defp mostrar_resultado({:ok, _usuarios, usuario, :registrado}),
    do: Util2.mostrar("  => Registrado automáticamente como #{usuario.tipo} en #{usuario.zona}\n", :mensaje)

  defp mostrar_resultado({:ok, _usuarios, usuario, :autenticado}),
    do: Util2.mostrar("  => Bienvenido de nuevo, #{usuario.nombre_usuario}\n", :mensaje)

  defp mostrar_resultado({:error, motivo}),
    do: Util2.mostrar("  => ERROR: #{inspect(motivo)}\n", :error)
end

Demo1Usuarios.main()
