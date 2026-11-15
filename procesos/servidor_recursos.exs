# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule ServidorRecursos do
  @moduledoc """
  Proceso (GenServer) que guarda el inventario de recursos.

  ## ¿Qué es un GenServer?

  Es un proceso que:
  1. Guarda un ESTADO (aquí: el inventario completo).
  2. Recibe mensajes de otros procesos y los atiende UNO A LA VEZ, en el
     orden en que llegaron (cada proceso tiene un buzón, como el
     `receive` que mostró el profe).
  3. Responde a quien le escribió.

  Eso resuelve el problema de la concurrencia: aunque 100 procesos pidan
  recursos al mismo tiempo, el GenServer los atiende de a uno, así que la
  cantidad asignada nunca puede superar el inventario.

  Cada operación se hace en dos pasos:
  - `GenServer.call(servidor, mensaje)`: el cliente envía el mensaje y ESPERA la respuesta.
  - `handle_call(mensaje, desde, estado)`: el servidor atiende el mensaje y devuelve
    `{:reply, respuesta, nuevo_estado}`.

  Este módulo solo coordina: la lógica de verdad está en el módulo `Recursos`.
  Después de cada cambio exitoso se guarda el inventario en el archivo.
  """

  use GenServer

  # ---------- API pública: lo que usan los demás ----------

  @doc "Inicia el servidor y lo registra con el nombre `ServidorRecursos`."
  def start_link(_argumento \\ :ok) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Detiene el servidor (el inventario ya está guardado en el archivo)."
  def detener, do: GenServer.stop(__MODULE__)

  def registrar(codigo, nombre, categoria, cantidad, unidad, ubicacion, zona) do
    GenServer.call(__MODULE__, {:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion, zona})
  end

  def registrar_entrada(codigo, cantidad, detalle) do
    GenServer.call(__MODULE__, {:entrada, codigo, cantidad, detalle})
  end

  def registrar_salida(codigo, cantidad, detalle) do
    GenServer.call(__MODULE__, {:salida, codigo, cantidad, detalle})
  end

  @doc "Toma recursos de una categoría para una necesidad. Devuelve `{:ok, tomas}` o `{:error, motivo}`."
  def asignar(categoria, cantidad, id_necesidad, zona) do
    GenServer.call(__MODULE__, {:asignar, categoria, cantidad, id_necesidad, zona})
  end

  @doc "Devuelve al inventario lo asignado a una necesidad."
  def liberar_necesidad(id_necesidad) do
    GenServer.call(__MODULE__, {:liberar_necesidad, id_necesidad})
  end

  def transferir(codigo, origen, destino, cantidad) do
    GenServer.call(__MODULE__, {:transferir, codigo, origen, destino, cantidad})
  end

  def consultar(filtros \\ %{}), do: GenServer.call(__MODULE__, {:consultar, filtros})

  def disponible_total(filtros \\ %{}), do: GenServer.call(__MODULE__, {:disponible_total, filtros})

  def con_poco_inventario(umbral \\ 10), do: GenServer.call(__MODULE__, {:poco_inventario, umbral})

  def historial(codigo), do: GenServer.call(__MODULE__, {:historial, codigo})

  # ---------- Callbacks: lo que hace el proceso por dentro ----------

  # `init` se ejecuta una sola vez, al arrancar. Lo que devuelva dentro de
  # `{:ok, ...}` es el estado inicial: aquí, el inventario que está en el archivo.
  @impl true
  def init(:ok) do
    case Recursos.cargar() do
      {:ok, inventario} -> {:ok, inventario}
      {:error, razon} -> {:stop, {:no_se_pudo_cargar, razon}}
    end
  end

  # Operaciones que MODIFICAN: se aplica la función pura y se responde con `responder/2`.
  @impl true
  def handle_call({:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion, zona}, _desde, inventario) do
    inventario
    |> Recursos.registrar(codigo, nombre, categoria, cantidad, unidad, ubicacion, zona)
    |> responder(inventario)
  end

  def handle_call({:entrada, codigo, cantidad, detalle}, _desde, inventario) do
    inventario
    |> Recursos.registrar_entrada(codigo, cantidad, detalle)
    |> responder(inventario)
  end

  def handle_call({:salida, codigo, cantidad, detalle}, _desde, inventario) do
    inventario
    |> Recursos.registrar_salida(codigo, cantidad, detalle)
    |> responder(inventario)
  end

  def handle_call({:asignar, categoria, cantidad, id_necesidad, zona}, _desde, inventario) do
    inventario
    |> Recursos.asignar(categoria, cantidad, id_necesidad, zona)
    |> responder(inventario)
  end

  def handle_call({:liberar_necesidad, id_necesidad}, _desde, inventario) do
    inventario
    |> Recursos.liberar_necesidad(id_necesidad)
    |> responder(inventario)
  end

  def handle_call({:transferir, codigo, origen, destino, cantidad}, _desde, inventario) do
    inventario
    |> Recursos.transferir(codigo, origen, destino, cantidad)
    |> responder(inventario)
  end

  # Consultas: solo leen, el estado queda igual.
  def handle_call({:consultar, filtros}, _desde, inventario) do
    {:reply, Recursos.consultar(inventario, filtros), inventario}
  end

  def handle_call({:disponible_total, filtros}, _desde, inventario) do
    {:reply, Recursos.disponible_total(inventario, filtros), inventario}
  end

  def handle_call({:poco_inventario, umbral}, _desde, inventario) do
    {:reply, Recursos.con_poco_inventario(inventario, umbral), inventario}
  end

  def handle_call({:historial, codigo}, _desde, inventario) do
    {:reply, Recursos.historial(inventario, codigo), inventario}
  end

  # ---------- El "cómo" ----------

  # Si la operación salió bien, guarda el archivo y el inventario nuevo pasa a
  # ser el estado. Si el archivo no se pudo guardar, el estado NO cambia
  # (así el estado y el archivo nunca quedan distintos).
  # Si hubo un error de la lógica, el estado tampoco cambia.
  defp responder({:ok, nuevo, elemento}, anterior) do
    case Recursos.guardar(nuevo) do
      :ok -> {:reply, {:ok, elemento}, nuevo}
      {:error, razon} -> {:reply, {:error, {:persistencia, razon}}, anterior}
    end
  end

  defp responder({:error, motivo}, anterior), do: {:reply, {:error, motivo}, anterior}
end
