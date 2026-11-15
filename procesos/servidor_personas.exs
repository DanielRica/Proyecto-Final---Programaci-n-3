# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule ServidorPersonas do
  @moduledoc """
  Proceso (GenServer) que guarda las personas afectadas.

  Funciona igual que `ServidorRecursos` (ver la explicación de GenServer allí).
  """

  use GenServer

  # ---------- API pública ----------

  def start_link(_argumento \\ :ok) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def registrar(documento, nombre, zona, estado, edad \\ nil) do
    GenServer.call(__MODULE__, {:registrar, documento, nombre, zona, estado, edad})
  end

  def cambiar_estado(documento, nuevo_estado) do
    GenServer.call(__MODULE__, {:cambiar_estado, documento, nuevo_estado})
  end

  def buscar(filtros \\ %{}), do: GenServer.call(__MODULE__, {:buscar, filtros})

  def buscar_por_documento(documento), do: GenServer.call(__MODULE__, {:buscar_por_documento, documento})

  def historial(documento), do: GenServer.call(__MODULE__, {:historial, documento})

  # ---------- Callbacks ----------

  @impl true
  def init(:ok) do
    case Personas.cargar() do
      {:ok, personas} -> {:ok, personas}
      {:error, razon} -> {:stop, {:no_se_pudo_cargar, razon}}
    end
  end

  # Operaciones que MODIFICAN
  @impl true
  def handle_call({:registrar, documento, nombre, zona, estado, edad}, _desde, personas) do
    personas
    |> Personas.registrar(documento, nombre, zona, estado, edad)
    |> responder(personas)
  end

  def handle_call({:cambiar_estado, documento, nuevo_estado}, _desde, personas) do
    personas
    |> Personas.cambiar_estado(documento, nuevo_estado)
    |> responder(personas)
  end

  # Consultas
  def handle_call({:buscar, filtros}, _desde, personas) do
    {:reply, Personas.buscar(personas, filtros), personas}
  end

  def handle_call({:buscar_por_documento, documento}, _desde, personas) do
    {:reply, Personas.buscar_por_documento(personas, documento), personas}
  end

  def handle_call({:historial, documento}, _desde, personas) do
    {:reply, Personas.historial(personas, documento), personas}
  end

  # ---------- El "cómo" ----------

  defp responder({:ok, nuevo, elemento}, anterior) do
    case Personas.guardar(nuevo) do
      :ok -> {:reply, {:ok, elemento}, nuevo}
      {:error, razon} -> {:reply, {:error, {:persistencia, razon}}, anterior}
    end
  end

  defp responder({:error, motivo}, anterior), do: {:reply, {:error, motivo}, anterior}
end
