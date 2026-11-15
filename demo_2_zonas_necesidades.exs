# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Antes de correr: compilar Util2 una vez, dentro de esta carpeta:  elixirc util2.ex
Code.require_file("persistencia.exs", __DIR__)
Code.require_file("dominio/zonas.exs", __DIR__)
Code.require_file("dominio/necesidades.exs", __DIR__)

defmodule Demo2ZonasNecesidades do
  # ---------- El "qué" ----------
  def main do
    Util2.mostrar("=== DEMO MANDADA 2: ZONAS Y NECESIDADES ===\n", :mensaje)

    probar_zonas()
    probar_necesidades()
  end

  # ---------- Zonas ----------
  defp probar_zonas do
    Util2.mostrar("--- ZONAS ---", :mensaje)

    zonas =
      %{}
      |> aplicar("registrar zona centro", &Zonas.registrar_zona(&1, "centro", "Centro", "critico", 100))
      |> aplicar("registrar zona norte", &Zonas.registrar_zona(&1, "norte", "Norte", "medio", 40))
      |> aplicar("sector s1 en centro", &Zonas.agregar_sector(&1, "centro", "s1", "Sector 1", "alto", 50))
      |> aplicar("sector s2 en centro", &Zonas.agregar_sector(&1, "centro", "s2", "Sector 2", "medio", 30))
      |> aplicar("punto p1 en s2", &Zonas.agregar_punto(&1, "centro", "s2", "p1", "Punto 1", "bajo", 10))
      # Errores esperados:
      |> aplicar("zona repetida", &Zonas.registrar_zona(&1, "centro", "Otra", "bajo"))
      |> aplicar("nivel inválido", &Zonas.registrar_zona(&1, "sur", "Sur", "gigante"))
      |> aplicar("sector en zona inexistente", &Zonas.agregar_sector(&1, "sur", "s1", "S", "bajo"))
      |> aplicar("punto en sector inexistente", &Zonas.agregar_punto(&1, "centro", "s9", "p1", "P", "bajo"))
      |> aplicar("personas negativas", &Zonas.agregar_sector(&1, "norte", "s1", "S", "bajo", -5))

    Util2.mostrar("\nEstado de centro (100 + 50 + 30 + 10 = 190 personas):", :mensaje)
    zonas |> Zonas.estado_zona("centro") |> mostrar_estado()

    Util2.mostrar("\nGuardar y recargar zonas:", :mensaje)
    guardar_y_recargar(zonas, &Zonas.guardar/1, &Zonas.cargar/0)
  end

  # ---------- Necesidades ----------
  defp probar_necesidades do
    Util2.mostrar("\n--- NECESIDADES ---", :mensaje)

    necesidades =
      %{}
      |> aplicar("N001 agua 30 critica", &Necesidades.registrar(&1, "agua", 30, "critica", "centro", "Punto sector 3", "laura"))
      |> aplicar("N002 alimentos 10 baja", &Necesidades.registrar(&1, "alimentos", 10, "baja", "centro", "Albergue", "laura"))
      |> aplicar("N003 rescate 2 critica", &Necesidades.registrar(&1, "rescate", 2, "critica", "norte", "Edificio caído", "andres"))
      |> aplicar("N004 medicamentos 5 alta", &Necesidades.registrar(&1, "medicamentos", 5, "alta", "centro", "Clínica", "laura"))
      # Errores esperados:
      |> aplicar("cantidad 0", &Necesidades.registrar(&1, "agua", 0, "alta", "centro", "x", "laura"))
      |> aplicar("tipo inválido", &Necesidades.registrar(&1, "oro", 5, "alta", "centro", "x", "laura"))
      |> aplicar("prioridad inválida", &Necesidades.registrar(&1, "agua", 5, "urgente", "centro", "x", "laura"))

    Util2.mostrar("\nTodas, por prioridad (esperado: N001, N003, N004, N002):", :mensaje)
    necesidades |> Necesidades.consultar() |> mostrar_lista()

    Util2.mostrar("\nFiltro zona=centro y prioridad=critica (esperado: N001):", :mensaje)
    necesidades |> Necesidades.consultar(%{zona: "centro", prioridad: "critica"}) |> mostrar_lista()

    Util2.mostrar("\nSiguiente a atender (esperado: N001):", :mensaje)
    necesidades |> Necesidades.siguiente_a_atender() |> mostrar_siguiente()

    Util2.mostrar("\nAsignaciones sobre N001 (pide 30):", :mensaje)

    necesidades =
      necesidades
      |> aplicar("asignar 20", &Necesidades.registrar_asignacion(&1, "N001", 20))
      |> aplicar("asignar 15 (excede)", &Necesidades.registrar_asignacion(&1, "N001", 15))
      |> aplicar("asignar 10 (completa)", &Necesidades.registrar_asignacion(&1, "N001", 10))
      |> aplicar("asignar 5 más (ya asignada)", &Necesidades.registrar_asignacion(&1, "N001", 5))

    Util2.mostrar("\nCambios de estado:", :mensaje)

    necesidades =
      necesidades
      |> aplicar("N001 -> en_atencion", &Necesidades.cambiar_estado(&1, "N001", "en_atencion"))
      |> aplicar("N001 -> atendida", &Necesidades.cambiar_estado(&1, "N001", "atendida"))
      |> aplicar("N001 -> atendida otra vez", &Necesidades.cambiar_estado(&1, "N001", "atendida"))
      |> aplicar("N001 -> cancelada", &Necesidades.cambiar_estado(&1, "N001", "cancelada"))
      |> aplicar("N001 recibe asignación", &Necesidades.registrar_asignacion(&1, "N001", 1))
      |> aplicar("N002 pendiente -> atendida", &Necesidades.cambiar_estado(&1, "N002", "atendida"))
      |> aplicar("N002 -> cancelada", &Necesidades.cambiar_estado(&1, "N002", "cancelada"))
      |> aplicar("N999 inexistente", &Necesidades.cambiar_estado(&1, "N999", "cancelada"))

    Util2.mostrar("\nPendientes (esperado: N003, N004):", :mensaje)
    necesidades |> Necesidades.pendientes() |> mostrar_lista()

    Util2.mostrar("\nGuardar y recargar necesidades:", :mensaje)
    guardar_y_recargar(necesidades, &Necesidades.guardar/1, &Necesidades.cargar/0)
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
  defp mostrar_resultado(etiqueta, {:ok, _nuevo}), do: Util2.mostrar("  ok    #{etiqueta}", :mensaje)
  defp mostrar_resultado(etiqueta, {:ok, _nuevo, _elemento}), do: Util2.mostrar("  ok    #{etiqueta}", :mensaje)
  defp mostrar_resultado(etiqueta, {:error, motivo}), do: Util2.mostrar("  ERROR #{etiqueta} => #{inspect(motivo)}", :mensaje)

  defp mostrar_estado({:ok, estado}) do
    Util2.mostrar("  Personas: #{estado.personas_afectadas}, sectores: #{estado.sectores}, puntos: #{estado.puntos_atencion}", :mensaje)

    estado.detalle_sectores
    |> Enum.map(&"  - #{&1.codigo}: #{&1.personas_afectadas} personas, #{&1.puntos_atencion} puntos")
    |> Enum.each(&Util2.mostrar(&1, :mensaje))
  end

  defp mostrar_estado({:error, motivo}), do: Util2.mostrar("  ERROR: #{inspect(motivo)}", :error)

  defp mostrar_lista(necesidades) do
    necesidades
    |> Util2.convertir_coleccion_mensaje(&"  #{&1.id} [#{&1.prioridad}] #{&1.tipo} #{&1.cantidad_asignada}/#{&1.cantidad} en #{&1.zona} (#{&1.estado})")
    |> Enum.each(&Util2.mostrar(&1, :mensaje))
  end

  defp mostrar_siguiente({:ok, necesidad}), do: Util2.mostrar("  #{necesidad.id} (#{necesidad.prioridad})", :mensaje)
  defp mostrar_siguiente({:error, motivo}), do: Util2.mostrar("  #{inspect(motivo)}", :mensaje)

  defp guardar_y_recargar(datos, guardar, cargar) do
    with :ok <- guardar.(datos),
         {:ok, recargados} <- cargar.() do
      Util2.mostrar("  ¿Quedó igual al recargar? #{datos == recargados}", :mensaje)
    else
      {:error, razon} -> Util2.mostrar("  ERROR de archivo: #{inspect(razon)}", :error)
    end
  end
end

Demo2ZonasNecesidades.main()
