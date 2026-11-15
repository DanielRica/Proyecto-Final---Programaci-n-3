# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Zonas do
  @moduledoc """
  Gestión de zonas afectadas: zona → sectores → puntos de atención.

  Los tres niveles tienen la MISMA forma (un nodo), y por eso se pueden
  recorrer con la misma función recursiva:

      %{tipo: "zona" | "sector" | "punto", codigo: "centro", nombre: "Centro",
        nivel: "critico", personas: 120, hijos: [otros nodos]}

  Las zonas se guardan en un mapa: la llave es el código de la zona.
  `personas` es el estimado registrado directamente en ese nodo; el total
  acumulado de una zona suma ese número más el de todo lo que cuelga de ella.
  """

  @niveles_validos ["critico", "alto", "medio", "bajo"]
  @archivo_zonas "zonas.txt"

  # ---------- El "qué" (funciones puras) ----------

  @doc "Devuelve los niveles de afectación permitidos."
  def niveles_validos, do: @niveles_validos

  @doc """
  Registra una zona. Devuelve `{:ok, zonas}` o `{:error, motivo}`.

  ## Ejemplo
  iex> Zonas.registrar_zona(%{}, "centro", "Centro", "critico", 500)
  {:ok, %{"centro" => %{tipo: "zona", ...}}}
  """
  def registrar_zona(zonas, codigo, nombre, nivel, personas \\ 0) do
    with {:ok, zona} <- crear_nodo("zona", codigo, nombre, nivel, personas) do
      colocar(zonas, [], zona)
    end
  end

  @doc "Agrega un sector dentro de una zona existente."
  def agregar_sector(zonas, codigo_zona, codigo, nombre, nivel, personas \\ 0) do
    with {:ok, sector} <- crear_nodo("sector", codigo, nombre, nivel, personas) do
      colocar(zonas, [codigo_zona], sector)
    end
  end

  @doc "Agrega un punto de atención dentro de un sector de una zona."
  def agregar_punto(zonas, codigo_zona, codigo_sector, codigo, nombre, nivel, personas \\ 0) do
    with {:ok, punto} <- crear_nodo("punto", codigo, nombre, nivel, personas) do
      colocar(zonas, [codigo_zona, codigo_sector], punto)
    end
  end

  @doc """
  Estado general de una zona, con estadísticas acumuladas de ella y de cada sector.

  ## Ejemplo
  iex> Zonas.estado_zona(zonas, "centro")
  {:ok, %{codigo: "centro", personas_afectadas: 650, sectores: 2, puntos_atencion: 3, detalle_sectores: [...]}}
  """
  def estado_zona(zonas, codigo_zona) do
    with {:ok, zona} <- buscar_zona(zonas, codigo_zona) do
      {:ok,
       %{
         codigo: zona.codigo,
         nombre: zona.nombre,
         nivel: zona.nivel,
         personas_afectadas: total_personas(zona),
         sectores: contar_tipo(zona, "sector"),
         puntos_atencion: contar_tipo(zona, "punto"),
         detalle_sectores: Enum.map(zona.hijos, &detalle_sector/1)
       }}
    end
  end

  @doc "Indica si existe una zona con ese código (lo usarán otros módulos)."
  def existe_zona?(zonas, codigo_zona), do: Map.has_key?(zonas, codigo_zona)

  # ---------- Funciones recursivas sobre el árbol ----------

  @doc """
  Suma las personas de un nodo y de TODO lo que cuelga de él.

  Es recursión sobre un árbol, con dos funciones que se llaman entre sí:
  una para el nodo y otra para la lista de hijos.

  Traza: zona(100) con sector A(50) y sector B(30) que tiene un punto(10):
  total(zona) = 100 + total_lista([A, B])
              = 100 + (50 + (30 + 10)) = 190
  """
  def total_personas(%{personas: personas, hijos: hijos}) do
    personas + total_personas_lista(hijos)
  end

  # Caso base: sin hijos no hay nada más que sumar
  defp total_personas_lista([]), do: 0

  # Caso recursivo: se suma el primer hijo (con todo lo suyo) y luego el resto
  defp total_personas_lista([head | tail]) do
    total_personas(head) + total_personas_lista(tail)
  end

  @doc """
  Cuenta cuántos nodos de un tipo ("sector" o "punto") hay dentro de un nodo.

  ## Ejemplo
  iex> Zonas.contar_tipo(zona, "punto")
  3
  """
  def contar_tipo(%{tipo: tipo_nodo, hijos: hijos}, tipo_buscado) do
    propio = if tipo_nodo == tipo_buscado, do: 1, else: 0
    propio + contar_tipo_lista(hijos, tipo_buscado)
  end

  # Caso base: sin hijos no hay nada más que contar
  defp contar_tipo_lista([], _tipo_buscado), do: 0

  # Caso recursivo: se cuenta el primer hijo (con todo lo suyo) y luego el resto
  defp contar_tipo_lista([head | tail], tipo_buscado) do
    contar_tipo(head, tipo_buscado) + contar_tipo_lista(tail, tipo_buscado)
  end

  # Inserta un nodo nuevo siguiendo una ruta de códigos dentro de un nodo.
  # Ruta ["s3"] significa: bajar al hijo "s3" y agregarlo allí.

  # Caso base: la ruta está vacía, el nodo nuevo se agrega aquí mismo
  defp insertar(nodo, [], nuevo) do
    cond do
      not hijo_permitido?(nodo.tipo, nuevo.tipo) -> {:error, :tipo_no_permitido}
      Enum.any?(nodo.hijos, &(&1.codigo == nuevo.codigo)) -> {:error, :codigo_existente}
      true -> {:ok, %{nodo | hijos: nodo.hijos ++ [nuevo]}}
    end
  end

  # Caso recursivo: se baja por el hijo cuyo código es el primero de la ruta
  defp insertar(nodo, [codigo | resto_ruta], nuevo) do
    case Enum.find_index(nodo.hijos, &(&1.codigo == codigo)) do
      nil ->
        {:error, :ruta_inexistente}

      indice ->
        hijo = Enum.at(nodo.hijos, indice)

        with {:ok, hijo_nuevo} <- insertar(hijo, resto_ruta, nuevo) do
          {:ok, %{nodo | hijos: List.replace_at(nodo.hijos, indice, hijo_nuevo)}}
        end
    end
  end

  # Convierte un nodo y todos sus descendientes en registros (una línea por nodo).
  # Caso base implícito: un nodo sin hijos solo genera su propio registro.
  defp aplanar(nodo, ruta_padre) do
    ruta = ruta_padre ++ [nodo.codigo]

    registro = [
      nodo.tipo,
      Enum.join(ruta, "/"),
      nodo.nombre,
      nodo.nivel,
      Integer.to_string(nodo.personas)
    ]

    [registro | Enum.flat_map(nodo.hijos, &aplanar(&1, ruta))]
  end

  # ---------- Conversión a texto plano (puras) ----------

  @doc "Convierte todas las zonas (con sus sectores y puntos) en registros para guardarlas."
  def a_registros(zonas) do
    zonas
    |> Map.values()
    |> Enum.flat_map(&aplanar(&1, []))
  end

  @doc """
  Reconstruye el mapa de zonas a partir de los registros del archivo.

  Se lee registro por registro y se va llevando el resultado (`{:ok, zonas}`);
  si en algún registro hay un error, ese error se conserva hasta el final.
  Los registros están en orden: cada padre aparece antes que sus hijos.
  """
  def desde_registros(registros) do
    Enum.reduce(registros, {:ok, %{}}, fn
      registro, {:ok, zonas} -> agregar_registro(zonas, registro)
      _registro, {:error, motivo} -> {:error, motivo}
    end)
  end

  # ---------- Efectos: archivos ----------

  @doc "Carga las zonas guardadas (mapa vacío si es la primera vez)."
  def cargar do
    with {:ok, registros} <- Persistencia.cargar(@archivo_zonas) do
      desde_registros(registros)
    end
  end

  @doc "Guarda todas las zonas en el archivo."
  def guardar(zonas) do
    Persistencia.guardar(@archivo_zonas, a_registros(zonas))
  end

  # ---------- El "cómo" ----------

  defp crear_nodo(tipo, codigo, nombre, nivel, personas) do
    with :ok <- Persistencia.validar_campos([codigo, nombre, nivel]),
         :ok <- validar_codigo(codigo),
         :ok <- validar_nivel(nivel),
         :ok <- validar_personas(personas) do
      {:ok, %{tipo: tipo, codigo: codigo, nombre: nombre, nivel: nivel, personas: personas, hijos: []}}
    end
  end

  # Coloca un nodo en el árbol. La ruta indica dónde: [] = zona nueva,
  # [zona] = sector de esa zona, [zona, sector] = punto de ese sector.
  defp colocar(zonas, [], %{tipo: "zona"} = zona) do
    if existe_zona?(zonas, zona.codigo) do
      {:error, :zona_existente}
    else
      {:ok, Map.put(zonas, zona.codigo, zona)}
    end
  end

  defp colocar(_zonas, [], _nodo), do: {:error, :ruta_inexistente}

  defp colocar(zonas, [codigo_zona | ruta_en_zona], nodo) do
    with {:ok, zona} <- buscar_zona(zonas, codigo_zona),
         {:ok, zona_nueva} <- insertar(zona, ruta_en_zona, nodo) do
      {:ok, Map.put(zonas, codigo_zona, zona_nueva)}
    end
  end

  defp agregar_registro(zonas, [tipo, ruta, nombre, nivel, personas]) do
    # "centro/s3/p1" => ruta_padre ["centro", "s3"], codigo "p1"
    {ruta_padre, [codigo]} = ruta |> String.split("/") |> Enum.split(-1)

    with {:ok, personas} <- Persistencia.a_entero(personas),
         {:ok, nodo} <- crear_nodo(tipo, codigo, nombre, nivel, personas) do
      colocar(zonas, ruta_padre, nodo)
    end
  end

  defp agregar_registro(_zonas, _registro_corrupto), do: {:error, :registro_corrupto}

  defp buscar_zona(zonas, codigo_zona) do
    case Map.fetch(zonas, codigo_zona) do
      {:ok, zona} -> {:ok, zona}
      :error -> {:error, :zona_inexistente}
    end
  end

  defp detalle_sector(sector) do
    %{
      codigo: sector.codigo,
      nombre: sector.nombre,
      nivel: sector.nivel,
      personas_afectadas: total_personas(sector),
      puntos_atencion: contar_tipo(sector, "punto")
    }
  end

  defp hijo_permitido?("zona", "sector"), do: true
  defp hijo_permitido?("sector", "punto"), do: true
  defp hijo_permitido?(_padre, _hijo), do: false

  # El código no puede llevar "/" porque separa los códigos en la ruta del archivo
  defp validar_codigo(codigo) do
    if String.contains?(codigo, "/"), do: {:error, :caracter_invalido}, else: :ok
  end

  defp validar_nivel(nivel) when nivel in @niveles_validos, do: :ok
  defp validar_nivel(_nivel), do: {:error, :nivel_invalido}

  defp validar_personas(personas) when is_integer(personas) and personas >= 0, do: :ok
  defp validar_personas(_personas), do: {:error, :cantidad_invalida}
end
