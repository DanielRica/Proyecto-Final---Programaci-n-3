# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Servicio do
  @moduledoc """
  Recibe los comandos de los clientes y los reparte a los servidores.

  Cada comando llega como una tupla `{usuario, comando, argumentos}`, por ejemplo
  `{"laura", "assign_resource", ["N001", "agua", "30"]}`. Los argumentos son
  textos tal como los escribió el usuario.

  Para cada comando (salvo `ping`, `help`, `connect` y `disconnect`) se hace, en orden:

  1. Comprobar que el usuario esté conectado.
  2. Comprobar que su tipo de usuario tenga permiso (`Permisos`).
  3. Validar los datos (números, que la zona exista...) y llamar al servidor correspondiente.
  4. Si salió bien, anotar el comando en la actividad del usuario.

  Siempre responde `{:ok, texto}` o `{:error, texto}`, con el texto listo
  para mostrar (`Presentacion`).
  """

  @filtros_necesidades %{"zona" => :zona, "tipo" => :tipo, "prioridad" => :prioridad, "estado" => :estado}
  @filtros_recursos %{"categoria" => :categoria, "zona" => :zona, "ubicacion" => :ubicacion}
  @filtros_personas %{"nombre" => :nombre, "zona" => :zona, "estado" => :estado, "documento" => :documento}
  @filtros_mascotas %{"especie" => :especie, "zona" => :zona, "estado" => :estado, "tipo" => :tipo}

  # ---------- El "qué" ----------

  @doc "Ejecuta un comando y devuelve `{:ok, texto}` o `{:error, texto}`."
  def ejecutar({usuario, comando, argumentos}) do
    case ejecutar_comando(usuario, comando, argumentos) do
      {:ok, texto} -> {:ok, texto}
      :ok -> {:ok, "Listo."}
      {:error, motivo} -> {:error, Presentacion.error(motivo)}
    end
  end

  # ---------- Comandos que no requieren sesión (o la manejan ellos) ----------

  defp ejecutar_comando(_usuario, "ping", []), do: {:ok, "pong"}

  defp ejecutar_comando(usuario, "help", []) do
    case obtener_sesion(usuario) do
      {:ok, sesion} ->
        {:ok, Presentacion.ayuda(Permisos.comandos_de(sesion.tipo))}

      {:error, _motivo} ->
        {:ok, "Primero conéctese:  connect usuario contraseña tipo zona\n(tipos: ciudadano, voluntario, coordinador, administrador)"}
    end
  end

  defp ejecutar_comando(_usuario, "connect", [nombre_usuario, contrasena, tipo, zona]) do
    with {:ok, %{usuario: datos, como: como}} <- ServidorUsuarios.conectar(nombre_usuario, contrasena, tipo, zona) do
      {:ok, "#{texto_conexion(como)} #{datos.nombre_usuario}, #{datos.tipo} de la zona #{datos.zona}."}
    end
  end

  defp ejecutar_comando(_usuario, "connect", _argumentos), do: {:error, {:uso_incorrecto, "connect"}}

  defp ejecutar_comando(usuario, "disconnect", []) when is_binary(usuario) do
    with :ok <- ServidorUsuarios.desconectar(usuario), do: {:ok, "Sesión cerrada. Hasta pronto, #{usuario}."}
  end

  # ---------- Comandos con sesión y permisos ----------

  defp ejecutar_comando(usuario, comando, argumentos) do
    with {:ok, sesion} <- obtener_sesion(usuario),
         :ok <- Permisos.verificar(sesion.tipo, comando),
         {:ok, texto} <- ejecutar_con_sesion(sesion, comando, argumentos) do
      # La actividad es "de cortesía": si no se puede anotar, no se le avisa al usuario.
      ServidorUsuarios.registrar_actividad(sesion.nombre_usuario, texto_comando(comando, argumentos))
      {:ok, texto}
    end
  end

  # ----- Zonas -----

  defp ejecutar_con_sesion(_sesion, "register_zone", [codigo, nombre, nivel | opcional]) when length(opcional) <= 1 do
    with {:ok, personas} <- personas_opcional(opcional),
         :ok <- ServidorZonas.registrar_zona(codigo, nombre, nivel, personas) do
      {:ok, "Zona #{codigo} registrada (#{nombre}, nivel #{nivel})."}
    end
  end

  defp ejecutar_con_sesion(_sesion, "register_sector", [zona, codigo, nombre, nivel | opcional]) when length(opcional) <= 1 do
    with {:ok, personas} <- personas_opcional(opcional),
         :ok <- ServidorZonas.agregar_sector(zona, codigo, nombre, nivel, personas) do
      {:ok, "Sector #{codigo} agregado a la zona #{zona}."}
    end
  end

  defp ejecutar_con_sesion(_sesion, "register_point", [zona, sector, codigo, nombre, nivel | opcional]) when length(opcional) <= 1 do
    with {:ok, personas} <- personas_opcional(opcional),
         :ok <- ServidorZonas.agregar_punto(zona, sector, codigo, nombre, nivel, personas) do
      {:ok, "Punto de atención #{codigo} agregado al sector #{sector} de la zona #{zona}."}
    end
  end

  defp ejecutar_con_sesion(_sesion, "zone_status", [zona]) do
    with {:ok, estado} <- ServidorZonas.estado_zona(zona), do: {:ok, Presentacion.estado_zona(estado)}
  end

  # ----- Necesidades -----

  defp ejecutar_con_sesion(sesion, "register_need", [tipo, cantidad, prioridad, zona | descripcion]) when descripcion != [] do
    with {:ok, cantidad} <- entero(cantidad),
         :ok <- validar_zona(zona),
         {:ok, necesidad} <-
           ServidorNecesidades.registrar(tipo, cantidad, prioridad, zona, Enum.join(descripcion, " "), sesion.nombre_usuario) do
      {:ok, "Necesidad registrada: " <> Presentacion.necesidad(necesidad)}
    end
  end

  defp ejecutar_con_sesion(_sesion, "list_needs", filtros_texto) do
    with {:ok, filtros} <- parsear_filtros(filtros_texto, @filtros_necesidades) do
      {:ok, listar(ServidorNecesidades.consultar(filtros), &Presentacion.necesidad/1, "No hay necesidades con esos filtros.")}
    end
  end

  defp ejecutar_con_sesion(_sesion, "pending_needs", []) do
    {:ok, listar(ServidorNecesidades.pendientes(), &Presentacion.necesidad/1, "No hay necesidades pendientes.")}
  end

  # Cancelar pasa siempre por cancel_need, para que se devuelvan los recursos asignados
  defp ejecutar_con_sesion(sesion, "change_need_status", [id, "cancelada"]) do
    ejecutar_con_sesion(sesion, "cancel_need", [id])
  end

  defp ejecutar_con_sesion(_sesion, "change_need_status", [id, estado]) do
    with {:ok, necesidad} <- ServidorNecesidades.cambiar_estado(id, estado) do
      {:ok, "Necesidad #{necesidad.id} ahora está en estado #{necesidad.estado}."}
    end
  end

  defp ejecutar_con_sesion(_sesion, "cancel_need", [id]) do
    with {:ok, devueltos} <- Asignador.cancelar_necesidad(id) do
      {:ok, "Necesidad #{id} cancelada. " <> texto_devueltos(devueltos)}
    end
  end

  # ----- Recursos -----

  defp ejecutar_con_sesion(sesion, "register_resource", [codigo, nombre, cantidad, unidad, ubicacion | opcional]) when length(opcional) <= 1 do
    # Si no se indica la zona, el recurso queda en la zona principal del usuario.
    zona = List.first(opcional, sesion.zona)

    with {:ok, cantidad} <- entero(cantidad),
         :ok <- validar_zona(zona),
         {:ok, recurso} <- ServidorRecursos.registrar(codigo, nombre, nombre, cantidad, unidad, ubicacion, zona) do
      {:ok, "Recurso registrado: " <> Presentacion.recurso(recurso)}
    end
  end

  defp ejecutar_con_sesion(_sesion, "list_resources", filtros_texto) do
    with {:ok, filtros} <- parsear_filtros(filtros_texto, @filtros_recursos) do
      {:ok, listar(ServidorRecursos.consultar(filtros), &Presentacion.recurso/1, "No hay recursos con esos filtros.")}
    end
  end

  defp ejecutar_con_sesion(_sesion, "assign_resource", [id, categoria, cantidad]) do
    with {:ok, cantidad} <- entero(cantidad),
         {:ok, tomas} <- Asignador.asignar(id, categoria, cantidad) do
      {:ok, "Se asignaron #{cantidad} de #{categoria} a #{id} (#{Presentacion.tomas(tomas)})."}
    end
  end

  defp ejecutar_con_sesion(_sesion, "transfer_resource", [codigo, origen, destino, cantidad]) do
    with {:ok, cantidad} <- entero(cantidad),
         {:ok, codigo_destino} <- ServidorRecursos.transferir(codigo, origen, destino, cantidad) do
      {:ok, "Se transfirieron #{cantidad} de #{codigo} (#{origen}) a #{destino}. En el destino queda como #{codigo_destino}."}
    end
  end

  defp ejecutar_con_sesion(_sesion, "critical_resources", []) do
    {:ok, Presentacion.criticos(faltantes_criticos(), ServidorRecursos.con_poco_inventario())}
  end

  # ----- Personas -----

  defp ejecutar_con_sesion(_sesion, "report_person", [documento, nombre, zona, estado | opcional]) when length(opcional) <= 1 do
    with {:ok, edad} <- edad_opcional(opcional),
         :ok <- validar_zona(zona),
         {:ok, persona} <- ServidorPersonas.registrar(documento, nombre, zona, estado, edad) do
      {:ok, "Persona registrada: " <> Presentacion.persona(persona)}
    end
  end

  defp ejecutar_con_sesion(_sesion, "find_person", [dato]) do
    if String.contains?(dato, "="), do: buscar_personas([dato]), else: buscar_persona_por_documento(dato)
  end

  defp ejecutar_con_sesion(_sesion, "find_person", filtros_texto) when filtros_texto != [] do
    buscar_personas(filtros_texto)
  end

  defp ejecutar_con_sesion(_sesion, "change_person_status", [documento, estado]) do
    with {:ok, persona} <- ServidorPersonas.cambiar_estado(documento, estado) do
      {:ok, "Estado actualizado: " <> Presentacion.persona(persona)}
    end
  end

  # ----- Mensajes entre familiares -----

  defp ejecutar_con_sesion(sesion, "send_family_message", [documento | partes]) when partes != [] do
    with {:ok, mensaje} <- ServidorMensajes.enviar(sesion.nombre_usuario, documento, Enum.join(partes, " ")) do
      {:ok, "Mensaje #{mensaje.id} enviado a #{documento} (pendiente de entrega)."}
    end
  end

  defp ejecutar_con_sesion(_sesion, "list_family_messages", [documento]) do
    {:ok, listar(ServidorMensajes.listar_para(documento), &Presentacion.mensaje/1, "No hay mensajes para #{documento}.")}
  end

  defp ejecutar_con_sesion(_sesion, "mark_message_delivered", [id]) do
    with {:ok, mensaje} <- ServidorMensajes.marcar_entregado(id), do: {:ok, "Mensaje #{mensaje.id} marcado como entregado."}
  end

  defp ejecutar_con_sesion(_sesion, "mark_message_pending", [id]) do
    with {:ok, mensaje} <- ServidorMensajes.marcar_pendiente(id), do: {:ok, "Mensaje #{mensaje.id} marcado como pendiente."}
  end

  # ----- Mascotas -----

  defp ejecutar_con_sesion(_sesion, "report_pet", [tipo, especie, nombre, color, tamano, zona, contacto | caracteristicas]) do
    caracteristicas = if caracteristicas == [], do: "sin_datos", else: Enum.join(caracteristicas, " ")

    with :ok <- validar_zona(zona),
         {:ok, reporte} <-
           ServidorMascotas.registrar(tipo_reporte(tipo), especie, nombre, color, tamano, zona, contacto, caracteristicas) do
      {:ok, "Reporte registrado: " <> Presentacion.reporte(reporte)}
    end
  end

  defp ejecutar_con_sesion(_sesion, "list_pets", filtros_texto) do
    with {:ok, filtros} <- parsear_filtros(filtros_texto, @filtros_mascotas) do
      {:ok, listar(ServidorMascotas.consultar(filtros), &Presentacion.reporte/1, "No hay reportes con esos filtros.")}
    end
  end

  defp ejecutar_con_sesion(_sesion, "match_pets", []) do
    with {:ok, coincidencias} <- ServidorMascotas.marcar_posibles() do
      {:ok, listar(coincidencias, &"#{&1.perdida} <-> #{&1.encontrada}: #{&1.puntaje} puntos de 100", "No hay posibles coincidencias.")}
    end
  end

  defp ejecutar_con_sesion(_sesion, "confirm_pet_match", [id_perdida, id_encontrada]) do
    with {:ok, _reportes_cerrados} <- ServidorMascotas.confirmar_coincidencia(id_perdida, id_encontrada) do
      {:ok, "Coincidencia confirmada: #{id_perdida} y #{id_encontrada} quedaron resueltos."}
    end
  end

  # ----- Albergues -----

  defp ejecutar_con_sesion(_sesion, "register_shelter", [codigo, nombre, zona, capacidad | opcional]) when length(opcional) <= 1 do
    with {:ok, capacidad} <- entero(capacidad),
         {:ok, ocupacion} <- personas_opcional(opcional),
         :ok <- validar_zona(zona),
         {:ok, albergue} <- ServidorAlbergues.registrar(codigo, nombre, zona, capacidad, ocupacion) do
      {:ok, "Albergue #{albergue.codigo} (#{albergue.nombre}) registrado con capacidad #{albergue.capacidad}."}
    end
  end

  defp ejecutar_con_sesion(_sesion, "check_shelter", [codigo]) do
    with {:ok, cupos} <- ServidorAlbergues.consultar_cupos(codigo), do: {:ok, Presentacion.cupos(cupos)}
  end

  defp ejecutar_con_sesion(_sesion, "register_entry", [codigo, documento]) do
    with {:ok, albergue} <- ServidorAlbergues.registrar_ingreso(codigo, documento) do
      {:ok, "Ingreso registrado en #{albergue.codigo}: #{albergue.ocupacion}/#{albergue.capacidad}." <> actualizar_estado_persona(documento)}
    end
  end

  defp ejecutar_con_sesion(_sesion, "register_exit", [codigo, documento]) do
    with {:ok, albergue} <- ServidorAlbergues.registrar_salida(codigo, documento) do
      {:ok, "Salida registrada en #{albergue.codigo}: #{albergue.ocupacion}/#{albergue.capacidad}."}
    end
  end

  defp ejecutar_con_sesion(_sesion, "top_shelters", opcional) when length(opcional) <= 1 do
    with {:ok, cantidad} <- cantidad_opcional(opcional, 3) do
      formato = &"#{&1.codigo} #{&1.nombre}: #{&1.ocupacion}/#{&1.capacidad} = #{&1.porcentaje}%"
      {:ok, listar(ServidorAlbergues.mayor_ocupacion(cantidad), formato, "No hay albergues registrados.")}
    end
  end

  # ----- General -----

  defp ejecutar_con_sesion(_sesion, "summary", []), do: {:ok, resumen_global()}

  defp ejecutar_con_sesion(sesion, "activity", []), do: actividad_de(sesion.nombre_usuario)

  defp ejecutar_con_sesion(%{tipo: "administrador"}, "activity", [otro_usuario]), do: actividad_de(otro_usuario)

  defp ejecutar_con_sesion(_sesion, "activity", [_otro_usuario]), do: {:error, {:sin_permiso, "activity usuario"}}

  # Si llegó hasta aquí es porque el comando existe pero se escribió mal
  defp ejecutar_con_sesion(_sesion, comando, _argumentos), do: {:error, {:uso_incorrecto, comando}}

  # ---------- El "cómo" ----------

  defp obtener_sesion(usuario) when is_binary(usuario), do: ServidorUsuarios.sesion(usuario)
  defp obtener_sesion(_usuario), do: {:error, :no_conectado}

  defp texto_conexion(:registrado), do: "Usuario nuevo registrado:"
  defp texto_conexion(:autenticado), do: "Sesión iniciada:"

  defp texto_comando(comando, argumentos), do: String.trim("#{comando} #{Enum.join(argumentos, " ")}")

  defp texto_devueltos([]), do: "No había recursos asignados para devolver."
  defp texto_devueltos(devueltos), do: "Recursos devueltos al inventario: #{Presentacion.tomas(devueltos)}."

  # La lista como texto, o el mensaje `vacio` si no hay elementos
  defp listar(elementos, formato, vacio) do
    case elementos do
      [] -> vacio
      _ -> Presentacion.lista(elementos, formato)
    end
  end

  defp entero(texto), do: Persistencia.a_entero(texto)

  defp personas_opcional([]), do: {:ok, 0}
  defp personas_opcional([texto]), do: entero(texto)

  defp edad_opcional([]), do: {:ok, nil}
  defp edad_opcional([texto]), do: entero(texto)

  defp cantidad_opcional([], por_defecto), do: {:ok, por_defecto}
  defp cantidad_opcional([texto], _por_defecto), do: entero(texto)

  defp validar_zona(zona) do
    if ServidorZonas.existe_zona?(zona), do: :ok, else: {:error, :zona_inexistente}
  end

  # En los comandos se escribe lost/found; internamente se guarda perdida/encontrada
  defp tipo_reporte("lost"), do: "perdida"
  defp tipo_reporte("found"), do: "encontrada"
  defp tipo_reporte(otro), do: otro

  # Convierte ["zona=centro", "tipo=agua"] en %{zona: "centro", tipo: "agua"},
  # aceptando solo los nombres de filtro que estén en `permitidos`.

  # Caso base: no quedan filtros
  defp parsear_filtros([], _permitidos), do: {:ok, %{}}

  # Caso recursivo: se convierte el primer filtro y luego el resto
  defp parsear_filtros([head | tail], permitidos) do
    with [clave, valor] <- String.split(head, "=", parts: 2),
         {:ok, campo} <- Map.fetch(permitidos, clave),
         {:ok, resto} <- parsear_filtros(tail, permitidos) do
      {:ok, Map.put(resto, campo, valor)}
    else
      {:error, motivo} -> {:error, motivo}
      _otro -> {:error, {:filtro_invalido, head}}
    end
  end

  defp buscar_personas(filtros_texto) do
    with {:ok, filtros} <- parsear_filtros(filtros_texto, @filtros_personas) do
      {:ok, listar(ServidorPersonas.buscar(filtros), &Presentacion.persona/1, "No se encontraron personas.")}
    end
  end

  defp buscar_persona_por_documento(documento) do
    with {:ok, persona} <- ServidorPersonas.buscar_por_documento(documento),
         {:ok, historial} <- ServidorPersonas.historial(documento) do
      {:ok, Presentacion.persona(persona) <> "\nHistorial de estados: " <> Enum.join(historial, " -> ")}
    end
  end

  # Si la persona ya estaba registrada, pasa a "en_albergue". Si no estaba
  # registrada (o su estado no puede cambiar a ese), el ingreso queda igual.
  defp actualizar_estado_persona(documento) do
    case ServidorPersonas.cambiar_estado(documento, "en_albergue") do
      {:ok, _persona} -> " Su estado ahora es en_albergue."
      {:error, _motivo} -> ""
    end
  end

  defp actividad_de(nombre_usuario) do
    with {:ok, registros} <- ServidorUsuarios.actividad(nombre_usuario) do
      formato = fn [fecha, _usuario, accion] -> "#{fecha} #{accion}" end
      {:ok, listar(registros, formato, "#{nombre_usuario} no tiene actividad registrada.")}
    end
  end

  # Por cada tipo de recurso: lo que falta para las necesidades críticas pendientes
  # frente a lo que hay disponible. Solo se incluyen los tipos donde NO alcanza.
  defp faltantes_criticos do
    %{prioridad: "critica", estado: "pendiente"}
    |> ServidorNecesidades.consultar()
    |> Enum.group_by(& &1.tipo, &Necesidades.cantidad_faltante/1)
    |> Enum.map(fn {tipo, faltantes} -> {tipo, Enum.sum(faltantes), ServidorRecursos.disponible_total(%{categoria: tipo})} end)
    |> Enum.filter(fn {_tipo, falta, disponible} -> falta > disponible end)
    |> Enum.sort()
  end

  defp resumen_global do
    Presentacion.resumen(%{
      zonas: ServidorZonas.resumen(),
      necesidades: ServidorNecesidades.consultar(),
      recursos: ServidorRecursos.consultar(),
      personas: ServidorPersonas.buscar(),
      mensajes: ServidorMensajes.todos(),
      mascotas: ServidorMascotas.consultar(),
      albergues: ServidorAlbergues.mayor_ocupacion(1_000)
    })
  end
end
