# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Mensajes do
  @moduledoc """
  Mensajes que dejan los familiares dirigidos a una persona (o a su familia).

  Los mensajes se guardan en un mapa: la llave es el identificador ("MSG001").

      %{id: "MSG001", fecha: "2026-11-09T15:30:00Z", remitente: "laura",
        destinatario: "111", contenido: "Estoy bien, estoy en el albergue norte",
        estado: "pendiente"}

  El destinatario es el documento de la persona. Este módulo no comprueba que
  la persona exista (no conoce a las personas): lo verificará el servidor.
  """

  @estados ["pendiente", "entregado"]
  @archivo_mensajes "mensajes.txt"

  # ---------- El "qué" (funciones puras) ----------

  @doc """
  Registra un mensaje nuevo (comando `send_family_message`), con estado "pendiente".
  La fecha se recibe como parámetro (use `fecha_actual/0`) para que esta
  función siga siendo pura.
  Devuelve `{:ok, mensajes, mensaje}` o `{:error, motivo}`.

  ## Ejemplo
  iex> Mensajes.enviar(%{}, "2026-11-09T15:30:00Z", "laura", "111", "Estoy bien")
  {:ok, %{"MSG001" => %{...}}, %{id: "MSG001", estado: "pendiente", ...}}
  """
  def enviar(mensajes, fecha, remitente, destinatario, contenido) do
    with :ok <- Persistencia.validar_campos([fecha, remitente, destinatario, contenido]) do
      id = siguiente_id(mensajes)

      mensaje = %{
        id: id,
        fecha: fecha,
        remitente: remitente,
        destinatario: destinatario,
        contenido: contenido,
        estado: "pendiente"
      }

      {:ok, Map.put(mensajes, id, mensaje), mensaje}
    end
  end

  @doc "Marca un mensaje como entregado."
  def marcar_entregado(mensajes, id), do: cambiar_estado(mensajes, id, "entregado")

  @doc "Marca un mensaje como pendiente."
  def marcar_pendiente(mensajes, id), do: cambiar_estado(mensajes, id, "pendiente")

  @doc """
  Mensajes dirigidos a un destinatario (comando `list_family_messages`),
  del más antiguo al más reciente. Con `estado` se filtran por "pendiente"
  o "entregado".
  """
  def listar_para(mensajes, destinatario, estado \\ nil) do
    mensajes
    |> Map.values()
    |> Enum.filter(&(&1.destinatario == destinatario))
    |> Enum.filter(&(estado == nil or &1.estado == estado))
    |> Util2.ordenar(:asc, & &1.id)
  end

  @doc "Todos los mensajes, del más antiguo al más reciente."
  def todos(mensajes) do
    mensajes
    |> Map.values()
    |> Util2.ordenar(:asc, & &1.id)
  end

  @doc "Fecha y hora actuales en formato de texto (efecto: depende del reloj)."
  def fecha_actual do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  # ---------- Conversión a texto plano (puras) ----------

  @doc "Convierte todos los mensajes en registros para guardarlos."
  def a_registros(mensajes) do
    mensajes
    |> Map.values()
    |> Enum.map(&a_campos/1)
  end

  @doc """
  Convierte los registros del archivo en el mapa de mensajes.
  Recursiva: arma el mapa con los mensajes que quedan y le agrega el primero.
  """
  # Caso base: sin registros, el mapa está vacío
  def desde_registros([]), do: {:ok, %{}}

  # Caso recursivo: se convierte el primer registro y luego el resto
  def desde_registros([head | tail]) do
    with {:ok, mensaje} <- desde_campos(head),
         {:ok, resto} <- desde_registros(tail) do
      {:ok, Map.put(resto, mensaje.id, mensaje)}
    end
  end

  # ---------- Efectos: archivos ----------

  @doc "Carga los mensajes guardados (mapa vacío si es la primera vez)."
  def cargar do
    with {:ok, registros} <- Persistencia.cargar(@archivo_mensajes) do
      desde_registros(registros)
    end
  end

  @doc "Guarda todos los mensajes en el archivo."
  def guardar(mensajes) do
    Persistencia.guardar(@archivo_mensajes, a_registros(mensajes))
  end

  # ---------- El "cómo" ----------

  # 0 mensajes => "MSG001", 1 => "MSG002", ... (nunca se borran)
  defp siguiente_id(mensajes) do
    numero = map_size(mensajes) + 1
    "MSG" <> String.pad_leading(Integer.to_string(numero), 3, "0")
  end

  defp cambiar_estado(mensajes, id, nuevo_estado) do
    with {:ok, mensaje} <- buscar(mensajes, id),
         :ok <- validar_estado(nuevo_estado),
         :ok <- validar_cambio(mensaje, nuevo_estado) do
      actualizado = %{mensaje | estado: nuevo_estado}
      {:ok, Map.put(mensajes, id, actualizado), actualizado}
    end
  end

  defp buscar(mensajes, id) do
    case Map.fetch(mensajes, id) do
      {:ok, mensaje} -> {:ok, mensaje}
      :error -> {:error, :mensaje_inexistente}
    end
  end

  defp validar_estado(estado) when estado in @estados, do: :ok
  defp validar_estado(_estado), do: {:error, :estado_invalido}

  defp validar_cambio(mensaje, nuevo_estado) do
    if mensaje.estado == nuevo_estado, do: {:error, :sin_cambios}, else: :ok
  end

  defp a_campos(mensaje) do
    [mensaje.id, mensaje.fecha, mensaje.remitente, mensaje.destinatario, mensaje.contenido, mensaje.estado]
  end

  defp desde_campos([id, fecha, remitente, destinatario, contenido, estado]) do
    {:ok,
     %{
       id: id,
       fecha: fecha,
       remitente: remitente,
       destinatario: destinatario,
       contenido: contenido,
       estado: estado
     }}
  end

  defp desde_campos(_registro_corrupto), do: {:error, :registro_corrupto}
end
