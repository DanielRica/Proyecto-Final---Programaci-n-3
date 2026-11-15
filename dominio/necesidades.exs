# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Necesidades do
  @moduledoc """
  Gestión de necesidades puntuales (solicitudes de ayuda).

  Las necesidades se guardan en un mapa: la llave es el identificador ("N001")
  y el valor es otro mapa:

      %{id: "N001", tipo: "agua", descripcion: "...", cantidad: 30, cantidad_asignada: 0,
        zona: "centro", prioridad: "critica", responsable: "laura", estado: "pendiente"}

  Estados: pendiente → asignada → en_atencion → atendida, y en cualquier momento
  antes de atendida se puede pasar a cancelada. Atendida y cancelada son finales.
  """

  @tipos_validos [
    "agua",
    "alimentos",
    "medicamentos",
    "primeros_auxilios",
    "refugio",
    "transporte",
    "rescate",
    "otra"
  ]

  # De la más urgente a la menos urgente (el orden de la lista ES la prioridad)
  @prioridades ["critica", "alta", "media", "baja"]

  @estados ["pendiente", "asignada", "en_atencion", "atendida", "cancelada"]

  # A qué estados se puede pasar con `cambiar_estado/3`.
  # Pasar de "pendiente" a "asignada" NO está aquí: ocurre solo cuando
  # `registrar_asignacion/3` completa la cantidad requerida.
  @transiciones %{
    "pendiente" => ["cancelada"],
    "asignada" => ["en_atencion", "cancelada"],
    "en_atencion" => ["atendida", "cancelada"],
    "atendida" => [],
    "cancelada" => []
  }

  @archivo_necesidades "necesidades.txt"

  # ---------- El "qué" (funciones puras) ----------

  @doc "Tipos de necesidad permitidos."
  def tipos_validos, do: @tipos_validos

  @doc "Prioridades permitidas, de la más urgente a la menos urgente."
  def prioridades_validas, do: @prioridades

  @doc """
  Registra una necesidad nueva (comando `register_need`). Le asigna un
  identificador único y estado "pendiente".
  Devuelve `{:ok, necesidades, necesidad}` o `{:error, motivo}`.

  La zona NO se comprueba aquí (este módulo no conoce las zonas): quien lo
  llame debe verificar antes que la zona exista.

  ## Ejemplo
  iex> Necesidades.registrar(%{}, "agua", 30, "critica", "centro", "Punto sector 3", "laura")
  {:ok, %{"N001" => %{...}}, %{id: "N001", estado: "pendiente", ...}}
  """
  def registrar(necesidades, tipo, cantidad, prioridad, zona, descripcion, responsable) do
    with :ok <- Persistencia.validar_campos([tipo, prioridad, zona, descripcion, responsable]),
         :ok <- validar_tipo(tipo),
         :ok <- validar_prioridad(prioridad),
         :ok <- validar_cantidad(cantidad) do
      id = siguiente_id(necesidades)

      necesidad = %{
        id: id,
        tipo: tipo,
        descripcion: descripcion,
        cantidad: cantidad,
        cantidad_asignada: 0,
        zona: zona,
        prioridad: prioridad,
        responsable: responsable,
        estado: "pendiente"
      }

      {:ok, Map.put(necesidades, id, necesidad), necesidad}
    end
  end

  @doc """
  Anota que se asignó parte (o todo) de lo que pide la necesidad.
  Solo se puede asignar mientras la necesidad esté "pendiente"; así una
  necesidad atendida, cancelada o ya completa no vuelve a consumir recursos.
  Cuando lo asignado iguala lo pedido, pasa a "asignada".

  ## Ejemplo (necesidad N001 pide 30)
  iex> Necesidades.registrar_asignacion(necesidades, "N001", 20)
  {:ok, necesidades, %{cantidad_asignada: 20, estado: "pendiente", ...}}
  iex> # luego otros 10:
  {:ok, necesidades, %{cantidad_asignada: 30, estado: "asignada", ...}}
  """
  def registrar_asignacion(necesidades, id, cantidad) do
    with {:ok, necesidad} <- buscar(necesidades, id),
         :ok <- validar_cantidad(cantidad),
         :ok <- validar_admite_asignacion(necesidad),
         :ok <- validar_no_excede(necesidad, cantidad) do
      asignada = necesidad.cantidad_asignada + cantidad
      estado = if asignada == necesidad.cantidad, do: "asignada", else: "pendiente"

      actualizar(necesidades, %{necesidad | cantidad_asignada: asignada, estado: estado})
    end
  end

  @doc """
  Deshace una asignación: se usa cuando se reservó la cantidad en la
  necesidad pero después no se pudieron tomar los recursos. Solo sirve
  mientras la necesidad esté "pendiente" o "asignada" y sin deshacer más de
  lo que tiene asignado.

  ## Ejemplo (N001 pide 30 y tiene 30 asignadas)
  iex> Necesidades.revertir_asignacion(necesidades, "N001", 30)
  {:ok, necesidades, %{cantidad_asignada: 0, estado: "pendiente", ...}}
  """
  def revertir_asignacion(necesidades, id, cantidad) do
    with {:ok, necesidad} <- buscar(necesidades, id),
         :ok <- validar_cantidad(cantidad),
         :ok <- validar_admite_reversion(necesidad, cantidad) do
      actualizar(necesidades, %{
        necesidad
        | cantidad_asignada: necesidad.cantidad_asignada - cantidad,
          estado: "pendiente"
      })
    end
  end

  @doc "Busca una necesidad por su identificador."
  def obtener(necesidades, id), do: buscar(necesidades, id)

  @doc """
  Cambia el estado de una necesidad si la transición es válida.

  ## Ejemplos
  iex> Necesidades.cambiar_estado(necesidades, "N001", "en_atencion")
  {:ok, necesidades, %{estado: "en_atencion", ...}}
  iex> Necesidades.cambiar_estado(necesidades, "N001", "atendida")  # ya estaba atendida
  {:error, :necesidad_cerrada}
  """
  def cambiar_estado(necesidades, id, nuevo_estado) do
    with {:ok, necesidad} <- buscar(necesidades, id),
         :ok <- validar_estado(nuevo_estado),
         :ok <- validar_transicion(necesidad.estado, nuevo_estado) do
      actualizar(necesidades, %{necesidad | estado: nuevo_estado})
    end
  end

  @doc "Cuánto falta por asignar de una necesidad."
  def cantidad_faltante(necesidad), do: necesidad.cantidad - necesidad.cantidad_asignada

  @doc """
  Consulta necesidades filtrando por zona, tipo, prioridad y/o estado.
  El resultado sale ordenado por prioridad (y a igual prioridad, la más antigua primero).

  ## Ejemplo
  iex> Necesidades.consultar(necesidades, %{zona: "centro", prioridad: "critica"})
  [%{id: "N001", ...}]
  """
  def consultar(necesidades, filtros \\ %{}) do
    necesidades
    |> Map.values()
    |> Enum.filter(&cumple_filtros?(&1, filtros))
    |> ordenar_por_prioridad()
  end

  @doc "Necesidades pendientes, ordenadas por prioridad (comando `pending_needs`)."
  def pendientes(necesidades), do: consultar(necesidades, %{estado: "pendiente"})

  @doc """
  Selecciona la necesidad que debe atenderse primero: la pendiente más
  urgente (y la más antigua entre las de igual prioridad).
  """
  def siguiente_a_atender(necesidades) do
    case pendientes(necesidades) do
      [] -> {:error, :sin_necesidades_pendientes}
      [primera | _otras] -> {:ok, primera}
    end
  end

  @doc """
  Ordena una lista de necesidades: primero las más urgentes y, a igual
  prioridad, las de identificador menor (las más antiguas).
  """
  def ordenar_por_prioridad(lista) do
    Util2.ordenar(lista, :asc, &{peso_prioridad(&1.prioridad), &1.id})
  end

  # ---------- Conversión a texto plano (puras) ----------

  @doc "Convierte todas las necesidades en registros para guardarlas."
  def a_registros(necesidades) do
    necesidades
    |> Map.values()
    |> Enum.map(&a_campos/1)
  end

  @doc """
  Convierte los registros del archivo en el mapa de necesidades.
  Recursiva: arma el mapa con las necesidades que quedan y le agrega la primera.
  """
  # Caso base: sin registros, el mapa está vacío
  def desde_registros([]), do: {:ok, %{}}

  # Caso recursivo: se convierte el primer registro y luego el resto
  def desde_registros([head | tail]) do
    with {:ok, necesidad} <- desde_campos(head),
         {:ok, resto} <- desde_registros(tail) do
      {:ok, Map.put(resto, necesidad.id, necesidad)}
    end
  end

  # ---------- Efectos: archivos ----------

  @doc "Carga las necesidades guardadas (mapa vacío si es la primera vez)."
  def cargar do
    with {:ok, registros} <- Persistencia.cargar(@archivo_necesidades) do
      desde_registros(registros)
    end
  end

  @doc "Guarda todas las necesidades en el archivo."
  def guardar(necesidades) do
    Persistencia.guardar(@archivo_necesidades, a_registros(necesidades))
  end

  # ---------- El "cómo" ----------

  # 0 necesidades => "N001", 1 => "N002", ... (nunca se borran, solo se cancelan,
  # por eso el tamaño del mapa + 1 siempre da un identificador nuevo)
  defp siguiente_id(necesidades) do
    numero = map_size(necesidades) + 1
    "N" <> String.pad_leading(Integer.to_string(numero), 3, "0")
  end

  defp buscar(necesidades, id) do
    case Map.fetch(necesidades, id) do
      {:ok, necesidad} -> {:ok, necesidad}
      :error -> {:error, :necesidad_inexistente}
    end
  end

  defp actualizar(necesidades, necesidad) do
    {:ok, Map.put(necesidades, necesidad.id, necesidad), necesidad}
  end

  # Cada filtro es {campo, valor}: la necesidad cumple si TODOS coinciden
  defp cumple_filtros?(necesidad, filtros) do
    Enum.all?(filtros, fn {campo, valor} -> Map.get(necesidad, campo) == valor end)
  end

  # "critica" => 0, "alta" => 1, "media" => 2, "baja" => 3
  defp peso_prioridad(prioridad), do: Enum.find_index(@prioridades, &(&1 == prioridad))

  defp validar_tipo(tipo) when tipo in @tipos_validos, do: :ok
  defp validar_tipo(_tipo), do: {:error, :tipo_invalido}

  defp validar_prioridad(prioridad) when prioridad in @prioridades, do: :ok
  defp validar_prioridad(_prioridad), do: {:error, :prioridad_invalida}

  defp validar_estado(estado) when estado in @estados, do: :ok
  defp validar_estado(_estado), do: {:error, :estado_invalido}

  defp validar_cantidad(cantidad) when is_integer(cantidad) and cantidad > 0, do: :ok
  defp validar_cantidad(_cantidad), do: {:error, :cantidad_invalida}

  defp validar_admite_asignacion(%{estado: "pendiente"}), do: :ok
  defp validar_admite_asignacion(_necesidad), do: {:error, :estado_no_admite_asignacion}

  defp validar_admite_reversion(%{estado: estado, cantidad_asignada: asignada}, cantidad)
       when estado in ["pendiente", "asignada"] and cantidad <= asignada,
       do: :ok

  defp validar_admite_reversion(_necesidad, _cantidad), do: {:error, :reversion_invalida}

  defp validar_no_excede(necesidad, cantidad) do
    if cantidad <= cantidad_faltante(necesidad), do: :ok, else: {:error, :excede_cantidad_requerida}
  end

  defp validar_transicion(estado_actual, nuevo_estado) do
    permitidos = Map.fetch!(@transiciones, estado_actual)

    cond do
      nuevo_estado in permitidos -> :ok
      permitidos == [] -> {:error, :necesidad_cerrada}
      true -> {:error, :transicion_invalida}
    end
  end

  defp a_campos(necesidad) do
    [
      necesidad.id,
      necesidad.tipo,
      necesidad.descripcion,
      Integer.to_string(necesidad.cantidad),
      Integer.to_string(necesidad.cantidad_asignada),
      necesidad.zona,
      necesidad.prioridad,
      necesidad.responsable,
      necesidad.estado
    ]
  end

  defp desde_campos([id, tipo, descripcion, cantidad, asignada, zona, prioridad, responsable, estado]) do
    with {:ok, cantidad} <- Persistencia.a_entero(cantidad),
         {:ok, asignada} <- Persistencia.a_entero(asignada) do
      {:ok,
       %{
         id: id,
         tipo: tipo,
         descripcion: descripcion,
         cantidad: cantidad,
         cantidad_asignada: asignada,
         zona: zona,
         prioridad: prioridad,
         responsable: responsable,
         estado: estado
       }}
    end
  end

  defp desde_campos(_registro_corrupto), do: {:error, :registro_corrupto}
end
