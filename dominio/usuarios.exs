# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

defmodule Usuarios do
  @moduledoc """
  Gestión de usuarios: registro, autenticación, conexión y actividad.

  Los usuarios se guardan en un mapa: la llave es el nombre de usuario
  y el valor es otro mapa con los datos del usuario.

      %{"laura" => %{nombre_usuario: "laura", clave: "...", nombre_completo: "laura",
                     tipo: "coordinador", zona: "centro"}}

  La contraseña nunca se guarda tal cual: se guarda su huella (SHA-256).
  """

  @tipos_validos ["ciudadano", "voluntario", "coordinador", "administrador"]
  @archivo_usuarios "usuarios.txt"
  @archivo_actividad "actividad.txt"

  # ---------- El "qué" (funciones puras) ----------

  @doc "Devuelve los tipos de usuario permitidos."
  def tipos_validos, do: @tipos_validos

  @doc """
  Registra un usuario nuevo. Devuelve `{:ok, usuarios}` con el mapa actualizado
  o `{:error, motivo}` si algún dato no es válido.

  ## Ejemplo
  iex> Usuarios.registrar(%{}, "laura", "1234", "Laura Gómez", "coordinador", "centro")
  {:ok, %{"laura" => %{...}}}
  """
  def registrar(usuarios, nombre_usuario, contrasena, nombre_completo, tipo, zona) do
    campos = [nombre_usuario, contrasena, nombre_completo, tipo, zona]

    with :ok <- Persistencia.validar_campos(campos),
         :ok <- validar_tipo(tipo),
         :ok <- validar_no_existe(usuarios, nombre_usuario) do
      usuario = %{
        nombre_usuario: nombre_usuario,
        clave: cifrar(contrasena),
        nombre_completo: nombre_completo,
        tipo: tipo,
        zona: zona
      }

      {:ok, Map.put(usuarios, nombre_usuario, usuario)}
    end
  end

  @doc """
  Valida las credenciales de un usuario que ya existe.

  ## Ejemplos
  iex> Usuarios.autenticar(usuarios, "laura", "1234")
  {:ok, %{nombre_usuario: "laura", ...}}
  iex> Usuarios.autenticar(usuarios, "laura", "9999")
  {:error, :contrasena_incorrecta}
  """
  def autenticar(usuarios, nombre_usuario, contrasena) do
    case Map.fetch(usuarios, nombre_usuario) do
      :error ->
        {:error, :usuario_inexistente}

      {:ok, usuario} ->
        if usuario.clave == cifrar(contrasena) do
          {:ok, usuario}
        else
          {:error, :contrasena_incorrecta}
        end
    end
  end

  @doc """
  Comando `connect usuario contraseña tipo zona`.

  - Si el usuario NO existe, se registra automáticamente (con su nombre de
    usuario como nombre completo, porque el comando no trae otro).
  - Si ya existe, solo se valida la contraseña (el tipo y la zona del comando
    se ignoran: valen los que ya estaban guardados).

  Devuelve `{:ok, usuarios, usuario, :registrado | :autenticado}` o `{:error, motivo}`.
  """
  def conectar(usuarios, nombre_usuario, contrasena, tipo, zona) do
    case Map.has_key?(usuarios, nombre_usuario) do
      false -> conectar_nuevo(usuarios, nombre_usuario, contrasena, tipo, zona)
      true -> conectar_existente(usuarios, nombre_usuario, contrasena)
    end
  end

  # ---------- Conversión a texto plano (puras) ----------

  @doc "Convierte todos los usuarios en registros (listas de campos) para guardarlos."
  def a_registros(usuarios) do
    usuarios
    |> Map.values()
    |> Enum.map(&a_campos/1)
  end

  @doc """
  Convierte los registros leídos del archivo en el mapa de usuarios.
  Es recursiva: arma el mapa de los usuarios que quedan y le agrega el primero.

  ## Ejemplo
  iex> Usuarios.desde_registros([["laura", "huella", "Laura", "coordinador", "centro"]])
  {:ok, %{"laura" => %{...}}}
  """
  # Caso base: sin registros, el mapa está vacío
  def desde_registros([]), do: {:ok, %{}}

  # Caso recursivo: se convierte el primer registro y luego el resto
  def desde_registros([head | tail]) do
    with {:ok, usuario} <- desde_campos(head),
         {:ok, resto} <- desde_registros(tail) do
      {:ok, Map.put(resto, usuario.nombre_usuario, usuario)}
    end
  end

  # ---------- Efectos: archivos ----------

  @doc "Carga los usuarios guardados en el archivo (mapa vacío si es la primera vez)."
  def cargar do
    with {:ok, registros} <- Persistencia.cargar(@archivo_usuarios) do
      desde_registros(registros)
    end
  end

  @doc "Guarda todos los usuarios en el archivo."
  def guardar(usuarios) do
    Persistencia.guardar(@archivo_usuarios, a_registros(usuarios))
  end

  @doc "Agrega una línea al historial de actividad: fecha;usuario;acción."
  def registrar_actividad(nombre_usuario, accion) do
    fecha = DateTime.utc_now() |> DateTime.to_iso8601()
    registro = [fecha, nombre_usuario, accion]

    with :ok <- Persistencia.validar_campos(registro) do
      Persistencia.agregar(@archivo_actividad, registro)
    end
  end

  @doc "Devuelve la actividad de un usuario como `{:ok, lista_de_registros}`."
  def consultar_actividad(nombre_usuario) do
    with {:ok, registros} <- Persistencia.cargar(@archivo_actividad) do
      {:ok, Enum.filter(registros, fn [_fecha, usuario, _accion] -> usuario == nombre_usuario end)}
    end
  end

  # ---------- El "cómo" ----------

  defp conectar_nuevo(usuarios, nombre_usuario, contrasena, tipo, zona) do
    with {:ok, nuevos_usuarios} <-
           registrar(usuarios, nombre_usuario, contrasena, nombre_usuario, tipo, zona) do
      {:ok, nuevos_usuarios, Map.fetch!(nuevos_usuarios, nombre_usuario), :registrado}
    end
  end

  defp conectar_existente(usuarios, nombre_usuario, contrasena) do
    with {:ok, usuario} <- autenticar(usuarios, nombre_usuario, contrasena) do
      {:ok, usuarios, usuario, :autenticado}
    end
  end

  defp validar_tipo(tipo) when tipo in @tipos_validos, do: :ok
  defp validar_tipo(_tipo), do: {:error, :tipo_invalido}

  defp validar_no_existe(usuarios, nombre_usuario) do
    if Map.has_key?(usuarios, nombre_usuario) do
      {:error, :usuario_existente}
    else
      :ok
    end
  end

  # "1234" => "03AC674216F3E15C..." (siempre da lo mismo para la misma contraseña)
  defp cifrar(contrasena) do
    :crypto.hash(:sha256, contrasena)
    |> Base.encode16()
  end

  defp a_campos(usuario) do
    [usuario.nombre_usuario, usuario.clave, usuario.nombre_completo, usuario.tipo, usuario.zona]
  end

  defp desde_campos([nombre_usuario, clave, nombre_completo, tipo, zona]) do
    {:ok,
     %{
       nombre_usuario: nombre_usuario,
       clave: clave,
       nombre_completo: nombre_completo,
       tipo: tipo,
       zona: zona
     }}
  end

  defp desde_campos(_registro_corrupto), do: {:error, :registro_corrupto}
end
