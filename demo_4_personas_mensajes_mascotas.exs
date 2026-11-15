# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Antes de correr: compilar Util2 una vez, dentro de esta carpeta:  elixirc util2.ex
Code.require_file("persistencia.exs", __DIR__)
Code.require_file("dominio/personas.exs", __DIR__)
Code.require_file("dominio/mensajes.exs", __DIR__)
Code.require_file("dominio/mascotas.exs", __DIR__)

defmodule Demo4PersonasMensajesMascotas do
  # ---------- El "qué" ----------
  def main do
    Util2.mostrar("=== DEMO MANDADA 4: PERSONAS, MENSAJES Y MASCOTAS ===\n", :mensaje)

    probar_personas()
    probar_mensajes()
    probar_mascotas()
  end

  # ---------- Personas ----------
  defp probar_personas do
    Util2.mostrar("--- PERSONAS ---", :mensaje)

    personas =
      %{}
      |> aplicar("111 Andrés (localizada)", &Personas.registrar(&1, "111", "Andrés", "norte", "localizada"))
      |> aplicar("222 María López, 34 años (reportada)", &Personas.registrar(&1, "222", "María López", "centro", "reportada", 34))
      |> aplicar("333 Juan (sin_informacion)", &Personas.registrar(&1, "333", "Juan", "sur", "sin_informacion"))
      # Errores esperados:
      |> aplicar("documento repetido", &Personas.registrar(&1, "111", "Otro", "norte", "reportada"))
      |> aplicar("estado inválido", &Personas.registrar(&1, "444", "Pedro", "norte", "perdido"))
      |> aplicar("edad negativa", &Personas.registrar(&1, "444", "Pedro", "norte", "reportada", -1))
      # Cambios de estado:
      |> aplicar("111 -> en_albergue", &Personas.cambiar_estado(&1, "111", "en_albergue"))
      |> aplicar("111 -> reportada (volver atrás)", &Personas.cambiar_estado(&1, "111", "reportada"))
      |> aplicar("111 -> reunificada", &Personas.cambiar_estado(&1, "111", "reunificada"))
      |> aplicar("111 -> localizada (ya reunificada)", &Personas.cambiar_estado(&1, "111", "localizada"))
      |> aplicar("222 -> localizada", &Personas.cambiar_estado(&1, "222", "localizada"))
      |> aplicar("222 -> localizada otra vez", &Personas.cambiar_estado(&1, "222", "localizada"))
      |> aplicar("999 inexistente", &Personas.cambiar_estado(&1, "999", "localizada"))

    Util2.mostrar("\nHistorial de 111 (esperado: localizada, en_albergue, reunificada):", :mensaje)
    personas |> Personas.historial("111") |> mostrar_historial()

    Util2.mostrar("\nBuscar nombre 'and' (esperado: Andrés):", :mensaje)
    personas |> Personas.buscar(%{nombre: "and"}) |> mostrar_personas()

    Util2.mostrar("\nBuscar zona=centro (esperado: María López):", :mensaje)
    personas |> Personas.buscar(%{zona: "centro"}) |> mostrar_personas()

    Util2.mostrar("\nBuscar estado=localizada (esperado: María López):", :mensaje)
    personas |> Personas.buscar(%{estado: "localizada"}) |> mostrar_personas()

    Util2.mostrar("\nFind person 333:", :mensaje)
    personas |> Personas.buscar_por_documento("333") |> mostrar_una_persona()

    Util2.mostrar("\nGuardar y recargar personas:", :mensaje)
    guardar_y_recargar(personas, &Personas.guardar/1, &Personas.cargar/0)
  end

  # ---------- Mensajes ----------
  defp probar_mensajes do
    Util2.mostrar("\n--- MENSAJES ---", :mensaje)
    fecha = Mensajes.fecha_actual()

    mensajes =
      %{}
      |> aplicar("laura -> 111", &Mensajes.enviar(&1, fecha, "laura", "111", "Estoy bien, estoy en el albergue norte"))
      |> aplicar("pedro -> 111", &Mensajes.enviar(&1, fecha, "pedro", "111", "Mamá pregunta por ti"))
      |> aplicar("ana -> 222", &Mensajes.enviar(&1, fecha, "ana", "222", "Te busco en el centro"))
      # Errores esperados:
      |> aplicar("contenido vacío", &Mensajes.enviar(&1, fecha, "laura", "111", ""))
      |> aplicar("contenido con ;", &Mensajes.enviar(&1, fecha, "laura", "111", "hola; adiós"))
      # Estados:
      |> aplicar("MSG001 -> entregado", &Mensajes.marcar_entregado(&1, "MSG001"))
      |> aplicar("MSG001 -> entregado otra vez", &Mensajes.marcar_entregado(&1, "MSG001"))
      |> aplicar("MSG999 inexistente", &Mensajes.marcar_entregado(&1, "MSG999"))

    Util2.mostrar("\nMensajes para 111 (esperado: MSG001 entregado, MSG002 pendiente):", :mensaje)
    mensajes |> Mensajes.listar_para("111") |> mostrar_mensajes()

    Util2.mostrar("\nPendientes para 111 (esperado: MSG002):", :mensaje)
    mensajes |> Mensajes.listar_para("111", "pendiente") |> mostrar_mensajes()

    Util2.mostrar("\nGuardar y recargar mensajes:", :mensaje)
    guardar_y_recargar(mensajes, &Mensajes.guardar/1, &Mensajes.cargar/0)
  end

  # ---------- Mascotas ----------
  defp probar_mascotas do
    Util2.mostrar("\n--- MASCOTAS ---", :mensaje)

    reportes =
      %{}
      |> aplicar("PET001 perdida: perro Luna negra mediana norte", &Mascotas.registrar(&1, "perdida", "perro", "Luna", "negra", "mediana", "norte", "3001234567", "collar rojo manchas blancas"))
      |> aplicar("PET002 perdida: gato Michi blanco pequeña centro", &Mascotas.registrar(&1, "perdida", "gato", "Michi", "blanco", "pequena", "centro", "3009999999"))
      |> aplicar("PET003 encontrada: perro negra mediana norte", &Mascotas.registrar(&1, "encontrada", "perro", "desconocido", "negra", "mediana", "norte", "3112223333", "collar rojo"))
      |> aplicar("PET004 encontrada: perro café grande sur", &Mascotas.registrar(&1, "encontrada", "perro", "desconocido", "cafe", "grande", "sur", "3124445555"))
      # Errores esperados:
      |> aplicar("tipo inválido", &Mascotas.registrar(&1, "vista", "perro", "x", "negra", "mediana", "norte", "1"))
      |> aplicar("tamaño inválido", &Mascotas.registrar(&1, "perdida", "perro", "x", "negra", "enorme", "norte", "1"))

    Util2.mostrar("\nPuntajes entre todos los pares perdida/encontrada:", :mensaje)
    mostrar_puntaje(reportes, "PET001", "PET003", "95 esperado")
    mostrar_puntaje(reportes, "PET001", "PET004", "30 esperado: solo la especie")
    mostrar_puntaje(reportes, "PET002", "PET003", "0 esperado: gato contra perro")

    Util2.mostrar("\nmatch_pets (esperado: solo PET001 con PET003, 95 puntos):", :mensaje)

    reportes =
      reportes
      |> aplicar("marcar posibles", &Mascotas.marcar_posibles/1)

    reportes |> Mascotas.consultar(%{estado: "posible_coincidencia"}) |> mostrar_reportes()

    Util2.mostrar("\nConfirmar coincidencia:", :mensaje)

    reportes =
      reportes
      |> aplicar("confirmar al revés (PET003, PET001)", &Mascotas.confirmar_coincidencia(&1, "PET003", "PET001"))
      |> aplicar("confirmar PET001 con PET003", &Mascotas.confirmar_coincidencia(&1, "PET001", "PET003"))
      |> aplicar("confirmar otra vez", &Mascotas.confirmar_coincidencia(&1, "PET001", "PET003"))
      |> aplicar("confirmar con PET999", &Mascotas.confirmar_coincidencia(&1, "PET001", "PET999"))

    Util2.mostrar("\nResueltas (esperado: PET001 y PET003, cada una apuntando a la otra):", :mensaje)
    reportes |> Mascotas.consultar(%{estado: "resuelta"}) |> mostrar_reportes()

    Util2.mostrar("\nPerros (esperado: PET001, PET003, PET004):", :mensaje)
    reportes |> Mascotas.consultar(%{especie: "perro"}) |> mostrar_reportes()

    Util2.mostrar("\nActivas (esperado: PET002, PET004):", :mensaje)
    reportes |> Mascotas.consultar(%{estado: "activa"}) |> mostrar_reportes()

    Util2.mostrar("\nGuardar y recargar reportes:", :mensaje)
    guardar_y_recargar(reportes, &Mascotas.guardar/1, &Mascotas.cargar/0)
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
  defp mostrar_resultado(etiqueta, {:ok, _nuevo, coincidencias}) when is_list(coincidencias),
    do: Util2.mostrar("  ok    #{etiqueta} => #{inspect(coincidencias)}", :mensaje)

  defp mostrar_resultado(etiqueta, {:ok, _nuevo}), do: Util2.mostrar("  ok    #{etiqueta}", :mensaje)
  defp mostrar_resultado(etiqueta, {:ok, _nuevo, _elemento}), do: Util2.mostrar("  ok    #{etiqueta}", :mensaje)
  defp mostrar_resultado(etiqueta, {:error, motivo}), do: Util2.mostrar("  ERROR #{etiqueta} => #{inspect(motivo)}", :mensaje)

  defp mostrar_historial({:ok, historial}), do: Util2.mostrar("  #{Enum.join(historial, " -> ")}", :mensaje)
  defp mostrar_historial({:error, motivo}), do: Util2.mostrar("  ERROR: #{inspect(motivo)}", :error)

  defp mostrar_una_persona({:ok, persona}), do: mostrar_personas([persona])
  defp mostrar_una_persona({:error, motivo}), do: Util2.mostrar("  ERROR: #{inspect(motivo)}", :error)

  defp mostrar_personas(personas) do
    personas
    |> Util2.convertir_coleccion_mensaje(&"  #{&1.documento} #{&1.nombre} (#{&1.zona}) edad=#{inspect(&1.edad)} estado=#{&1.estado}")
    |> Enum.each(&Util2.mostrar(&1, :mensaje))
  end

  defp mostrar_mensajes(mensajes) do
    mensajes
    |> Util2.convertir_coleccion_mensaje(&"  #{&1.id} de #{&1.remitente} para #{&1.destinatario} [#{&1.estado}]: #{&1.contenido}")
    |> Enum.each(&Util2.mostrar(&1, :mensaje))
  end

  defp mostrar_reportes(reportes) do
    reportes
    |> Util2.convertir_coleccion_mensaje(&"  #{&1.id} #{&1.tipo} #{&1.especie} #{&1.color} #{&1.tamano} #{&1.zona} [#{&1.estado}] coincidencia=#{&1.coincidencia}")
    |> Enum.each(&Util2.mostrar(&1, :mensaje))
  end

  defp mostrar_puntaje(reportes, id_a, id_b, esperado) do
    puntaje = Mascotas.puntaje(Map.fetch!(reportes, id_a), Map.fetch!(reportes, id_b))
    Util2.mostrar("  #{id_a} vs #{id_b}: #{puntaje} (#{esperado})", :mensaje)
  end

  defp guardar_y_recargar(datos, guardar, cargar) do
    with :ok <- guardar.(datos),
         {:ok, recargados} <- cargar.() do
      Util2.mostrar("  ¿Quedó igual al recargar? #{datos == recargados}", :mensaje)
    else
      {:error, razon} -> Util2.mostrar("  ERROR de archivo: #{inspect(razon)}", :error)
    end
  end
end

Demo4PersonasMensajesMascotas.main()
