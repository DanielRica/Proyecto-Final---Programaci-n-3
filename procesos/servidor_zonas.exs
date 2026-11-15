# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule ServidorZonas do
  @moduledoc """
  Proceso (GenServer) que guarda las zonas con sus sectores y puntos de atención.

  Funciona igual que `ServidorRecursos` (ver la explicación de GenServer allí):
  el estado es el mapa de zonas, los mensajes se atienden uno a la vez y el
  archivo se guarda después de cada cambio.
  """

  use GenServer

  # ---------- API pública ----------

  def start_link(_argumento \\ :ok) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def registrar_zona(codigo, nombre, nivel, personas \\ 0) do
    GenServer.call(__MODULE__, {:registrar_zona, codigo, nombre, nivel, personas})
  end

  def agregar_sector(codigo_zona, codigo, nombre, nivel, personas \\ 0) do
    GenServer.call(__MODULE__, {:agregar_sector, codigo_zona, codigo, nombre, nivel, personas})
  end

  def agregar_punto(codigo_zona, codigo_sector, codigo, nombre, nivel, personas \\ 0) do
    GenServer.call(__MODULE__, {:agregar_punto, codigo_zona, codigo_sector, codigo, nombre, nivel, personas})
  end

  def estado_zona(codigo_zona), do: GenServer.call(__MODULE__, {:estado_zona, codigo_zona})

  def existe_zona?(codigo_zona), do: GenServer.call(__MODULE__, {:existe_zona, codigo_zona})

  @doc "Estado de todas las zonas, ordenadas por código."
  def resumen, do: GenServer.call(__MODULE__, :resumen)

  # ---------- Callbacks ----------

  @impl true
  def init(:ok) do
    case Zonas.cargar() do
      {:ok, zonas} -> {:ok, zonas}
      {:error, razon} -> {:stop, {:no_se_pudo_cargar, razon}}
    end
  end

  # Operaciones que MODIFICAN
  @impl true
  def handle_call({:registrar_zona, codigo, nombre, nivel, personas}, _desde, zonas) do
    zonas
    |> Zonas.registrar_zona(codigo, nombre, nivel, personas)
    |> responder(zonas)
  end

  def handle_call({:agregar_sector, codigo_zona, codigo, nombre, nivel, personas}, _desde, zonas) do
    zonas
    |> Zonas.agregar_sector(codigo_zona, codigo, nombre, nivel, personas)
    |> responder(zonas)
  end

  def handle_call({:agregar_punto, codigo_zona, codigo_sector, codigo, nombre, nivel, personas}, _desde, zonas) do
    zonas
    |> Zonas.agregar_punto(codigo_zona, codigo_sector, codigo, nombre, nivel, personas)
    |> responder(zonas)
  end

  # Consultas
  def handle_call({:estado_zona, codigo_zona}, _desde, zonas) do
    {:reply, Zonas.estado_zona(zonas, codigo_zona), zonas}
  end

  def handle_call({:existe_zona, codigo_zona}, _desde, zonas) do
    {:reply, Zonas.existe_zona?(zonas, codigo_zona), zonas}
  end

  def handle_call(:resumen, _desde, zonas) do
    resumen =
      zonas
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(fn codigo ->
        {:ok, estado} = Zonas.estado_zona(zonas, codigo)
        estado
      end)

    {:reply, resumen, zonas}
  end

  # ---------- El "cómo" ----------

  # Las funciones de `Zonas` que modifican devuelven `{:ok, zonas_nuevas}` (sin
  # elemento extra), por eso aquí la respuesta al cliente es solo `:ok`.
  defp responder({:ok, nuevo}, anterior) do
    case Zonas.guardar(nuevo) do
      :ok -> {:reply, :ok, nuevo}
      {:error, razon} -> {:reply, {:error, {:persistencia, razon}}, anterior}
    end
  end

  defp responder({:error, motivo}, anterior), do: {:reply, {:error, motivo}, anterior}
end
