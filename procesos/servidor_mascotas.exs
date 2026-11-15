# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule ServidorMascotas do
  @moduledoc """
  Proceso (GenServer) que guarda los reportes de mascotas perdidas y encontradas.

  Funciona igual que `ServidorRecursos` (ver la explicación de GenServer allí).
  Como atiende un mensaje a la vez, dos usuarios que intenten confirmar la
  misma coincidencia al mismo tiempo no pueden cerrar un reporte dos veces:
  el segundo encuentra el reporte ya resuelto.
  """

  use GenServer

  # ---------- API pública ----------

  def start_link(_argumento \\ :ok) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def registrar(tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas \\ "sin_datos") do
    GenServer.call(__MODULE__, {:registrar, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas})
  end

  def consultar(filtros \\ %{}), do: GenServer.call(__MODULE__, {:consultar, filtros})

  @doc "Comando `match_pets`: busca coincidencias y marca los reportes como posible coincidencia."
  def marcar_posibles, do: GenServer.call(__MODULE__, :marcar_posibles)

  def confirmar_coincidencia(id_perdida, id_encontrada) do
    GenServer.call(__MODULE__, {:confirmar, id_perdida, id_encontrada})
  end

  # ---------- Callbacks ----------

  @impl true
  def init(:ok) do
    case Mascotas.cargar() do
      {:ok, reportes} -> {:ok, reportes}
      {:error, razon} -> {:stop, {:no_se_pudo_cargar, razon}}
    end
  end

  # Operaciones que MODIFICAN
  @impl true
  def handle_call({:registrar, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas}, _desde, reportes) do
    reportes
    |> Mascotas.registrar(tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas)
    |> responder(reportes)
  end

  def handle_call(:marcar_posibles, _desde, reportes) do
    reportes
    |> Mascotas.marcar_posibles()
    |> responder(reportes)
  end

  def handle_call({:confirmar, id_perdida, id_encontrada}, _desde, reportes) do
    reportes
    |> Mascotas.confirmar_coincidencia(id_perdida, id_encontrada)
    |> responder(reportes)
  end

  # Consultas
  def handle_call({:consultar, filtros}, _desde, reportes) do
    {:reply, Mascotas.consultar(reportes, filtros), reportes}
  end

  # ---------- El "cómo" ----------

  defp responder({:ok, nuevo, elemento}, anterior) do
    case Mascotas.guardar(nuevo) do
      :ok -> {:reply, {:ok, elemento}, nuevo}
      {:error, razon} -> {:reply, {:error, {:persistencia, razon}}, anterior}
    end
  end

  defp responder({:error, motivo}, anterior), do: {:reply, {:error, motivo}, anterior}
end
