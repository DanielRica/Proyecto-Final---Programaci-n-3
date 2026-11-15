# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Persistencia do
  @moduledoc """
  Guarda y carga la información del sistema en archivos de texto plano.

  Formato: un archivo por entidad, una línea por registro y los campos
  separados por `;`. Todos los archivos quedan en la carpeta `datos/`,
  al lado de este archivo, para que funcione desde cualquier carpeta.

  Si existe la variable de entorno `DATOS_DIR`, se usa esa carpeta en lugar
  de `datos/`. Las pruebas la usan para no tocar los datos reales.
  """

  @separador ";"
  @carpeta_por_defecto Path.join(__DIR__, "datos")

  # ---------- El "qué" ----------

  @doc """
  Reescribe un archivo completo con la lista de registros dada.
  Cada registro es una lista de textos (los campos).

  ## Ejemplo
  iex> Persistencia.guardar("prueba.txt", [["a", "b"], ["c", "d"]])
  :ok
  """
  def guardar(nombre_archivo, registros) do
    contenido = Enum.map_join(registros, &(a_linea(&1) <> "\n"))

    with :ok <- File.mkdir_p(carpeta_datos()) do
      File.write(ruta(nombre_archivo), contenido)
    end
  end

  @doc """
  Agrega un registro al final de un archivo (sin borrar lo anterior).
  """
  def agregar(nombre_archivo, registro) do
    with :ok <- File.mkdir_p(carpeta_datos()) do
      File.write(ruta(nombre_archivo), a_linea(registro) <> "\n", [:append])
    end
  end

  @doc """
  Carga los registros de un archivo. Si el archivo todavía no existe,
  devuelve una lista vacía (es la primera vez que se ejecuta el sistema).

  ## Ejemplo
  iex> Persistencia.cargar("prueba.txt")
  {:ok, [["a", "b"], ["c", "d"]]}
  """
  def cargar(nombre_archivo) do
    case File.read(ruta(nombre_archivo)) do
      {:ok, contenido} -> {:ok, a_registros(contenido)}
      {:error, :enoent} -> {:ok, []}
      {:error, razon} -> {:error, razon}
    end
  end

  @doc """
  Revisa que ningún campo esté vacío ni contenga el separador `;` o saltos
  de línea, porque romperían el formato del archivo.

  ## Ejemplos
  iex> Persistencia.validar_campos(["laura", "1234"])
  :ok
  iex> Persistencia.validar_campos(["laura", ""])
  {:error, :campo_vacio}
  iex> Persistencia.validar_campos(["la;ura"])
  {:error, :caracter_invalido}
  """
  # Caso base: no quedan campos por revisar
  def validar_campos([]), do: :ok

  # Caso recursivo: se revisa el primer campo y luego el resto
  def validar_campos([head | tail]) do
    cond do
      String.trim(head) == "" -> {:error, :campo_vacio}
      String.contains?(head, [@separador, "\n", "\r"]) -> {:error, :caracter_invalido}
      true -> validar_campos(tail)
    end
  end

  @doc """
  Convierte un texto en número entero. Se usa al leer los archivos, donde
  todo viene como texto.

  ## Ejemplos
  iex> Persistencia.a_entero("30")
  {:ok, 30}
  iex> Persistencia.a_entero("treinta")
  {:error, :numero_invalido}
  """
  def a_entero(texto) do
    case Integer.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> {:error, :numero_invalido}
    end
  end

  # ---------- El "cómo" ----------

  # Se calcula cada vez que se necesita, para que DATOS_DIR pueda cambiar mientras corre el programa
  defp carpeta_datos, do: System.get_env("DATOS_DIR") || @carpeta_por_defecto

  defp ruta(nombre_archivo), do: Path.join(carpeta_datos(), nombre_archivo)

  # ["a", "b"] => "a;b"
  defp a_linea(registro), do: Enum.join(registro, @separador)

  # "a;b\nc;d\n" => [["a", "b"], ["c", "d"]]
  # Se aceptan saltos de línea de Linux ("\n") y de Windows ("\r\n").
  defp a_registros(contenido) do
    contenido
    |> String.split(["\r\n", "\n"], trim: true)
    |> Enum.map(&String.split(&1, @separador))
  end
end
