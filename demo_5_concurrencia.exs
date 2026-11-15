# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Antes de correr: compilar Util2 una vez, dentro de esta carpeta:  elixirc util2.ex
Code.require_file("persistencia.exs", __DIR__)
Code.require_file("dominio/necesidades.exs", __DIR__)
Code.require_file("dominio/recursos.exs", __DIR__)
Code.require_file("dominio/albergues.exs", __DIR__)
Code.require_file("procesos/servidor_recursos.exs", __DIR__)
Code.require_file("procesos/servidor_necesidades.exs", __DIR__)
Code.require_file("procesos/servidor_albergues.exs", __DIR__)
Code.require_file("procesos/asignador.exs", __DIR__)

defmodule Demo5Concurrencia do
  @carpeta_datos Path.join(__DIR__, "datos")

  # ---------- El "qué" ----------
  def main do
    Util2.mostrar("=== DEMO MANDADA 5: PROCESOS CONCURRENTES ===", :mensaje)

    File.rm_rf(@carpeta_datos)
    iniciar_servidores()

    escenario_del_enunciado()
    escenario_muchos_pedidos()
    escenario_misma_necesidad()
    escenario_albergue_lleno()
    escenario_reinicio()

    File.rm_rf(@carpeta_datos)
  end

  # ---------- Escenario 1: los 50 litros ----------
  defp escenario_del_enunciado do
    titulo("1. Los 50 litros: una necesidad de 30 y otra de 25 al mismo tiempo")

    {:ok, _} = ServidorRecursos.registrar("R001", "agua", "agua", 50, "litros", "centro_acopio_1", "centro")
    {:ok, n1} = ServidorNecesidades.registrar("agua", 30, "critica", "centro", "Punto de atención sector 3", "laura")
    {:ok, n2} = ServidorNecesidades.registrar("agua", 25, "critica", "centro", "Albergue centro", "pedro")

    resultados = pedir_a_la_vez([{n1.id, "agua", 30}, {n2.id, "agua", 25}])
    mostrar_resultados(resultados)

    disponible = ServidorRecursos.disponible_total(%{categoria: "agua"})
    verificar("se asignó exactamente una de las dos (no 55 litros)", contar_exitos(resultados) == 1)
    verificar("el inventario nunca superó lo que había (quedan #{disponible} de 50)", disponible in [20, 25])

    # La necesidad que no obtuvo recursos debe quedar como estaba (pendiente, 0 asignado)
    fallida = resultados |> Enum.find(fn {_id, resultado} -> match?({:error, _}, resultado) end) |> elem(0)
    {:ok, necesidad_fallida} = ServidorNecesidades.obtener(fallida)
    verificar("#{fallida} quedó pendiente con 0 asignado", necesidad_fallida.estado == "pendiente" and necesidad_fallida.cantidad_asignada == 0)

    # Cancelar la necesidad que sí recibió recursos: se devuelven al inventario
    exitosa = resultados |> Enum.find(fn {_id, resultado} -> match?({:ok, _}, resultado) end) |> elem(0)
    Util2.mostrar("\nCancelando #{exitosa} (la que recibió recursos):", :mensaje)
    Util2.mostrar("  #{inspect(Asignador.cancelar_necesidad(exitosa))}", :mensaje)
    verificar("los 50 litros volvieron al inventario", ServidorRecursos.disponible_total(%{categoria: "agua"}) == 50)

    Util2.mostrar("Cancelando #{exitosa} otra vez:", :mensaje)
    Util2.mostrar("  #{inspect(Asignador.cancelar_necesidad(exitosa))}", :mensaje)
    verificar("no se devolvió dos veces (siguen 50)", ServidorRecursos.disponible_total(%{categoria: "agua"}) == 50)
  end

  # ---------- Escenario 2: 20 pedidos contra 50 kg ----------
  defp escenario_muchos_pedidos do
    titulo("2. Veinte pedidos de 10 kg al mismo tiempo contra 50 kg")

    {:ok, _} = ServidorRecursos.registrar("R010", "arroz", "alimentos", 50, "kg", "centro_acopio_1", "centro")

    ids =
      1..20
      |> Enum.map(fn numero ->
        {:ok, necesidad} = ServidorNecesidades.registrar("alimentos", 10, "media", "centro", "Familia #{numero}", "laura")
        necesidad.id
      end)

    resultados = ids |> Enum.map(&{&1, "alimentos", 10}) |> pedir_a_la_vez()

    exitos = contar_exitos(resultados)
    Util2.mostrar("Pedidos aceptados: #{exitos}. Rechazados: #{20 - exitos}.", :mensaje)

    todas = ServidorNecesidades.consultar(%{tipo: "alimentos"})
    asignadas = Enum.count(todas, &(&1.estado == "asignada"))
    limpias = Enum.count(todas, &(&1.estado == "pendiente" and &1.cantidad_asignada == 0))

    verificar("se aceptaron exactamente 5 (5 x 10 = 50 kg)", exitos == 5)
    verificar("el inventario quedó en 0, nunca negativo", ServidorRecursos.disponible_total(%{categoria: "alimentos"}) == 0)
    verificar("5 necesidades asignadas y 15 pendientes sin nada asignado", asignadas == 5 and limpias == 15)
  end

  # ---------- Escenario 3: cinco pedidos para la misma necesidad ----------
  defp escenario_misma_necesidad do
    titulo("3. Cinco pedidos al mismo tiempo para UNA necesidad de 10 unidades")

    {:ok, _} = ServidorRecursos.registrar("R020", "suero", "medicamentos", 100, "unidades", "centro_acopio_2", "norte")
    {:ok, necesidad} = ServidorNecesidades.registrar("medicamentos", 10, "alta", "norte", "Clínica", "laura")

    resultados = pedir_a_la_vez(List.duplicate({necesidad.id, "medicamentos", 10}, 5))
    mostrar_resultados(resultados)

    verificar("solo un pedido consumió recursos", contar_exitos(resultados) == 1)
    verificar("el inventario bajó 10, no 50 (quedan 90)", ServidorRecursos.disponible_total(%{categoria: "medicamentos"}) == 90)
  end

  # ---------- Escenario 4: último cupo de un albergue ----------
  defp escenario_albergue_lleno do
    titulo("4. Diez personas piden entrar a la vez a un albergue con 3 cupos")

    {:ok, _} = ServidorAlbergues.registrar("A01", "Albergue Norte", "norte", 3)

    padre = self()

    Enum.each(1..10, fn numero ->
      spawn(fn -> send(padre, {:resultado, numero, ServidorAlbergues.registrar_ingreso("A01", "doc#{numero}")}) end)
    end)

    resultados = recibir_resultados(10)
    entraron = Enum.count(resultados, fn {_id, resultado} -> match?({:ok, _}, resultado) end)
    {:ok, cupos} = ServidorAlbergues.consultar_cupos("A01")

    Util2.mostrar("Entraron #{entraron} de 10. Ocupación: #{cupos.ocupacion}/#{cupos.capacidad}.", :mensaje)
    verificar("entraron exactamente 3 y la ocupación no superó la capacidad", entraron == 3 and cupos.ocupacion == 3)
  end

  # ---------- Escenario 5: reiniciar el servidor ----------
  defp escenario_reinicio do
    titulo("5. Detener y volver a iniciar el servidor de recursos")

    antes = ServidorRecursos.consultar()
    :ok = ServidorRecursos.detener()
    {:ok, _pid} = ServidorRecursos.start_link()
    despues = ServidorRecursos.consultar()

    verificar("el inventario es igual después de reiniciar (se recuperó del archivo)", antes == despues)
  end

  # ---------- El "cómo" ----------

  # Lanza un proceso por cada pedido, TODOS a la vez, y espera las respuestas.
  # Cada proceso le manda su resultado al proceso principal con `send`.
  defp pedir_a_la_vez(pedidos) do
    padre = self()

    Enum.each(pedidos, fn {id_necesidad, categoria, cantidad} ->
      spawn(fn -> send(padre, {:resultado, id_necesidad, Asignador.asignar(id_necesidad, categoria, cantidad)}) end)
    end)

    recibir_resultados(length(pedidos))
  end

  # Caso base: no faltan respuestas
  defp recibir_resultados(0), do: []

  # Caso recursivo: recibe una respuesta y espera las que faltan
  defp recibir_resultados(faltan) do
    receive do
      {:resultado, id, resultado} -> [{id, resultado} | recibir_resultados(faltan - 1)]
    after
      5_000 -> []
    end
  end

  defp contar_exitos(resultados) do
    Enum.count(resultados, fn {_id, resultado} -> match?({:ok, _}, resultado) end)
  end

  defp mostrar_resultados(resultados) do
    Enum.each(resultados, fn {id, resultado} ->
      Util2.mostrar("  #{id} => #{inspect(resultado)}", :mensaje)
    end)
  end

  defp iniciar_servidores do
    {:ok, _} = ServidorRecursos.start_link()
    {:ok, _} = ServidorNecesidades.start_link()
    {:ok, _} = ServidorAlbergues.start_link()
  end

  defp titulo(texto), do: Util2.mostrar("\n--- #{texto} ---", :mensaje)

  defp verificar(descripcion, true), do: Util2.mostrar("  [OK]    #{descripcion}", :mensaje)
  defp verificar(descripcion, false), do: Util2.mostrar("  [FALLO] #{descripcion}", :error)
end

Demo5Concurrencia.main()
