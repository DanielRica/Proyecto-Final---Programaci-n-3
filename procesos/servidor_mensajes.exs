# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule ServidorMensajes do
  @moduledoc """
  Proceso (GenServer) que guarda los mensajes entre familiares.

  Funciona igual que `ServidorRecursos` (ver la explicación de GenServer allí).
  La fecha de cada mensaje la pone este servidor al recibirlo.
  """

  use GenServer

  # ---------- API pública ----------

  def start_link(_argumento \\ :ok) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def enviar(remitente, destinatario, contenido) do
    GenServer.call(__MODULE__, {:enviar, remitente, destinatario, contenido})
  end

  def marcar_entregado(id), do: GenServer.call(__MODULE__, {:marcar_entregado, id})

  def marcar_pendiente(id), do: GenServer.call(__MODULE__, {:marcar_pendiente, id})

  def listar_para(destinatario, estado \\ nil), do: GenServer.call(__MODULE__, {:listar_para, destinatario, estado})

  def todos, do: GenServer.call(__MODULE__, :todos)

  # ---------- Callbacks ----------

  @impl true
  def init(:ok) do
    case Mensajes.cargar() do
      {:ok, mensajes} -> {:ok, mensajes}
      {:error, razon} -> {:stop, {:no_se_pudo_cargar, razon}}
    end
  end

  # Operaciones que MODIFICAN
  @impl true
  def handle_call({:enviar, remitente, destinatario, contenido}, _desde, mensajes) do
    mensajes
    |> Mensajes.enviar(Mensajes.fecha_actual(), remitente, destinatario, contenido)
    |> responder(mensajes)
  end

  def handle_call({:marcar_entregado, id}, _desde, mensajes) do
    mensajes
    |> Mensajes.marcar_entregado(id)
    |> responder(mensajes)
  end

  def handle_call({:marcar_pendiente, id}, _desde, mensajes) do
    mensajes
    |> Mensajes.marcar_pendiente(id)
    |> responder(mensajes)
  end

  # Consultas
  def handle_call({:listar_para, destinatario, estado}, _desde, mensajes) do
    {:reply, Mensajes.listar_para(mensajes, destinatario, estado), mensajes}
  end

  def handle_call(:todos, _desde, mensajes) do
    {:reply, Mensajes.todos(mensajes), mensajes}
  end

  # ---------- El "cómo" ----------

  defp responder({:ok, nuevo, elemento}, anterior) do
    case Mensajes.guardar(nuevo) do
      :ok -> {:reply, {:ok, elemento}, nuevo}
      {:error, razon} -> {:reply, {:error, {:persistencia, razon}}, anterior}
    end
  end

  defp responder({:error, motivo}, anterior), do: {:reply, {:error, motivo}, anterior}
end
