# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule SupervisorPrincipal do

  use Supervisor

  # ---------- API pública ----------

  def start_link(_argumento \\ :ok) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # ---------- Callbacks ----------

  # `init` devuelve la lista de hijos. Cada módulo con `use GenServer` ya sabe
  # cómo arrancarse (llama a su `start_link/1`). El primero es el
  # DynamicSupervisor, porque `ServidorUsuarios` lo necesita al arrancar.
  @impl true
  def init(:ok) do
    hijos = [
      {DynamicSupervisor, name: SupervisorSesiones, strategy: :one_for_one},
      ServidorUsuarios,
      ServidorZonas,
      ServidorNecesidades,
      ServidorRecursos,
      ServidorAlbergues,
      ServidorPersonas,
      ServidorMensajes,
      ServidorMascotas
    ]

    Supervisor.init(hijos, strategy: :one_for_one, max_restarts: 5, max_seconds: 10)
  end
end
