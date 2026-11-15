# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Asignador do
  @moduledoc """
  Coordina los dos servidores que intervienen al asignar recursos:
  `ServidorNecesidades` y `ServidorRecursos`.

  Asignar recursos a una necesidad toca a los dos, y cada servidor solo
  garantiza su propio estado. Para que nunca queden inconsistentes, los
  pasos van en este orden:

  1. RESERVAR en la necesidad (`ServidorNecesidades.reservar`). Aquí se
     rechaza si la necesidad ya no está "pendiente" (atendida, cancelada o
     ya completa) o si se pide más de lo que falta. Así una necesidad no
     consume recursos dos veces.
  2. TOMAR los recursos (`ServidorRecursos.asignar`). Aquí se rechaza si no
     alcanza el inventario, y nunca se descuenta más de lo que hay.
  3. Si el paso 2 falla, se DESHACE la reserva del paso 1
     (`ServidorNecesidades.revertir`) y la necesidad queda como estaba.

  Cada paso es atómico porque cada servidor atiende un mensaje a la vez.
  """

  # ---------- El "qué" ----------

  @doc """
  Asigna `cantidad` unidades de la categoría a la necesidad (comando `assign_resource`).
  Devuelve `{:ok, tomas}` (lista de `{codigo_recurso, cantidad_tomada}`) o `{:error, motivo}`.

  ## Ejemplo
  iex> Asignador.asignar("N001", "agua", 30)
  {:ok, [{"R001", 30}]}
  """
  def asignar(id_necesidad, categoria, cantidad) do
    with {:ok, necesidad} <- ServidorNecesidades.obtener(id_necesidad),
         :ok <- validar_categoria(necesidad, categoria),
         {:ok, reservada} <- ServidorNecesidades.reservar(id_necesidad, cantidad) do
      tomar_recursos(reservada, categoria, cantidad)
    end
  end

  @doc """
  Cancela una necesidad y devuelve al inventario todo lo que tenía asignado.
  Si la necesidad ya estaba cerrada, no se devuelve nada (así no se
  devuelve dos veces).
  Devuelve `{:ok, devueltos}` o `{:error, motivo}`.
  """
  def cancelar_necesidad(id_necesidad) do
    with {:ok, _necesidad} <- ServidorNecesidades.cambiar_estado(id_necesidad, "cancelada") do
      ServidorRecursos.liberar_necesidad(id_necesidad)
    end
  end

  # ---------- El "cómo" ----------

  # Si los recursos no se pudieron tomar, se deshace la reserva de la necesidad
  defp tomar_recursos(necesidad, categoria, cantidad) do
    case ServidorRecursos.asignar(categoria, cantidad, necesidad.id, necesidad.zona) do
      {:ok, tomas} ->
        {:ok, tomas}

      {:error, motivo} ->
        ServidorNecesidades.revertir(necesidad.id, cantidad)
        {:error, motivo}
    end
  end

  # El tipo de la necesidad debe coincidir con la categoría del recurso
  # (agua con agua), salvo las necesidades de tipo "otra".
  defp validar_categoria(%{tipo: tipo}, categoria) when tipo == categoria or tipo == "otra", do: :ok
  defp validar_categoria(_necesidad, _categoria), do: {:error, :categoria_no_coincide}
end
