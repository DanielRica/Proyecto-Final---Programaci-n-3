# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Mascotas do
  @moduledoc """
  Gestión de reportes de mascotas perdidas y encontradas.

  Los reportes se guardan en un mapa: la llave es el identificador ("PET001").

      %{id: "PET001", tipo: "perdida", especie: "perro", nombre: "Luna",
        caracteristicas: "collar rojo", color: "negra", tamano: "mediana",
        zona: "norte", contacto: "3001234567", estado: "activa", coincidencia: "-"}

  `nombre` es "desconocido" si no se conoce, y `coincidencia` guarda el
  identificador del reporte con el que se confirmó la coincidencia ("-" si
  todavía no hay).

  ## Puntaje de coincidencia (0 a 100)

  Se compara un reporte "perdida" con uno "encontrada":

  - Especie igual: 30 puntos (OBLIGATORIA: si la especie es distinta, el puntaje es 0).
  - Zona igual: 25 puntos.
  - Color igual: 20 puntos.
  - Tamaño igual: 15 puntos.
  - Características: hasta 10 puntos, según cuántas palabras tienen en común.

  Desde 60 puntos se considera una "posible coincidencia".
  """

  @tipos ["perdida", "encontrada"]
  @tamanos ["pequena", "mediana", "grande"]
  @umbral_coincidencia 60
  @archivo_mascotas "mascotas.txt"

  # ---------- El "qué" (funciones puras) ----------

  @doc """
  Registra un reporte (comando `report_pet`), con estado "activa".
  `tipo` es "perdida" o "encontrada" y `tamano` es "pequena", "mediana" o "grande".
  Las características son opcionales.
  Devuelve `{:ok, reportes, reporte}` o `{:error, motivo}`.

  ## Ejemplo
  iex> Mascotas.registrar(%{}, "perdida", "perro", "Luna", "negra", "mediana", "norte", "3001234567")
  {:ok, %{"PET001" => %{...}}, %{id: "PET001", estado: "activa", ...}}
  """
  def registrar(reportes, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas \\ "sin_datos") do
    with :ok <- Persistencia.validar_campos([tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas]),
         :ok <- validar_tipo(tipo),
         :ok <- validar_tamano(tamano) do
      id = siguiente_id(reportes)

      reporte = %{
        id: id,
        tipo: tipo,
        especie: especie,
        nombre: nombre,
        caracteristicas: caracteristicas,
        color: color,
        tamano: tamano,
        zona: zona,
        contacto: contacto,
        estado: "activa",
        coincidencia: "-"
      }

      {:ok, Map.put(reportes, id, reporte), reporte}
    end
  end

  @doc """
  Consulta reportes filtrando por especie, zona, estado y/o tipo.
  Sale ordenado por identificador.
  """
  def consultar(reportes, filtros \\ %{}) do
    reportes
    |> Map.values()
    |> Enum.filter(fn reporte ->
      Enum.all?(filtros, fn {campo, valor} -> Map.get(reporte, campo) == valor end)
    end)
    |> Util2.ordenar(:asc, & &1.id)
  end

  @doc """
  Busca posibles coincidencias entre las perdidas y las encontradas que
  todavía no están resueltas. Devuelve solo las parejas con puntaje de al
  menos 60, de mayor a menor puntaje. No modifica los reportes.

  ## Ejemplo
  iex> Mascotas.buscar_coincidencias(reportes)
  [%{perdida: "PET001", encontrada: "PET003", puntaje: 95}]
  """
  def buscar_coincidencias(reportes) do
    perdidas = abiertos(reportes, "perdida")
    encontradas = abiertos(reportes, "encontrada")

    perdidas
    |> Enum.flat_map(fn perdida -> Enum.map(encontradas, &comparar(perdida, &1)) end)
    |> Enum.filter(&(&1.puntaje >= @umbral_coincidencia))
    |> Util2.ordenar(:desc, & &1.puntaje)
  end

  @doc """
  Comando `match_pets`: busca coincidencias y marca como "posible_coincidencia"
  los reportes involucrados. Devuelve `{:ok, reportes, coincidencias}`.
  """
  def marcar_posibles(reportes) do
    coincidencias = buscar_coincidencias(reportes)

    nuevos =
      Enum.reduce(coincidencias, reportes, fn coincidencia, acumulados ->
        acumulados
        |> cambiar_estado(coincidencia.perdida, "posible_coincidencia")
        |> cambiar_estado(coincidencia.encontrada, "posible_coincidencia")
      end)

    {:ok, nuevos, coincidencias}
  end

  @doc """
  Confirma una coincidencia: cierra los DOS reportes ("resuelta") y guarda en
  cada uno el identificador del otro. Un reporte ya resuelto no se puede
  cerrar de nuevo.

  ## Ejemplos
  iex> Mascotas.confirmar_coincidencia(reportes, "PET001", "PET003")
  {:ok, reportes, {%{id: "PET001", estado: "resuelta", coincidencia: "PET003", ...}, %{id: "PET003", ...}}}
  iex> Mascotas.confirmar_coincidencia(reportes, "PET001", "PET003")  # otra vez
  {:error, :reporte_ya_resuelto}
  """
  def confirmar_coincidencia(reportes, id_perdida, id_encontrada) do
    with {:ok, perdida} <- buscar(reportes, id_perdida),
         {:ok, encontrada} <- buscar(reportes, id_encontrada),
         :ok <- validar_tipos(perdida, encontrada),
         :ok <- validar_abierto(perdida),
         :ok <- validar_abierto(encontrada) do
      perdida_cerrada = %{perdida | estado: "resuelta", coincidencia: encontrada.id}
      encontrada_cerrada = %{encontrada | estado: "resuelta", coincidencia: perdida.id}

      nuevos =
        reportes
        |> Map.put(perdida.id, perdida_cerrada)
        |> Map.put(encontrada.id, encontrada_cerrada)

      {:ok, nuevos, {perdida_cerrada, encontrada_cerrada}}
    end
  end

  @doc """
  Puntaje de coincidencia (0 a 100) entre dos reportes.

  Traza: perro negro mediano del norte con "collar rojo manchas blancas"
  contra perro negro mediano del norte con "collar rojo":
  30 (especie) + 25 (zona) + 20 (color) + 15 (tamaño)
  + 10 * 2 palabras comunes / 4 palabras en total = 5  =>  95
  """
  def puntaje(reporte_a, reporte_b) do
    if igual?(reporte_a.especie, reporte_b.especie) do
      30 +
        puntos_si(igual?(reporte_a.zona, reporte_b.zona), 25) +
        puntos_si(igual?(reporte_a.color, reporte_b.color), 20) +
        puntos_si(igual?(reporte_a.tamano, reporte_b.tamano), 15) +
        puntos_caracteristicas(reporte_a.caracteristicas, reporte_b.caracteristicas)
    else
      0
    end
  end

  # ---------- Conversión a texto plano (puras) ----------

  @doc "Convierte todos los reportes en registros para guardarlos."
  def a_registros(reportes) do
    reportes
    |> Map.values()
    |> Enum.map(&a_campos/1)
  end

  @doc """
  Convierte los registros del archivo en el mapa de reportes.
  Recursiva: arma el mapa con los reportes que quedan y le agrega el primero.
  """
  # Caso base: sin registros, el mapa está vacío
  def desde_registros([]), do: {:ok, %{}}

  # Caso recursivo: se convierte el primer registro y luego el resto
  def desde_registros([head | tail]) do
    with {:ok, reporte} <- desde_campos(head),
         {:ok, resto} <- desde_registros(tail) do
      {:ok, Map.put(resto, reporte.id, reporte)}
    end
  end

  # ---------- Efectos: archivos ----------

  @doc "Carga los reportes guardados (mapa vacío si es la primera vez)."
  def cargar do
    with {:ok, registros} <- Persistencia.cargar(@archivo_mascotas) do
      desde_registros(registros)
    end
  end

  @doc "Guarda todos los reportes en el archivo."
  def guardar(reportes) do
    Persistencia.guardar(@archivo_mascotas, a_registros(reportes))
  end

  # ---------- El "cómo" ----------

  # 0 reportes => "PET001", 1 => "PET002", ... (nunca se borran)
  defp siguiente_id(reportes) do
    numero = map_size(reportes) + 1
    "PET" <> String.pad_leading(Integer.to_string(numero), 3, "0")
  end

  defp buscar(reportes, id) do
    case Map.fetch(reportes, id) do
      {:ok, reporte} -> {:ok, reporte}
      :error -> {:error, :reporte_inexistente}
    end
  end

  # Reportes de un tipo que todavía no están resueltos
  defp abiertos(reportes, tipo) do
    reportes
    |> Map.values()
    |> Enum.filter(&(&1.tipo == tipo and &1.estado != "resuelta"))
    |> Util2.ordenar(:asc, & &1.id)
  end

  defp comparar(perdida, encontrada) do
    %{perdida: perdida.id, encontrada: encontrada.id, puntaje: puntaje(perdida, encontrada)}
  end

  defp cambiar_estado(reportes, id, nuevo_estado) do
    Map.update!(reportes, id, &%{&1 | estado: nuevo_estado})
  end

  # Compara textos sin importar mayúsculas ("Negra" == "negra")
  defp igual?(texto_a, texto_b), do: String.downcase(texto_a) == String.downcase(texto_b)

  defp puntos_si(true, puntos), do: puntos
  defp puntos_si(false, _puntos), do: 0

  # Hasta 10 puntos según el parecido de las palabras (palabras comunes / palabras distintas en total)
  defp puntos_caracteristicas(texto_a, texto_b) do
    palabras_a = palabras(texto_a)
    palabras_b = palabras(texto_b)
    total = MapSet.size(MapSet.union(palabras_a, palabras_b))
    comunes = MapSet.size(MapSet.intersection(palabras_a, palabras_b))

    if total == 0, do: 0, else: round(10 * comunes / total)
  end

  # "sin_datos" significa que no se dieron características
  defp palabras("sin_datos"), do: MapSet.new()

  defp palabras(texto) do
    texto
    |> String.downcase()
    |> String.split(" ", trim: true)
    |> MapSet.new()
  end

  defp validar_tipo(tipo) when tipo in @tipos, do: :ok
  defp validar_tipo(_tipo), do: {:error, :tipo_invalido}

  defp validar_tamano(tamano) when tamano in @tamanos, do: :ok
  defp validar_tamano(_tamano), do: {:error, :tamano_invalido}

  defp validar_tipos(%{tipo: "perdida"}, %{tipo: "encontrada"}), do: :ok
  defp validar_tipos(_perdida, _encontrada), do: {:error, :tipos_incompatibles}

  defp validar_abierto(%{estado: "resuelta"}), do: {:error, :reporte_ya_resuelto}
  defp validar_abierto(_reporte), do: :ok

  defp a_campos(reporte) do
    [
      reporte.id,
      reporte.tipo,
      reporte.especie,
      reporte.nombre,
      reporte.caracteristicas,
      reporte.color,
      reporte.tamano,
      reporte.zona,
      reporte.contacto,
      reporte.estado,
      reporte.coincidencia
    ]
  end

  defp desde_campos([id, tipo, especie, nombre, caracteristicas, color, tamano, zona, contacto, estado, coincidencia]) do
    {:ok,
     %{
       id: id,
       tipo: tipo,
       especie: especie,
       nombre: nombre,
       caracteristicas: caracteristicas,
       color: color,
       tamano: tamano,
       zona: zona,
       contacto: contacto,
       estado: estado,
       coincidencia: coincidencia
     }}
  end

  defp desde_campos(_registro_corrupto), do: {:error, :registro_corrupto}
end
