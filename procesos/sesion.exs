# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Sesion do
  @moduledoc """
  Proceso (GenServer) que representa la sesión de UN usuario conectado.

  Hay uno por cada usuario conectado. No tiene nombre propio (hay muchos),
  así que se le habla por su pid. Los crea y los termina un
  `DynamicSupervisor` (ver `SupervisorPrincipal`), porque la cantidad de
  usuarios conectados cambia mientras el sistema está corriendo.

  `restart: :temporary` significa que, si una sesión se cae, el supervisor
  NO la reinicia: el usuario simplemente tiene que volver a conectarse.
  """

  use GenServer, restart: :temporary

  # ---------- API pública ----------

  @doc "Inicia la sesión de un usuario (lo llama el DynamicSupervisor)."
  def start_link(usuario), do: GenServer.start_link(__MODULE__, usuario)

  @doc """
  Suma una acción realizada por el usuario. Usa `cast`: envía el mensaje y
  NO espera respuesta (a diferencia de `call`).
  """
  def contar_accion(pid), do: GenServer.cast(pid, :contar_accion)

  @doc "Devuelve los datos de la sesión: usuario, cuándo se conectó y cuántas acciones lleva."
  def informacion(pid), do: GenServer.call(pid, :informacion)

  # ---------- Callbacks ----------

  @impl true
  def init(usuario) do
    desde = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    {:ok, %{usuario: usuario, acciones: 0, desde: desde}}
  end

  @impl true
  def handle_cast(:contar_accion, estado) do
    {:noreply, %{estado | acciones: estado.acciones + 1}}
  end

  @impl true
  def handle_call(:informacion, _desde, estado) do
    {:reply, estado, estado}
  end
end
