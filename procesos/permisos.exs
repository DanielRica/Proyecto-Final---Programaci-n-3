# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Permisos do
  @moduledoc """
  Qué tipo de usuario puede ejecutar cada comando.

  Hay cuatro tipos, de menos a más permisos:

  - `ciudadano`: pide ayuda, reporta personas y mascotas, deja mensajes y consulta.
  - `voluntario`: además maneja el inventario, los ingresos a albergues y las coincidencias.
  - `coordinador`: además crea zonas y albergues, asigna y transfiere recursos, y ve el resumen.
  - `administrador`: todo lo anterior, y puede ver la actividad de cualquier usuario.

  Los comandos `connect`, `disconnect`, `ping` y `help` no pasan por aquí
  (no requieren estar conectado, o se revisan aparte).
  """

  @todos ["ciudadano", "voluntario", "coordinador", "administrador"]
  @desde_voluntario ["voluntario", "coordinador", "administrador"]
  @coordinacion ["coordinador", "administrador"]

  @permisos %{
    # Zonas
    "register_zone" => @coordinacion,
    "register_sector" => @coordinacion,
    "register_point" => @coordinacion,
    "zone_status" => @todos,
    # Necesidades
    "register_need" => @todos,
    "list_needs" => @todos,
    "pending_needs" => @desde_voluntario,
    "change_need_status" => @desde_voluntario,
    "cancel_need" => @coordinacion,
    # Recursos
    "register_resource" => @desde_voluntario,
    "list_resources" => @desde_voluntario,
    "assign_resource" => @coordinacion,
    "transfer_resource" => @coordinacion,
    "critical_resources" => @coordinacion,
    # Familiares
    "report_person" => @todos,
    "find_person" => @todos,
    "change_person_status" => @desde_voluntario,
    "send_family_message" => @todos,
    "list_family_messages" => @todos,
    "mark_message_delivered" => @desde_voluntario,
    "mark_message_pending" => @desde_voluntario,
    # Mascotas
    "report_pet" => @todos,
    "list_pets" => @todos,
    "match_pets" => @desde_voluntario,
    "confirm_pet_match" => @coordinacion,
    # Albergues
    "register_shelter" => @coordinacion,
    "check_shelter" => @todos,
    "register_entry" => @desde_voluntario,
    "register_exit" => @desde_voluntario,
    "top_shelters" => @coordinacion,
    # General
    "summary" => @coordinacion,
    "activity" => @todos
  }

  # ---------- El "qué" ----------

  @doc """
  Verifica si un tipo de usuario puede ejecutar un comando.

  ## Ejemplos
  iex> Permisos.verificar("coordinador", "assign_resource")
  :ok
  iex> Permisos.verificar("ciudadano", "assign_resource")
  {:error, {:sin_permiso, "assign_resource"}}
  iex> Permisos.verificar("ciudadano", "volar")
  {:error, {:comando_desconocido, "volar"}}
  """
  def verificar(tipo_usuario, comando) do
    case Map.fetch(@permisos, comando) do
      {:ok, tipos_permitidos} ->
        if tipo_usuario in tipos_permitidos, do: :ok, else: {:error, {:sin_permiso, comando}}

      :error ->
        {:error, {:comando_desconocido, comando}}
    end
  end

  @doc "Lista ordenada de los comandos que puede usar un tipo de usuario."
  def comandos_de(tipo_usuario) do
    @permisos
    |> Enum.filter(fn {_comando, tipos_permitidos} -> tipo_usuario in tipos_permitidos end)
    |> Enum.map(fn {comando, _tipos_permitidos} -> comando end)
    |> Enum.sort()
  end

  @doc "Indica si el comando existe."
  def existe?(comando), do: Map.has_key?(@permisos, comando)
end
