# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Antes de correr: compilar Util2 una vez, dentro de esta carpeta:  elixirc util2.ex
Code.require_file("persistencia.exs", __DIR__)
Code.require_file("dominio/recursos.exs", __DIR__)
Code.require_file("dominio/albergues.exs", __DIR__)

defmodule Demo3RecursosAlbergues do
  # ---------- El "qué" ----------
  def main do
    Util2.mostrar("=== DEMO MANDADA 3: RECURSOS Y ALBERGUES ===\n", :mensaje)

    probar_recursos()
    probar_albergues()
  end

  # ---------- Recursos ----------
  defp probar_recursos do
    Util2.mostrar("--- RECURSOS ---", :mensaje)

    inventario =
      Recursos.nuevo()
      |> aplicar("R001 agua 50 litros (zona centro)", &Recursos.registrar(&1, "R001", "agua", "agua", 50, "litros", "centro_acopio_1", "centro"))
      |> aplicar("R002 agua 100 litros (zona norte)", &Recursos.registrar(&1, "R002", "agua", "agua", 100, "litros", "centro_acopio_2", "norte"))
      |> aplicar("R003 alimentos 5 kg", &Recursos.registrar(&1, "R003", "alimentos", "alimentos", 5, "kg", "centro_acopio_1", "centro"))
      # Errores esperados:
      |> aplicar("código repetido", &Recursos.registrar(&1, "R001", "x", "x", 1, "u", "u", "z"))
      |> aplicar("cantidad negativa", &Recursos.registrar(&1, "R009", "x", "x", -5, "u", "u", "z"))
      # Entradas y salidas:
      |> aplicar("entrada R001 +10 (queda 60)", &Recursos.registrar_entrada(&1, "R001", 10, "donación"))
      |> aplicar("salida R003 -8 (solo hay 5)", &Recursos.registrar_salida(&1, "R003", 8, "reparto"))
      |> aplicar("salida R003 -2 (queda 3)", &Recursos.registrar_salida(&1, "R003", 2, "reparto"))
      # Asignaciones (R001 tiene 60 y es de la zona centro):
      |> aplicar("asignar agua 30 a N001 (zona centro)", &Recursos.asignar(&1, "agua", 30, "N001", "centro"))
      |> aplicar("asignar agua 25 a N002 (zona centro)", &Recursos.asignar(&1, "agua", 25, "N002", "centro"))
      # Transferencias (R001 queda con 5):
      |> aplicar("transferir R001 3 -> albergue_2", &Recursos.transferir(&1, "R001", "centro_acopio_1", "albergue_2", 3))
      |> aplicar("transferir R001 10 (solo quedan 2)", &Recursos.transferir(&1, "R001", "centro_acopio_1", "albergue_2", 10))
      |> aplicar("transferir desde ubicación equivocada", &Recursos.transferir(&1, "R001", "otro_lugar", "albergue_2", 1))
      # Asignación que necesita varios recursos: 2 de R001, 3 de R001-albergue_2 y 35 de R002
      |> aplicar("asignar agua 40 a N003 (zona centro)", &Recursos.asignar(&1, "agua", 40, "N003", "centro"))
      |> aplicar("asignar agua 500 (no alcanza)", &Recursos.asignar(&1, "agua", 500, "N004", "centro"))

    Util2.mostrar("\nTodo el recurso (esperado: R001=0, R001-albergue_2=0, R002=65, R003=3):", :mensaje)
    inventario |> Recursos.consultar() |> mostrar_recursos()

    Util2.mostrar("\nAgua disponible en total (esperado 65): #{Recursos.disponible_total(inventario, %{categoria: "agua"})}", :mensaje)

    Util2.mostrar("\nCon poco inventario (<= 10): #{inspect(Enum.map(Recursos.con_poco_inventario(inventario), & &1.codigo))}", :mensaje)

    Util2.mostrar("\nHistorial de R001:", :mensaje)

    inventario
    |> Recursos.historial("R001")
    |> Util2.convertir_coleccion_mensaje(&"  #{&1.numero}. #{&1.tipo} #{&1.cantidad} (#{&1.detalle})")
    |> Enum.each(&Util2.mostrar(&1, :mensaje))

    Util2.mostrar("\nGuardar y recargar inventario:", :mensaje)
    guardar_y_recargar(inventario, &Recursos.guardar/1, &Recursos.cargar/0)
  end

  # ---------- Albergues ----------
  defp probar_albergues do
    Util2.mostrar("\n--- ALBERGUES ---", :mensaje)

    albergues =
      %{}
      |> aplicar("A01 capacidad 3, ocupación 1", &Albergues.registrar(&1, "A01", "Albergue Norte", "norte", 3, 1))
      |> aplicar("A02 capacidad 10, ocupación 8", &Albergues.registrar(&1, "A02", "Albergue Sur", "sur", 10, 8))
      # Errores esperados:
      |> aplicar("código repetido", &Albergues.registrar(&1, "A01", "Otro", "norte", 5))
      |> aplicar("capacidad 0", &Albergues.registrar(&1, "A03", "Otro", "norte", 0))
      |> aplicar("ocupación mayor que capacidad", &Albergues.registrar(&1, "A03", "Otro", "norte", 5, 9))
      # Ingresos y salidas:
      |> aplicar("entra 111 a A01", &Albergues.registrar_ingreso(&1, "A01", "111"))
      |> aplicar("entra 222 a A01 (queda lleno)", &Albergues.registrar_ingreso(&1, "A01", "222"))
      |> aplicar("entra 333 a A01 (sin cupo)", &Albergues.registrar_ingreso(&1, "A01", "333"))
      |> aplicar("entra 111 a A02 (ya está en A01)", &Albergues.registrar_ingreso(&1, "A02", "111"))
      |> aplicar("sale 111 de A01", &Albergues.registrar_salida(&1, "A01", "111"))
      |> aplicar("sale 111 otra vez", &Albergues.registrar_salida(&1, "A01", "111"))
      |> aplicar("entra 111 a A02 (ahora sí)", &Albergues.registrar_ingreso(&1, "A02", "111"))

    Util2.mostrar("\nCupos de A01 (esperado: capacidad 3, ocupación 2, cupos 1):", :mensaje)
    albergues |> Albergues.consultar_cupos("A01") |> mostrar_cupos()

    Util2.mostrar("\nMayor ocupación (esperado: A02 90.0%, A01 66.7%):", :mensaje)

    albergues
    |> Albergues.mayor_ocupacion()
    |> Util2.convertir_coleccion_mensaje(&"  #{&1.codigo} #{&1.nombre}: #{&1.ocupacion}/#{&1.capacidad} = #{&1.porcentaje}%")
    |> Enum.each(&Util2.mostrar(&1, :mensaje))

    Util2.mostrar("\nGuardar y recargar albergues:", :mensaje)
    guardar_y_recargar(albergues, &Albergues.guardar/1, &Albergues.cargar/0)
  end

  # ---------- El "cómo" ----------

  # Ejecuta una operación, muestra su resultado y devuelve el estado actualizado
  # (si hubo error, devuelve el estado anterior sin cambios).
  defp aplicar(estado, etiqueta, operacion) do
    resultado = operacion.(estado)
    mostrar_resultado(etiqueta, resultado)
    estado_nuevo(resultado, estado)
  end

  defp estado_nuevo({:ok, nuevo}, _anterior), do: nuevo
  defp estado_nuevo({:ok, nuevo, _elemento}, _anterior), do: nuevo
  defp estado_nuevo({:error, _motivo}, anterior), do: anterior

  # Una sola función que imprime resultados, con una cláusula por cada forma.
  defp mostrar_resultado(etiqueta, {:ok, _nuevo, tomas}) when is_list(tomas),
    do: Util2.mostrar("  ok    #{etiqueta} => tomó #{inspect(tomas)}", :mensaje)

  defp mostrar_resultado(etiqueta, {:ok, _nuevo}), do: Util2.mostrar("  ok    #{etiqueta}", :mensaje)
  defp mostrar_resultado(etiqueta, {:ok, _nuevo, _elemento}), do: Util2.mostrar("  ok    #{etiqueta}", :mensaje)
  defp mostrar_resultado(etiqueta, {:error, motivo}), do: Util2.mostrar("  ERROR #{etiqueta} => #{inspect(motivo)}", :mensaje)

  defp mostrar_recursos(recursos) do
    recursos
    |> Util2.convertir_coleccion_mensaje(&"  #{&1.codigo} #{&1.categoria}: #{&1.cantidad} #{&1.unidad} en #{&1.ubicacion} (#{&1.zona})")
    |> Enum.each(&Util2.mostrar(&1, :mensaje))
  end

  defp mostrar_cupos({:ok, cupos}) do
    Util2.mostrar("  #{cupos.codigo}: capacidad #{cupos.capacidad}, ocupación #{cupos.ocupacion}, cupos #{cupos.cupos}", :mensaje)
  end

  defp mostrar_cupos({:error, motivo}), do: Util2.mostrar("  ERROR: #{inspect(motivo)}", :error)

  defp guardar_y_recargar(datos, guardar, cargar) do
    with :ok <- guardar.(datos),
         {:ok, recargados} <- cargar.() do
      Util2.mostrar("  ¿Quedó igual al recargar? #{datos == recargados}", :mensaje)
    else
      {:error, razon} -> Util2.mostrar("  ERROR de archivo: #{inspect(razon)}", :error)
    end
  end
end

Demo3RecursosAlbergues.main()
