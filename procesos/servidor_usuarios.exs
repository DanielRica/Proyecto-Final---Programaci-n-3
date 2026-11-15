# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule ServidorUsuarios do
  @moduledoc """
  Proceso (GenServer) que guarda los usuarios registrados y controla quién
  está conectado.

  Funciona como `ServidorRecursos` (ver la explicación de GenServer allí),
  con una diferencia: su estado tiene DOS partes.

      %{usuarios: %{"laura" => %{...}},      # todos los registrados (se guardan en archivo)
        sesiones: %{"laura" => #PID<0.150.0>}}   # los conectados ahora (solo en memoria)

  Al conectarse un usuario se crea un proceso `Sesion` dentro del
  `DynamicSupervisor` `SupervisorSesiones`; al desconectarse, se termina.
  """

  use GenServer

  # ---------- API pública ----------

  def start_link(_argumento \\ :ok) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Comando `connect`. Si el usuario no existe lo registra; si existe valida la
  contraseña. Crea su sesión.
  Devuelve `{:ok, %{usuario: datos_sin_contraseña, como: :registrado | :autenticado}}`
  o `{:error, motivo}`.
  """
  def conectar(nombre_usuario, contrasena, tipo, zona) do
    GenServer.call(__MODULE__, {:conectar, nombre_usuario, contrasena, tipo, zona})
  end

  @doc "Comando `disconnect`. Termina la sesión del usuario."
  def desconectar(nombre_usuario), do: GenServer.call(__MODULE__, {:desconectar, nombre_usuario})

  @doc "Datos del usuario SI está conectado (sin la contraseña); si no, `{:error, :no_conectado}`."
  def sesion(nombre_usuario), do: GenServer.call(__MODULE__, {:sesion, nombre_usuario})

  @doc "Anota una acción del usuario en el historial de actividad (archivo) y en su sesión."
  def registrar_actividad(nombre_usuario, accion) do
    GenServer.call(__MODULE__, {:registrar_actividad, nombre_usuario, accion})
  end

  def actividad(nombre_usuario), do: GenServer.call(__MODULE__, {:actividad, nombre_usuario})

  @doc "Nombres de los usuarios conectados ahora."
  def conectados, do: GenServer.call(__MODULE__, :conectados)

  @doc "Información de la sesión de un usuario conectado (cuándo entró, cuántas acciones lleva)."
  def informacion_sesion(nombre_usuario), do: GenServer.call(__MODULE__, {:informacion_sesion, nombre_usuario})

  # ---------- Callbacks ----------

  # Al arrancar (o reiniciarse tras una caída) carga los usuarios del archivo.
  # Las sesiones del arranque anterior ya no tienen dueño, así que se cierran:
  # los usuarios tendrán que conectarse de nuevo.
  @impl true
  def init(:ok) do
    case Usuarios.cargar() do
      {:ok, usuarios} ->
        cerrar_sesiones_huerfanas()
        {:ok, %{usuarios: usuarios, sesiones: %{}}}

      {:error, razon} ->
        {:stop, {:no_se_pudo_cargar, razon}}
    end
  end

  @impl true
  def handle_call({:conectar, nombre_usuario, contrasena, tipo, zona}, _desde, estado) do
    case Usuarios.conectar(estado.usuarios, nombre_usuario, contrasena, tipo, zona) do
      {:ok, usuarios, usuario, como} -> conectar_exitoso(estado, usuarios, usuario, como)
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
    end
  end

  def handle_call({:desconectar, nombre_usuario}, _desde, estado) do
    case sesion_activa(estado, nombre_usuario) do
      {:ok, pid} ->
        Usuarios.registrar_actividad(nombre_usuario, "disconnect")
        DynamicSupervisor.terminate_child(SupervisorSesiones, pid)
        {:reply, :ok, %{estado | sesiones: Map.delete(estado.sesiones, nombre_usuario)}}

      :error ->
        {:reply, {:error, :no_conectado}, estado}
    end
  end

  def handle_call({:sesion, nombre_usuario}, _desde, estado) do
    case sesion_activa(estado, nombre_usuario) do
      {:ok, _pid} -> {:reply, {:ok, datos_publicos(estado.usuarios, nombre_usuario)}, estado}
      :error -> {:reply, {:error, :no_conectado}, estado}
    end
  end

  def handle_call({:registrar_actividad, nombre_usuario, accion}, _desde, estado) do
    case sesion_activa(estado, nombre_usuario) do
      {:ok, pid} ->
        Sesion.contar_accion(pid)
        {:reply, Usuarios.registrar_actividad(nombre_usuario, accion), estado}

      :error ->
        {:reply, {:error, :no_conectado}, estado}
    end
  end

  def handle_call({:actividad, nombre_usuario}, _desde, estado) do
    {:reply, Usuarios.consultar_actividad(nombre_usuario), estado}
  end

  def handle_call(:conectados, _desde, estado) do
    conectados =
      estado.sesiones
      |> Map.keys()
      |> Enum.filter(&match?({:ok, _pid}, sesion_activa(estado, &1)))
      |> Enum.sort()

    {:reply, conectados, estado}
  end

  def handle_call({:informacion_sesion, nombre_usuario}, _desde, estado) do
    case sesion_activa(estado, nombre_usuario) do
      {:ok, pid} -> {:reply, {:ok, Sesion.informacion(pid)}, estado}
      :error -> {:reply, {:error, :no_conectado}, estado}
    end
  end

  # ---------- El "cómo" ----------

  # Guarda el usuario si es nuevo, crea (o reutiliza) su sesión y responde.
  defp conectar_exitoso(estado, usuarios, usuario, como) do
    with :ok <- guardar_si_es_nuevo(usuarios, como),
         {:ok, pid} <- asegurar_sesion(estado, usuario) do
      Usuarios.registrar_actividad(usuario.nombre_usuario, "connect")
      Sesion.contar_accion(pid)

      nuevo = %{
        estado
        | usuarios: usuarios,
          sesiones: Map.put(estado.sesiones, usuario.nombre_usuario, pid)
      }

      {:reply, {:ok, %{usuario: sin_contrasena(usuario), como: como}}, nuevo}
    else
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
    end
  end

  defp guardar_si_es_nuevo(usuarios, :registrado), do: Usuarios.guardar(usuarios)
  defp guardar_si_es_nuevo(_usuarios, :autenticado), do: :ok

  # Si el usuario ya tenía una sesión viva se reutiliza (conectarse dos veces no crea dos sesiones)
  defp asegurar_sesion(estado, usuario) do
    case sesion_activa(estado, usuario.nombre_usuario) do
      {:ok, pid} -> {:ok, pid}
      :error -> DynamicSupervisor.start_child(SupervisorSesiones, {Sesion, sin_contrasena(usuario)})
    end
  end

  # La sesión cuenta solo si el proceso sigue vivo
  defp sesion_activa(estado, nombre_usuario) do
    case Map.fetch(estado.sesiones, nombre_usuario) do
      {:ok, pid} -> if Process.alive?(pid), do: {:ok, pid}, else: :error
      :error -> :error
    end
  end

  defp datos_publicos(usuarios, nombre_usuario) do
    usuarios |> Map.fetch!(nombre_usuario) |> sin_contrasena()
  end

  defp sin_contrasena(usuario), do: Map.delete(usuario, :clave)

  defp cerrar_sesiones_huerfanas do
    SupervisorSesiones
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn {_id, pid, _tipo, _modulos} ->
      DynamicSupervisor.terminate_child(SupervisorSesiones, pid)
    end)
  end
end
