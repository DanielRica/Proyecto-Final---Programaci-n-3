# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule ServidorNecesidades do
  @moduledoc """
  Proceso (GenServer) que guarda las necesidades puntuales.

  Funciona igual que `ServidorRecursos` (ver la explicación de GenServer allí):
  guarda el mapa de necesidades como estado, atiende los mensajes uno a la
  vez y guarda el archivo después de cada cambio.

  Como los mensajes se atienden de a uno, dos solicitudes simultáneas sobre
  la misma necesidad no pueden "resolverla" dos veces: la segunda ya la
  encuentra cambiada.
  """

  use GenServer

  # ---------- API pública ----------

  def start_link(_argumento \\ :ok) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def detener, do: GenServer.stop(__MODULE__)

  @doc "Registra una necesidad. Devuelve `{:ok, necesidad}` (con su identificador) o `{:error, motivo}`."
  def registrar(tipo, cantidad, prioridad, zona, descripcion, responsable) do
    GenServer.call(__MODULE__, {:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable})
  end

  def obtener(id), do: GenServer.call(__MODULE__, {:obtener, id})

  def consultar(filtros \\ %{}), do: GenServer.call(__MODULE__, {:consultar, filtros})

  def pendientes, do: GenServer.call(__MODULE__, :pendientes)

  def siguiente_a_atender, do: GenServer.call(__MODULE__, :siguiente)

  def cambiar_estado(id, nuevo_estado), do: GenServer.call(__MODULE__, {:cambiar_estado, id, nuevo_estado})

  @doc "Reserva `cantidad` de lo que pide la necesidad (ver `Necesidades.registrar_asignacion/3`)."
  def reservar(id, cantidad), do: GenServer.call(__MODULE__, {:reservar, id, cantidad})

  @doc "Deshace una reserva (ver `Necesidades.revertir_asignacion/3`)."
  def revertir(id, cantidad), do: GenServer.call(__MODULE__, {:revertir, id, cantidad})

  # ---------- Callbacks ----------

  @impl true
  def init(:ok) do
    case Necesidades.cargar() do
      {:ok, necesidades} -> {:ok, necesidades}
      {:error, razon} -> {:stop, {:no_se_pudo_cargar, razon}}
    end
  end

  # Operaciones que MODIFICAN
  @impl true
  def handle_call({:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable}, _desde, necesidades) do
    necesidades
    |> Necesidades.registrar(tipo, cantidad, prioridad, zona, descripcion, responsable)
    |> responder(necesidades)
  end

  def handle_call({:cambiar_estado, id, nuevo_estado}, _desde, necesidades) do
    necesidades
    |> Necesidades.cambiar_estado(id, nuevo_estado)
    |> responder(necesidades)
  end

  def handle_call({:reservar, id, cantidad}, _desde, necesidades) do
    necesidades
    |> Necesidades.registrar_asignacion(id, cantidad)
    |> responder(necesidades)
  end

  def handle_call({:revertir, id, cantidad}, _desde, necesidades) do
    necesidades
    |> Necesidades.revertir_asignacion(id, cantidad)
    |> responder(necesidades)
  end

  # Consultas
  def handle_call({:obtener, id}, _desde, necesidades) do
    {:reply, Necesidades.obtener(necesidades, id), necesidades}
  end

  def handle_call({:consultar, filtros}, _desde, necesidades) do
    {:reply, Necesidades.consultar(necesidades, filtros), necesidades}
  end

  def handle_call(:pendientes, _desde, necesidades) do
    {:reply, Necesidades.pendientes(necesidades), necesidades}
  end

  def handle_call(:siguiente, _desde, necesidades) do
    {:reply, Necesidades.siguiente_a_atender(necesidades), necesidades}
  end

  # ---------- El "cómo" ----------

  # Si salió bien: guarda el archivo y el mapa nuevo pasa a ser el estado.
  # Si algo falla (lógica o archivo), el estado queda como estaba.
  defp responder({:ok, nuevo, elemento}, anterior) do
    case Necesidades.guardar(nuevo) do
      :ok -> {:reply, {:ok, elemento}, nuevo}
      {:error, razon} -> {:reply, {:error, {:persistencia, razon}}, anterior}
    end
  end

  defp responder({:error, motivo}, anterior), do: {:reply, {:error, motivo}, anterior}
end
