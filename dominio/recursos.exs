# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Recursos do
  @moduledoc """
  Gestión de recursos y centros de apoyo: inventario, movimientos y transferencias.

  El inventario es un mapa con dos partes:

      %{recursos: %{"R001" => %{codigo: "R001", nombre: "agua", categoria: "agua",
                                cantidad: 50, unidad: "litros",
                                ubicacion: "centro_acopio_1", zona: "centro"}},
        movimientos: [%{numero: 1, codigo: "R001", tipo: "registro", cantidad: 50, detalle: "..."}]}

  Cada vez que cambia una cantidad queda un movimiento en el historial.
  La cantidad de un recurso NUNCA puede quedar negativa: cada operación
  comprueba el inventario antes de descontar.
  """

  @umbral_critico 10
  @archivo_recursos "recursos.txt"
  @archivo_movimientos "movimientos.txt"

  # ---------- El "qué" (funciones puras) ----------

  @doc "Inventario vacío."
  def nuevo, do: %{recursos: %{}, movimientos: []}

  @doc """
  Registra un recurso (comando `register_resource`). Su cantidad inicial
  queda como primer movimiento del historial.
  Devuelve `{:ok, inventario, recurso}` o `{:error, motivo}`.

  ## Ejemplo
  iex> Recursos.registrar(Recursos.nuevo(), "R001", "agua", "agua", 50, "litros", "centro_acopio_1", "centro")
  {:ok, inventario, %{codigo: "R001", cantidad: 50, ...}}
  """
  def registrar(inventario, codigo, nombre, categoria, cantidad, unidad, ubicacion, zona) do
    with :ok <- Persistencia.validar_campos([codigo, nombre, categoria, unidad, ubicacion, zona]),
         :ok <- validar_cantidad_inicial(cantidad),
         :ok <- validar_codigo_nuevo(inventario, codigo) do
      recurso = %{
        codigo: codigo,
        nombre: nombre,
        categoria: categoria,
        cantidad: 0,
        unidad: unidad,
        ubicacion: ubicacion,
        zona: zona
      }

      nuevo =
        %{inventario | recursos: Map.put(inventario.recursos, codigo, recurso)}
        |> aplicar_cambio(codigo, cantidad, "registro", "inventario inicial")

      {:ok, nuevo, Map.fetch!(nuevo.recursos, codigo)}
    end
  end

  @doc "Suma unidades a un recurso (entrada de inventario)."
  def registrar_entrada(inventario, codigo, cantidad, detalle) do
    with {:ok, _recurso} <- buscar(inventario, codigo),
         :ok <- Persistencia.validar_campos([detalle]),
         :ok <- validar_cantidad_positiva(cantidad) do
      nuevo = aplicar_cambio(inventario, codigo, cantidad, "entrada", detalle)
      {:ok, nuevo, Map.fetch!(nuevo.recursos, codigo)}
    end
  end

  @doc """
  Resta unidades a un recurso (salida de inventario). Si se piden más
  unidades de las que hay, devuelve `{:error, :inventario_insuficiente}`.
  """
  def registrar_salida(inventario, codigo, cantidad, detalle) do
    with {:ok, recurso} <- buscar(inventario, codigo),
         :ok <- Persistencia.validar_campos([detalle]),
         :ok <- validar_cantidad_positiva(cantidad),
         :ok <- validar_hay_inventario(recurso, cantidad) do
      nuevo = aplicar_cambio(inventario, codigo, -cantidad, "salida", detalle)
      {:ok, nuevo, Map.fetch!(nuevo.recursos, codigo)}
    end
  end

  @doc """
  Asigna recursos de una categoría a una necesidad (comando `assign_resource`).

  Toma primero de los recursos de la misma zona de la necesidad y, si no
  alcanzan, de los de otras zonas. Puede tomar de varios recursos a la vez.
  Si en total no hay suficiente, NO descuenta nada y devuelve
  `{:error, :inventario_insuficiente}`.

  Devuelve `{:ok, inventario, tomas}`, donde `tomas` es una lista de
  `{codigo_del_recurso, cantidad_tomada}`.

  ## Ejemplo (R001 tiene 30 en la zona centro y R002 tiene 100 en la zona norte)
  iex> Recursos.asignar(inventario, "agua", 40, "N003", "centro")
  {:ok, inventario, [{"R001", 30}, {"R002", 10}]}
  """
  def asignar(inventario, categoria, cantidad, id_necesidad, zona) do
    with :ok <- Persistencia.validar_campos([categoria, id_necesidad, zona]),
         :ok <- validar_cantidad_positiva(cantidad),
         {:ok, tomas} <- tomar(candidatos(inventario, categoria, zona), cantidad) do
      nuevo =
        Enum.reduce(tomas, inventario, fn {codigo, tomado}, acumulado ->
          aplicar_cambio(acumulado, codigo, -tomado, "asignacion", id_necesidad)
        end)

      {:ok, nuevo, tomas}
    end
  end

  @doc """
  Devuelve al inventario lo que se había asignado a una necesidad (por
  ejemplo, cuando la necesidad se cancela). Cada devolución queda como
  movimiento "liberacion". Si se llama dos veces, la segunda no devuelve
  nada porque ya no queda nada por liberar.
  Devuelve `{:ok, inventario, devueltos}`, con `devueltos` = lista de
  `{codigo_del_recurso, cantidad_devuelta}`.
  """
  def liberar_necesidad(inventario, id_necesidad) do
    devueltos = por_liberar(inventario, id_necesidad)

    nuevo =
      Enum.reduce(devueltos, inventario, fn {codigo, cantidad}, acumulado ->
        aplicar_cambio(acumulado, codigo, cantidad, "liberacion", id_necesidad)
      end)

    {:ok, nuevo, devueltos}
  end

  @doc """
  Transfiere unidades de un recurso a otro centro de apoyo
  (comando `transfer_resource codigo origen destino cantidad`).

  En el destino se crea (o se aumenta) un recurso con el código
  `codigo-destino`, por ejemplo `R001-albergue_2`. Por simplicidad, el
  recurso del destino queda en la misma zona que el de origen.
  Devuelve `{:ok, inventario, codigo_destino}`.
  """
  def transferir(inventario, codigo, origen, destino, cantidad) do
    with {:ok, recurso} <- buscar(inventario, codigo),
         :ok <- Persistencia.validar_campos([origen, destino]),
         :ok <- validar_origen(recurso, origen),
         :ok <- validar_destino(origen, destino),
         :ok <- validar_cantidad_positiva(cantidad),
         :ok <- validar_hay_inventario(recurso, cantidad) do
      codigo_destino = codigo <> "-" <> destino

      nuevo =
        inventario
        |> aplicar_cambio(codigo, -cantidad, "transferencia_salida", "hacia #{destino}")
        |> asegurar_recurso_destino(recurso, codigo_destino, destino)
        |> aplicar_cambio(codigo_destino, cantidad, "transferencia_entrada", "desde #{origen}")

      {:ok, nuevo, codigo_destino}
    end
  end

  @doc """
  Consulta recursos filtrando por categoría, zona, ubicación y/o nombre.
  Sale ordenado por código.

  ## Ejemplo
  iex> Recursos.consultar(inventario, %{categoria: "agua", zona: "centro"})
  [%{codigo: "R001", ...}]
  """
  def consultar(inventario, filtros \\ %{}) do
    inventario.recursos
    |> Map.values()
    |> Enum.filter(&cumple_filtros?(&1, filtros))
    |> Util2.ordenar(:asc, & &1.codigo)
  end

  @doc "Total de unidades que cumplen los filtros (por ejemplo, toda el agua de una zona)."
  def disponible_total(inventario, filtros \\ %{}) do
    inventario
    |> consultar(filtros)
    |> Enum.map(& &1.cantidad)
    |> Enum.sum()
  end

  @doc "Recursos con poca existencia (cantidad menor o igual al umbral, por defecto 10)."
  def con_poco_inventario(inventario, umbral \\ @umbral_critico) do
    inventario.recursos
    |> Map.values()
    |> Enum.filter(&(&1.cantidad <= umbral))
    |> Util2.ordenar(:asc, & &1.codigo)
  end

  @doc "Historial de movimientos de un recurso, del más antiguo al más reciente."
  def historial(inventario, codigo) do
    Enum.filter(inventario.movimientos, &(&1.codigo == codigo))
  end

  # ---------- Funciones recursivas ----------

  # Decide cuánto se toma de cada recurso para completar lo pedido.
  # Traza: tomar([R1(30), R2(100)], 40)
  #        = [{R1, 30} | tomar([R2(100)], 10)] = [{R1, 30}, {R2, 10}]

  # Caso base: ya no falta nada
  defp tomar(_recursos, 0), do: {:ok, []}

  # Caso base: faltan unidades pero ya no quedan recursos
  defp tomar([], _faltante), do: {:error, :inventario_insuficiente}

  # Caso recursivo: se toma lo que se pueda del primero y se sigue con el resto
  defp tomar([head | tail], faltante) do
    tomado = min(head.cantidad, faltante)

    with {:ok, resto} <- tomar(tail, faltante - tomado) do
      {:ok, [{head.codigo, tomado} | resto]}
    end
  end

  @doc """
  Convierte los registros de recursos del archivo en el mapa de recursos.
  Recursiva: arma el mapa con los que quedan y le agrega el primero.
  """
  # Caso base: sin registros, el mapa está vacío
  def recursos_desde_registros([]), do: {:ok, %{}}

  # Caso recursivo: se convierte el primer registro y luego el resto
  def recursos_desde_registros([head | tail]) do
    with {:ok, recurso} <- recurso_desde_campos(head),
         {:ok, resto} <- recursos_desde_registros(tail) do
      {:ok, Map.put(resto, recurso.codigo, recurso)}
    end
  end

  @doc "Convierte los registros de movimientos del archivo en la lista de movimientos."
  # Caso base: sin registros, la lista está vacía
  def movimientos_desde_registros([]), do: {:ok, []}

  # Caso recursivo: se convierte el primer registro y luego el resto
  def movimientos_desde_registros([head | tail]) do
    with {:ok, movimiento} <- movimiento_desde_campos(head),
         {:ok, resto} <- movimientos_desde_registros(tail) do
      {:ok, [movimiento | resto]}
    end
  end

  # ---------- Efectos: archivos ----------

  @doc "Carga el inventario guardado (vacío si es la primera vez)."
  def cargar do
    with {:ok, registros_recursos} <- Persistencia.cargar(@archivo_recursos),
         {:ok, recursos} <- recursos_desde_registros(registros_recursos),
         {:ok, registros_movimientos} <- Persistencia.cargar(@archivo_movimientos),
         {:ok, movimientos} <- movimientos_desde_registros(registros_movimientos) do
      {:ok, %{recursos: recursos, movimientos: movimientos}}
    end
  end

  @doc "Guarda el inventario (recursos y movimientos) en sus archivos."
  def guardar(inventario) do
    registros_recursos = inventario.recursos |> Map.values() |> Enum.map(&recurso_a_campos/1)
    registros_movimientos = Enum.map(inventario.movimientos, &movimiento_a_campos/1)

    with :ok <- Persistencia.guardar(@archivo_recursos, registros_recursos) do
      Persistencia.guardar(@archivo_movimientos, registros_movimientos)
    end
  end

  # ---------- El "cómo" ----------

  # Cambia la cantidad de un recurso (cambio positivo = entra, negativo = sale)
  # y deja el movimiento en el historial. Se usa SOLO después de validar.
  defp aplicar_cambio(inventario, codigo, cambio, tipo, detalle) do
    recurso = Map.fetch!(inventario.recursos, codigo)

    movimiento = %{
      numero: length(inventario.movimientos) + 1,
      codigo: codigo,
      tipo: tipo,
      cantidad: abs(cambio),
      detalle: detalle
    }

    %{
      inventario
      | recursos: Map.put(inventario.recursos, codigo, %{recurso | cantidad: recurso.cantidad + cambio}),
        movimientos: inventario.movimientos ++ [movimiento]
    }
  end

  # Por cada recurso: lo asignado a la necesidad menos lo que ya se liberó.
  # Traza: asignacion 30 de R001, liberacion 0 => [{"R001", 30}]
  defp por_liberar(inventario, id_necesidad) do
    inventario.movimientos
    |> Enum.filter(&(&1.detalle == id_necesidad and &1.tipo in ["asignacion", "liberacion"]))
    |> Enum.reduce(%{}, fn movimiento, acumulado ->
      cambio = if movimiento.tipo == "asignacion", do: movimiento.cantidad, else: -movimiento.cantidad
      Map.update(acumulado, movimiento.codigo, cambio, &(&1 + cambio))
    end)
    |> Enum.filter(fn {_codigo, cantidad} -> cantidad > 0 end)
    |> Enum.sort()
  end

  # Si el recurso del destino todavía no existe, lo crea con cantidad 0
  defp asegurar_recurso_destino(inventario, recurso, codigo_destino, destino) do
    if Map.has_key?(inventario.recursos, codigo_destino) do
      inventario
    else
      nuevo = %{recurso | codigo: codigo_destino, ubicacion: destino, cantidad: 0}
      %{inventario | recursos: Map.put(inventario.recursos, codigo_destino, nuevo)}
    end
  end

  # Recursos de la categoría con existencias: primero los de la zona
  # de la necesidad (false va antes que true) y luego por código.
  defp candidatos(inventario, categoria, zona) do
    inventario.recursos
    |> Map.values()
    |> Enum.filter(&(&1.categoria == categoria and &1.cantidad > 0))
    |> Util2.ordenar(:asc, &{&1.zona != zona, &1.codigo})
  end

  defp cumple_filtros?(recurso, filtros) do
    Enum.all?(filtros, fn {campo, valor} -> Map.get(recurso, campo) == valor end)
  end

  defp buscar(inventario, codigo) do
    case Map.fetch(inventario.recursos, codigo) do
      {:ok, recurso} -> {:ok, recurso}
      :error -> {:error, :recurso_inexistente}
    end
  end

  defp validar_codigo_nuevo(inventario, codigo) do
    if Map.has_key?(inventario.recursos, codigo), do: {:error, :codigo_existente}, else: :ok
  end

  defp validar_cantidad_inicial(cantidad) when is_integer(cantidad) and cantidad >= 0, do: :ok
  defp validar_cantidad_inicial(_cantidad), do: {:error, :cantidad_invalida}

  defp validar_cantidad_positiva(cantidad) when is_integer(cantidad) and cantidad > 0, do: :ok
  defp validar_cantidad_positiva(_cantidad), do: {:error, :cantidad_invalida}

  defp validar_hay_inventario(recurso, cantidad) do
    if cantidad <= recurso.cantidad, do: :ok, else: {:error, :inventario_insuficiente}
  end

  defp validar_origen(recurso, origen) do
    if recurso.ubicacion == origen, do: :ok, else: {:error, :origen_incorrecto}
  end

  defp validar_destino(origen, destino) do
    if origen == destino, do: {:error, :destino_igual_al_origen}, else: :ok
  end

  defp recurso_a_campos(recurso) do
    [
      recurso.codigo,
      recurso.nombre,
      recurso.categoria,
      Integer.to_string(recurso.cantidad),
      recurso.unidad,
      recurso.ubicacion,
      recurso.zona
    ]
  end

  defp recurso_desde_campos([codigo, nombre, categoria, cantidad, unidad, ubicacion, zona]) do
    with {:ok, cantidad} <- Persistencia.a_entero(cantidad) do
      {:ok,
       %{
         codigo: codigo,
         nombre: nombre,
         categoria: categoria,
         cantidad: cantidad,
         unidad: unidad,
         ubicacion: ubicacion,
         zona: zona
       }}
    end
  end

  defp recurso_desde_campos(_registro_corrupto), do: {:error, :registro_corrupto}

  defp movimiento_a_campos(movimiento) do
    [
      Integer.to_string(movimiento.numero),
      movimiento.codigo,
      movimiento.tipo,
      Integer.to_string(movimiento.cantidad),
      movimiento.detalle
    ]
  end

  defp movimiento_desde_campos([numero, codigo, tipo, cantidad, detalle]) do
    with {:ok, numero} <- Persistencia.a_entero(numero),
         {:ok, cantidad} <- Persistencia.a_entero(cantidad) do
      {:ok, %{numero: numero, codigo: codigo, tipo: tipo, cantidad: cantidad, detalle: detalle}}
    end
  end

  defp movimiento_desde_campos(_registro_corrupto), do: {:error, :registro_corrupto}
end
