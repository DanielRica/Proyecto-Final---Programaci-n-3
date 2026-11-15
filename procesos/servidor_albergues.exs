# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule ServidorAlbergues do
  @moduledoc """
  Proceso (GenServer) que guarda los albergues.

  Funciona igual que `ServidorRecursos` (ver la explicación de GenServer allí).
  Como atiende un mensaje a la vez, si dos personas piden entrar al mismo
  tiempo al último cupo, solo una entra: la segunda encuentra el albergue
  lleno. La ocupación nunca supera la capacidad.
  """

  use GenServer

  # ---------- API pública ----------

  def start_link(_argumento \\ :ok) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def detener, do: GenServer.stop(__MODULE__)

  def registrar(codigo, nombre, zona, capacidad, ocupacion \\ 0) do
    GenServer.call(__MODULE__, {:registrar, codigo, nombre, zona, capacidad, ocupacion})
  end

  def registrar_ingreso(codigo, documento), do: GenServer.call(__MODULE__, {:ingreso, codigo, documento})

  def registrar_salida(codigo, documento), do: GenServer.call(__MODULE__, {:salida, codigo, documento})

  def consultar_cupos(codigo), do: GenServer.call(__MODULE__, {:cupos, codigo})

  def mayor_ocupacion(cantidad \\ 3), do: GenServer.call(__MODULE__, {:mayor_ocupacion, cantidad})

  # ---------- Callbacks ----------

  @impl true
  def init(:ok) do
    case Albergues.cargar() do
      {:ok, albergues} -> {:ok, albergues}
      {:error, razon} -> {:stop, {:no_se_pudo_cargar, razon}}
    end
  end

  # Operaciones que MODIFICAN
  @impl true
  def handle_call({:registrar, codigo, nombre, zona, capacidad, ocupacion}, _desde, albergues) do
    albergues
    |> Albergues.registrar(codigo, nombre, zona, capacidad, ocupacion)
    |> responder(albergues)
  end

  def handle_call({:ingreso, codigo, documento}, _desde, albergues) do
    albergues
    |> Albergues.registrar_ingreso(codigo, documento)
    |> responder(albergues)
  end

  def handle_call({:salida, codigo, documento}, _desde, albergues) do
    albergues
    |> Albergues.registrar_salida(codigo, documento)
    |> responder(albergues)
  end

  # Consultas
  def handle_call({:cupos, codigo}, _desde, albergues) do
    {:reply, Albergues.consultar_cupos(albergues, codigo), albergues}
  end

  def handle_call({:mayor_ocupacion, cantidad}, _desde, albergues) do
    {:reply, Albergues.mayor_ocupacion(albergues, cantidad), albergues}
  end

  # ---------- El "cómo" ----------

  # Si salió bien: guarda el archivo y el mapa nuevo pasa a ser el estado.
  # Si algo falla (lógica o archivo), el estado queda como estaba.
  defp responder({:ok, nuevo, elemento}, anterior) do
    case Albergues.guardar(nuevo) do
      :ok -> {:reply, {:ok, elemento}, nuevo}
      {:error, razon} -> {:reply, {:error, {:persistencia, razon}}, anterior}
    end
  end

  defp responder({:error, motivo}, anterior), do: {:reply, {:error, motivo}, anterior}
end
