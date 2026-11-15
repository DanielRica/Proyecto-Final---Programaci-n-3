# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Albergues do
  @moduledoc """
  Gestión de albergues: capacidad, ocupación, ingresos y salidas de personas.

  Los albergues se guardan en un mapa: la llave es el código ("A01").

      %{codigo: "A01", nombre: "Albergue Norte", zona: "norte", capacidad: 150,
        ocupacion: 40, personas: MapSet.new(["111", "222"])}

  `ocupacion` es el número de personas alojadas ahora mismo. `personas` es
  el conjunto (MapSet) de documentos registrados con `register_entry`;
  un MapSet no permite repetidos, justo lo que se necesita para que una
  persona no quede dos veces en el mismo albergue.

  Los recursos y las necesidades de un albergue se asocian por su
  `ubicacion` (el código del albergue); eso lo resolverá el servidor.
  """

  @archivo_albergues "albergues.txt"

  # ---------- El "qué" (funciones puras) ----------

  @doc """
  Registra un albergue (comando `register_shelter`). La ocupación inicial
  es opcional (por defecto 0) y no puede superar la capacidad.
  Devuelve `{:ok, albergues, albergue}` o `{:error, motivo}`.

  ## Ejemplo
  iex> Albergues.registrar(%{}, "A01", "Albergue Norte", "norte", 150)
  {:ok, %{"A01" => %{...}}, %{codigo: "A01", capacidad: 150, ocupacion: 0, ...}}
  """
  def registrar(albergues, codigo, nombre, zona, capacidad, ocupacion \\ 0) do
    with :ok <- Persistencia.validar_campos([codigo, nombre, zona]),
         :ok <- validar_capacidad(capacidad),
         :ok <- validar_ocupacion(ocupacion, capacidad),
         :ok <- validar_codigo_nuevo(albergues, codigo) do
      albergue = %{
        codigo: codigo,
        nombre: nombre,
        zona: zona,
        capacidad: capacidad,
        ocupacion: ocupacion,
        personas: MapSet.new()
      }

      {:ok, Map.put(albergues, codigo, albergue), albergue}
    end
  end

  @doc """
  Registra el ingreso de una persona (comando `register_entry`).
  Falla si el albergue está lleno o si la persona ya está en algún albergue.
  """
  def registrar_ingreso(albergues, codigo, documento) do
    with {:ok, albergue} <- buscar(albergues, codigo),
         :ok <- validar_documento(documento),
         :ok <- validar_persona_libre(albergues, documento),
         :ok <- validar_hay_cupo(albergue) do
      actualizado = %{
        albergue
        | ocupacion: albergue.ocupacion + 1,
          personas: MapSet.put(albergue.personas, documento)
      }

      {:ok, Map.put(albergues, codigo, actualizado), actualizado}
    end
  end

  @doc "Registra la salida de una persona (comando `register_exit`)."
  def registrar_salida(albergues, codigo, documento) do
    with {:ok, albergue} <- buscar(albergues, codigo),
         :ok <- validar_persona_alojada(albergue, documento) do
      actualizado = %{
        albergue
        | ocupacion: albergue.ocupacion - 1,
          personas: MapSet.delete(albergue.personas, documento)
      }

      {:ok, Map.put(albergues, codigo, actualizado), actualizado}
    end
  end

  @doc "Cupos disponibles de un albergue (capacidad menos ocupación)."
  def cupos_disponibles(albergue), do: albergue.capacidad - albergue.ocupacion

  @doc """
  Consulta el estado de un albergue (comando `check_shelter`).

  ## Ejemplo
  iex> Albergues.consultar_cupos(albergues, "A01")
  {:ok, %{codigo: "A01", nombre: "Albergue Norte", capacidad: 3, ocupacion: 2, cupos: 1}}
  """
  def consultar_cupos(albergues, codigo) do
    with {:ok, albergue} <- buscar(albergues, codigo) do
      {:ok,
       %{
         codigo: albergue.codigo,
         nombre: albergue.nombre,
         capacidad: albergue.capacidad,
         ocupacion: albergue.ocupacion,
         cupos: cupos_disponibles(albergue)
       }}
    end
  end

  @doc """
  Reporte de los albergues con mayor nivel de ocupación (porcentaje de la
  capacidad ocupada), del más lleno al menos lleno.

  ## Ejemplo
  iex> Albergues.mayor_ocupacion(albergues, 2)
  [%{codigo: "A02", porcentaje: 80.0, ...}, %{codigo: "A01", porcentaje: 66.7, ...}]
  """
  def mayor_ocupacion(albergues, cantidad \\ 3) do
    albergues
    |> Map.values()
    |> Enum.map(&resumen_ocupacion/1)
    |> Util2.ordenar(:desc, & &1.porcentaje)
    |> Enum.take(cantidad)
  end

  # ---------- Conversión a texto plano (puras) ----------

  @doc "Convierte todos los albergues en registros para guardarlos."
  def a_registros(albergues) do
    albergues
    |> Map.values()
    |> Enum.map(&a_campos/1)
  end

  @doc """
  Convierte los registros del archivo en el mapa de albergues.
  Recursiva: arma el mapa con los albergues que quedan y le agrega el primero.
  """
  # Caso base: sin registros, el mapa está vacío
  def desde_registros([]), do: {:ok, %{}}

  # Caso recursivo: se convierte el primer registro y luego el resto
  def desde_registros([head | tail]) do
    with {:ok, albergue} <- desde_campos(head),
         {:ok, resto} <- desde_registros(tail) do
      {:ok, Map.put(resto, albergue.codigo, albergue)}
    end
  end

  # ---------- Efectos: archivos ----------

  @doc "Carga los albergues guardados (mapa vacío si es la primera vez)."
  def cargar do
    with {:ok, registros} <- Persistencia.cargar(@archivo_albergues) do
      desde_registros(registros)
    end
  end

  @doc "Guarda todos los albergues en el archivo."
  def guardar(albergues) do
    Persistencia.guardar(@archivo_albergues, a_registros(albergues))
  end

  # ---------- El "cómo" ----------

  defp buscar(albergues, codigo) do
    case Map.fetch(albergues, codigo) do
      {:ok, albergue} -> {:ok, albergue}
      :error -> {:error, :albergue_inexistente}
    end
  end

  defp resumen_ocupacion(albergue) do
    %{
      codigo: albergue.codigo,
      nombre: albergue.nombre,
      ocupacion: albergue.ocupacion,
      capacidad: albergue.capacidad,
      porcentaje: Float.round(albergue.ocupacion * 100 / albergue.capacidad, 1)
    }
  end

  defp validar_codigo_nuevo(albergues, codigo) do
    if Map.has_key?(albergues, codigo), do: {:error, :albergue_existente}, else: :ok
  end

  # La capacidad debe ser mayor que 0 (con 0 no se podría calcular el porcentaje)
  defp validar_capacidad(capacidad) when is_integer(capacidad) and capacidad > 0, do: :ok
  defp validar_capacidad(_capacidad), do: {:error, :capacidad_invalida}

  defp validar_ocupacion(ocupacion, capacidad)
       when is_integer(ocupacion) and ocupacion >= 0 and is_integer(capacidad) and ocupacion <= capacidad,
       do: :ok

  defp validar_ocupacion(_ocupacion, _capacidad), do: {:error, :ocupacion_invalida}

  # El documento va en el archivo separado por comas, por eso no puede llevar ","
  defp validar_documento(documento) do
    with :ok <- Persistencia.validar_campos([documento]) do
      if String.contains?(documento, ","), do: {:error, :caracter_invalido}, else: :ok
    end
  end

  defp validar_persona_libre(albergues, documento) do
    if Enum.any?(Map.values(albergues), &MapSet.member?(&1.personas, documento)) do
      {:error, :persona_ya_alojada}
    else
      :ok
    end
  end

  defp validar_hay_cupo(albergue) do
    if albergue.ocupacion < albergue.capacidad, do: :ok, else: {:error, :albergue_lleno}
  end

  defp validar_persona_alojada(albergue, documento) do
    if MapSet.member?(albergue.personas, documento), do: :ok, else: {:error, :persona_no_alojada}
  end

  defp a_campos(albergue) do
    [
      albergue.codigo,
      albergue.nombre,
      albergue.zona,
      Integer.to_string(albergue.capacidad),
      Integer.to_string(albergue.ocupacion),
      albergue.personas |> MapSet.to_list() |> Enum.join(",")
    ]
  end

  defp desde_campos([codigo, nombre, zona, capacidad, ocupacion, documentos]) do
    with {:ok, capacidad} <- Persistencia.a_entero(capacidad),
         {:ok, ocupacion} <- Persistencia.a_entero(ocupacion) do
      {:ok,
       %{
         codigo: codigo,
         nombre: nombre,
         zona: zona,
         capacidad: capacidad,
         ocupacion: ocupacion,
         personas: documentos |> String.split(",", trim: true) |> MapSet.new()
       }}
    end
  end

  defp desde_campos(_registro_corrupto), do: {:error, :registro_corrupto}
end
