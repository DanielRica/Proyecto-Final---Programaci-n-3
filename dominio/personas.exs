# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Personas do
  @moduledoc """
  Gestión de personas afectadas, para que sus familiares puedan localizarlas.

  Las personas se guardan en un mapa: la llave es el documento (o dato de
  referencia), que hace de identificador y por eso no se puede repetir.

      %{documento: "111", nombre: "Andrés", edad: 30, zona: "norte",
        estado: "localizada", historial: ["reportada", "localizada"]}

  `edad` puede ser `nil` si no se conoce. `historial` guarda todos los
  estados por los que ha pasado la persona, en orden; el último es el actual.
  """

  @estados ["sin_informacion", "reportada", "localizada", "trasladada", "en_albergue", "reunificada"]

  # A qué estados se puede pasar desde cada uno. "reunificada" es el final.
  @transiciones %{
    "sin_informacion" => ["reportada", "localizada"],
    "reportada" => ["localizada"],
    "localizada" => ["trasladada", "en_albergue", "reunificada"],
    "trasladada" => ["localizada", "en_albergue", "reunificada"],
    "en_albergue" => ["trasladada", "reunificada"],
    "reunificada" => []
  }

  @archivo_personas "personas.txt"

  # ---------- El "qué" (funciones puras) ----------

  @doc "Estados permitidos para una persona."
  def estados_validos, do: @estados

  @doc """
  Registra una persona afectada (comando `report_person`). El estado inicial
  puede ser cualquiera de los estados válidos, y queda como primer elemento
  del historial. La edad es opcional.
  Devuelve `{:ok, personas, persona}` o `{:error, motivo}`.

  ## Ejemplo
  iex> Personas.registrar(%{}, "111", "Andrés", "norte", "localizada")
  {:ok, %{"111" => %{...}}, %{documento: "111", estado: "localizada", historial: ["localizada"], ...}}
  """
  def registrar(personas, documento, nombre, zona, estado, edad \\ nil) do
    with :ok <- Persistencia.validar_campos([documento, nombre, zona]),
         :ok <- validar_estado(estado),
         :ok <- validar_edad(edad),
         :ok <- validar_documento_nuevo(personas, documento) do
      persona = %{
        documento: documento,
        nombre: nombre,
        edad: edad,
        zona: zona,
        estado: estado,
        historial: [estado]
      }

      {:ok, Map.put(personas, documento, persona), persona}
    end
  end

  @doc """
  Cambia el estado de una persona si la transición es válida y lo agrega al historial.

  ## Ejemplos
  iex> Personas.cambiar_estado(personas, "111", "en_albergue")
  {:ok, personas, %{estado: "en_albergue", historial: ["localizada", "en_albergue"], ...}}
  iex> Personas.cambiar_estado(personas, "111", "reportada")  # no se puede volver atrás
  {:error, :transicion_invalida}
  """
  def cambiar_estado(personas, documento, nuevo_estado) do
    with {:ok, persona} <- buscar_por_documento(personas, documento),
         :ok <- validar_estado(nuevo_estado),
         :ok <- validar_transicion(persona.estado, nuevo_estado) do
      actualizada = %{persona | estado: nuevo_estado, historial: persona.historial ++ [nuevo_estado]}
      {:ok, Map.put(personas, documento, actualizada), actualizada}
    end
  end

  @doc """
  Busca personas por nombre (basta un pedazo, sin importar mayúsculas),
  documento, zona y/o estado. Sale ordenado por nombre.

  ## Ejemplo
  iex> Personas.buscar(personas, %{nombre: "and", zona: "norte"})
  [%{nombre: "Andrés", ...}]
  """
  def buscar(personas, filtros \\ %{}) do
    personas
    |> Map.values()
    |> Enum.filter(fn persona -> Enum.all?(filtros, &cumple_filtro?(persona, &1)) end)
    |> Util2.ordenar(:asc, &String.downcase(&1.nombre))
  end

  @doc "Busca una persona por su documento (comando `find_person`)."
  def buscar_por_documento(personas, documento) do
    case Map.fetch(personas, documento) do
      {:ok, persona} -> {:ok, persona}
      :error -> {:error, :persona_inexistente}
    end
  end

  @doc "Historial de estados de una persona, del más antiguo al más reciente."
  def historial(personas, documento) do
    with {:ok, persona} <- buscar_por_documento(personas, documento) do
      {:ok, persona.historial}
    end
  end

  # ---------- Conversión a texto plano (puras) ----------

  @doc "Convierte todas las personas en registros para guardarlas."
  def a_registros(personas) do
    personas
    |> Map.values()
    |> Enum.map(&a_campos/1)
  end

  @doc """
  Convierte los registros del archivo en el mapa de personas.
  Recursiva: arma el mapa con las personas que quedan y le agrega la primera.
  """
  # Caso base: sin registros, el mapa está vacío
  def desde_registros([]), do: {:ok, %{}}

  # Caso recursivo: se convierte el primer registro y luego el resto
  def desde_registros([head | tail]) do
    with {:ok, persona} <- desde_campos(head),
         {:ok, resto} <- desde_registros(tail) do
      {:ok, Map.put(resto, persona.documento, persona)}
    end
  end

  # ---------- Efectos: archivos ----------

  @doc "Carga las personas guardadas (mapa vacío si es la primera vez)."
  def cargar do
    with {:ok, registros} <- Persistencia.cargar(@archivo_personas) do
      desde_registros(registros)
    end
  end

  @doc "Guarda todas las personas en el archivo."
  def guardar(personas) do
    Persistencia.guardar(@archivo_personas, a_registros(personas))
  end

  # ---------- El "cómo" ----------

  # El nombre se busca por pedazos; los demás campos deben coincidir exactamente
  defp cumple_filtro?(persona, {:nombre, texto}) do
    String.contains?(String.downcase(persona.nombre), String.downcase(texto))
  end

  defp cumple_filtro?(persona, {campo, valor}), do: Map.get(persona, campo) == valor

  defp validar_documento_nuevo(personas, documento) do
    if Map.has_key?(personas, documento), do: {:error, :documento_existente}, else: :ok
  end

  defp validar_estado(estado) when estado in @estados, do: :ok
  defp validar_estado(_estado), do: {:error, :estado_invalido}

  defp validar_edad(nil), do: :ok
  defp validar_edad(edad) when is_integer(edad) and edad >= 0 and edad <= 120, do: :ok
  defp validar_edad(_edad), do: {:error, :edad_invalida}

  defp validar_transicion(estado_actual, nuevo_estado) do
    permitidos = Map.fetch!(@transiciones, estado_actual)

    cond do
      nuevo_estado in permitidos -> :ok
      permitidos == [] -> {:error, :persona_reunificada}
      true -> {:error, :transicion_invalida}
    end
  end

  # En el archivo, la edad desconocida se guarda como campo vacío
  defp a_campos(persona) do
    [
      persona.documento,
      persona.nombre,
      if(persona.edad == nil, do: "", else: Integer.to_string(persona.edad)),
      persona.zona,
      persona.estado,
      Enum.join(persona.historial, ",")
    ]
  end

  defp desde_campos([documento, nombre, edad, zona, estado, historial]) do
    with {:ok, edad} <- edad_desde_texto(edad) do
      {:ok,
       %{
         documento: documento,
         nombre: nombre,
         edad: edad,
         zona: zona,
         estado: estado,
         historial: String.split(historial, ",", trim: true)
       }}
    end
  end

  defp desde_campos(_registro_corrupto), do: {:error, :registro_corrupto}

  defp edad_desde_texto(""), do: {:ok, nil}
  defp edad_desde_texto(texto), do: Persistencia.a_entero(texto)
end
