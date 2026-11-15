# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Presentacion do
  @moduledoc """
  Convierte los datos del sistema en textos para mostrar al usuario.
  Son todas funciones puras: reciben datos y devuelven un texto, sin
  imprimir nada (quien imprime es el cliente).
  """

  @errores %{
    contrasena_incorrecta: "Contraseña incorrecta.",
    usuario_inexistente: "El usuario no existe.",
    usuario_existente: "El usuario ya existe.",
    no_conectado: "Debe conectarse primero con: connect usuario contraseña tipo zona",
    tipo_invalido: "El tipo indicado no es válido.",
    campo_vacio: "Hay un dato vacío.",
    caracter_invalido: "Hay un dato con un carácter no permitido (; o / o salto de línea).",
    numero_invalido: "Se esperaba un número entero.",
    cantidad_invalida: "La cantidad debe ser un número entero válido (mayor que 0, o 0 o más según el caso).",
    zona_inexistente: "La zona no existe. Regístrela con register_zone.",
    zona_existente: "Ya existe una zona con ese código.",
    nivel_invalido: "Nivel no válido. Use: critico, alto, medio o bajo.",
    ruta_inexistente: "El sector o la zona indicados no existen.",
    tipo_no_permitido: "Un punto de atención solo puede ir dentro de un sector.",
    codigo_existente: "Ya existe ese código.",
    necesidad_inexistente: "La necesidad no existe.",
    prioridad_invalida: "Prioridad no válida. Use: critica, alta, media o baja.",
    estado_invalido: "El estado indicado no es válido.",
    estado_no_admite_asignacion: "La necesidad ya no admite asignaciones (está completa, atendida o cancelada).",
    excede_cantidad_requerida: "Se pide más de lo que le falta a la necesidad.",
    necesidad_cerrada: "La necesidad ya está cerrada (atendida o cancelada).",
    transicion_invalida: "Ese cambio de estado no es válido desde el estado actual.",
    categoria_no_coincide: "El tipo de la necesidad no coincide con la categoría del recurso.",
    reversion_invalida: "No se pudo deshacer la asignación.",
    sin_necesidades_pendientes: "No hay necesidades pendientes.",
    recurso_inexistente: "El recurso no existe.",
    inventario_insuficiente: "No hay inventario suficiente.",
    origen_incorrecto: "El recurso no está en el centro de origen indicado.",
    destino_igual_al_origen: "El destino debe ser distinto del origen.",
    albergue_inexistente: "El albergue no existe.",
    albergue_existente: "Ya existe un albergue con ese código.",
    capacidad_invalida: "La capacidad debe ser un entero mayor que 0.",
    ocupacion_invalida: "La ocupación debe ser un entero entre 0 y la capacidad.",
    albergue_lleno: "El albergue está lleno.",
    persona_ya_alojada: "La persona ya está alojada en un albergue.",
    persona_no_alojada: "La persona no está en ese albergue.",
    persona_inexistente: "No hay una persona con ese documento.",
    documento_existente: "Ya hay una persona registrada con ese documento.",
    edad_invalida: "La edad debe estar entre 0 y 120.",
    persona_reunificada: "La persona ya fue reunificada: su estado es final.",
    mensaje_inexistente: "El mensaje no existe.",
    sin_cambios: "El mensaje ya tenía ese estado.",
    reporte_inexistente: "El reporte no existe.",
    tamano_invalido: "Tamaño no válido. Use: pequena, mediana o grande.",
    tipos_incompatibles: "Debe indicar primero el reporte de la mascota perdida y luego el de la encontrada.",
    reporte_ya_resuelto: "Uno de los reportes ya estaba resuelto.",
    registro_corrupto: "Hay un registro dañado en los archivos."
  }

  # comando => {sintaxis, descripción}
  @ayuda %{
    "connect" => {"connect usuario contraseña tipo zona", "Inicia sesión (si el usuario no existe, se registra)"},
    "register_zone" => {"register_zone codigo nombre nivel [personas]", "Registra una zona (nivel: critico, alto, medio, bajo)"},
    "register_sector" => {"register_sector zona codigo nombre nivel [personas]", "Agrega un sector a una zona"},
    "register_point" => {"register_point zona sector codigo nombre nivel [personas]", "Agrega un punto de atención a un sector"},
    "zone_status" => {"zone_status zona", "Estado general y estadísticas de una zona"},
    "register_need" => {"register_need tipo cantidad prioridad zona descripcion", "Registra una necesidad (prioridad: critica, alta, media, baja)"},
    "list_needs" => {"list_needs [zona=x] [tipo=x] [prioridad=x] [estado=x]", "Lista necesidades, de la más urgente a la menos urgente"},
    "pending_needs" => {"pending_needs", "Necesidades pendientes por prioridad"},
    "change_need_status" => {"change_need_status id estado", "Cambia el estado: en_atencion, atendida o cancelada"},
    "cancel_need" => {"cancel_need id", "Cancela una necesidad y devuelve sus recursos"},
    "register_resource" => {"register_resource codigo nombre cantidad unidad ubicacion [zona]", "Registra un recurso (por defecto en su zona)"},
    "list_resources" => {"list_resources [categoria=x] [zona=x] [ubicacion=x]", "Lista recursos"},
    "assign_resource" => {"assign_resource id_necesidad categoria cantidad", "Asigna recursos a una necesidad"},
    "transfer_resource" => {"transfer_resource codigo origen destino cantidad", "Transfiere recursos entre centros de apoyo"},
    "critical_resources" => {"critical_resources", "Recursos críticos: faltantes para necesidades críticas y existencias bajas"},
    "report_person" => {"report_person documento nombre zona estado [edad]", "Registra una persona afectada"},
    "find_person" => {"find_person documento | find_person nombre=x zona=x estado=x", "Busca personas y muestra su historial"},
    "change_person_status" => {"change_person_status documento estado", "Cambia el estado de una persona"},
    "send_family_message" => {"send_family_message documento mensaje", "Deja un mensaje para una persona o familia"},
    "list_family_messages" => {"list_family_messages documento", "Lista los mensajes de una persona"},
    "mark_message_delivered" => {"mark_message_delivered id", "Marca un mensaje como entregado"},
    "mark_message_pending" => {"mark_message_pending id", "Marca un mensaje como pendiente"},
    "report_pet" => {"report_pet lost|found especie nombre color tamano zona contacto [caracteristicas]", "Reporta una mascota perdida o encontrada"},
    "list_pets" => {"list_pets [especie=x] [zona=x] [estado=x] [tipo=x]", "Lista reportes de mascotas"},
    "match_pets" => {"match_pets", "Busca posibles coincidencias entre perdidas y encontradas"},
    "confirm_pet_match" => {"confirm_pet_match id_perdida id_encontrada", "Confirma una coincidencia y cierra ambos reportes"},
    "register_shelter" => {"register_shelter codigo nombre zona capacidad [ocupacion]", "Registra un albergue"},
    "check_shelter" => {"check_shelter codigo", "Cupos disponibles de un albergue"},
    "register_entry" => {"register_entry codigo_albergue documento", "Registra el ingreso de una persona"},
    "register_exit" => {"register_exit codigo_albergue documento", "Registra la salida de una persona"},
    "top_shelters" => {"top_shelters [cantidad]", "Albergues con mayor ocupación"},
    "summary" => {"summary", "Resumen global de la emergencia"},
    "activity" => {"activity [usuario]", "Su actividad (el administrador puede ver la de otros)"}
  }

  # ---------- Errores y ayuda ----------

  @doc """
  Convierte el motivo de un error en un mensaje para el usuario.

  ## Ejemplos
  iex> Presentacion.error(:albergue_lleno)
  "El albergue está lleno."
  iex> Presentacion.error({:sin_permiso, "summary"})
  "No tiene permiso para usar 'summary'."
  """
  def error({:sin_permiso, comando}), do: "No tiene permiso para usar '#{comando}'."

  def error({:comando_desconocido, comando}),
    do: "Comando desconocido: '#{comando}'. Escriba help para ver los comandos."

  def error({:uso_incorrecto, comando}), do: "Uso incorrecto. Sintaxis: #{sintaxis(comando)}"
  def error({:filtro_invalido, filtro}), do: "Filtro no válido: '#{filtro}'."
  def error({:persistencia, razon}), do: "No se pudo guardar en el archivo: #{inspect(razon)}."

  def error(motivo) when is_atom(motivo) do
    Map.get(@errores, motivo, "Error: #{motivo}.")
  end

  def error(otro), do: "Error: #{inspect(otro)}."

  @doc "Sintaxis de un comando."
  def sintaxis(comando) do
    case Map.fetch(@ayuda, comando) do
      {:ok, {sintaxis, _descripcion}} -> sintaxis
      :error -> comando
    end
  end

  @doc "Texto de ayuda con los comandos que puede usar el usuario."
  def ayuda(comandos_permitidos) do
    lineas =
      comandos_permitidos
      |> Enum.filter(&Map.has_key?(@ayuda, &1))
      |> Util2.convertir_coleccion_mensaje(fn comando ->
        {sintaxis, descripcion} = Map.fetch!(@ayuda, comando)
        "  #{sintaxis}\n      #{descripcion}\n"
      end)

    "Comandos disponibles (los textos con espacios van entre comillas):\n" <>
      Enum.join(lineas) <>
      "  help, disconnect, salir"
  end

  # ---------- Elementos ----------

  def necesidad(n) do
    "#{n.id} [#{n.prioridad}] #{n.tipo} #{n.cantidad_asignada}/#{n.cantidad} en #{n.zona} (#{n.estado}) - #{n.descripcion} (por #{n.responsable})"
  end

  def recurso(r), do: "#{r.codigo} #{r.nombre}: #{r.cantidad} #{r.unidad} en #{r.ubicacion} (zona #{r.zona})"

  def persona(p) do
    edad = if p.edad == nil, do: "?", else: Integer.to_string(p.edad)
    "#{p.documento} #{p.nombre}, edad #{edad}, zona #{p.zona}, estado #{p.estado}"
  end

  def mensaje(m), do: "#{m.id} [#{m.estado}] #{m.fecha} de #{m.remitente}: #{m.contenido}"

  def reporte(r) do
    "#{r.id} #{r.tipo} #{r.especie} #{r.nombre}, #{r.color}, #{r.tamano}, zona #{r.zona} [#{r.estado}] contacto #{r.contacto}"
  end

  def cupos(c), do: "#{c.codigo} #{c.nombre}: #{c.ocupacion}/#{c.capacidad} ocupados, #{c.cupos} cupos libres"

  @doc "Lista de `{codigo_recurso, cantidad}` como texto."
  def tomas(tomas), do: Enum.map_join(tomas, ", ", fn {codigo, cantidad} -> "#{codigo}: #{cantidad}" end)

  def estado_zona(e) do
    detalle =
      e.detalle_sectores
      |> Util2.convertir_coleccion_mensaje(fn s ->
        "  - sector #{s.codigo} (#{s.nombre}, nivel #{s.nivel}): #{s.personas_afectadas} personas, #{s.puntos_atencion} puntos de atención\n"
      end)
      |> Enum.join()
      |> String.trim_trailing()

    "Zona #{e.codigo} (#{e.nombre}), nivel #{e.nivel}\n" <>
      "Personas afectadas (acumulado): #{e.personas_afectadas}\n" <>
      "Sectores: #{e.sectores}. Puntos de atención: #{e.puntos_atencion}" <>
      if(detalle == "", do: "", else: "\n" <> detalle)
  end

  @doc """
  Convierte una lista en texto, una línea por elemento. Si la lista está
  vacía devuelve el mensaje `vacio`.
  """
  def lista([], vacio), do: vacio

  def lista(elementos, formato) when is_function(formato, 1) do
    elementos
    |> Util2.convertir_coleccion_mensaje(fn elemento -> " - #{formato.(elemento)}\n" end)
    |> Enum.join()
    |> String.trim_trailing()
  end

  # ---------- Informes ----------

  @doc "Texto de `critical_resources`: faltantes para necesidades críticas y recursos con poca existencia."
  def criticos(faltantes, bajos) do
    parte_faltantes =
      case faltantes do
        [] ->
          "Las necesidades críticas pendientes tienen inventario suficiente."

        _ ->
          "Faltan recursos para necesidades críticas pendientes:\n" <>
            lista(faltantes, fn {tipo, falta, disponible} -> "#{tipo}: faltan #{falta}, disponibles #{disponible}" end)
      end

    parte_bajos =
      case bajos do
        [] -> "Ningún recurso tiene existencias bajas."
        _ -> "Recursos con existencias bajas (10 o menos):\n" <> lista(bajos, &recurso/1)
      end

    parte_faltantes <> "\n" <> parte_bajos
  end

  @doc "Texto del comando `summary` a partir de los datos de todos los servidores."
  def resumen(datos) do
    personas_zonas = datos.zonas |> Enum.map(& &1.personas_afectadas) |> Enum.sum()
    pendientes = Enum.filter(datos.necesidades, &(&1.estado == "pendiente"))
    criticas = Enum.count(pendientes, &(&1.prioridad == "critica"))

    existencias =
      datos.recursos
      |> Enum.group_by(& &1.categoria, & &1.cantidad)
      |> Enum.map(fn {categoria, cantidades} -> {categoria, Enum.sum(cantidades)} end)
      |> Enum.sort()
      |> Enum.map_join(", ", fn {categoria, total} -> "#{categoria}: #{total}" end)

    albergues =
      case datos.albergues do
        [] -> "-"
        lista_albergues -> Enum.map_join(lista_albergues, "; ", &"#{&1.codigo} #{&1.ocupacion}/#{&1.capacidad} (#{&1.porcentaje}%)")
      end

    [
      "=== RESUMEN GLOBAL ===",
      "Zonas: #{length(datos.zonas)} (personas afectadas estimadas, acumulado: #{personas_zonas})",
      "Necesidades: #{length(datos.necesidades)} en total -> #{conteo(datos.necesidades, & &1.estado)}",
      "  Pendientes: #{length(pendientes)} (críticas: #{criticas})",
      "Recursos restantes: #{vacio_a_guion(existencias)}",
      "Personas: #{length(datos.personas)} registradas -> #{conteo(datos.personas, & &1.estado)}",
      "Mensajes: #{length(datos.mensajes)} (pendientes: #{Enum.count(datos.mensajes, &(&1.estado == "pendiente"))})",
      "Mascotas: #{length(datos.mascotas)} reportes -> #{conteo(datos.mascotas, & &1.estado)}",
      "Albergues (ocupación): #{albergues}"
    ]
    |> Enum.join("\n")
  end

  # ---------- El "cómo" ----------

  # [%{estado: "a"}, %{estado: "a"}, %{estado: "b"}] => "a: 2, b: 1"
  defp conteo(elementos, campo) do
    elementos
    |> Enum.frequencies_by(campo)
    |> Enum.sort()
    |> Enum.map_join(", ", fn {valor, cantidad} -> "#{valor}: #{cantidad}" end)
    |> vacio_a_guion()
  end

  defp vacio_a_guion(""), do: "-"
  defp vacio_a_guion(texto), do: texto
end
