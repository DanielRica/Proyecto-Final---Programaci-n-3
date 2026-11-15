# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Antes de correr: compilar Util2 una vez, dentro de esta carpeta:  elixirc util2.ex
Code.require_file("cargar_procesos.exs", __DIR__)

defmodule Demo6Supervision do
  @carpeta_datos Path.join(__DIR__, "datos")

  # ---------- El "qué" ----------
  def main do
    Util2.mostrar("=== DEMO MANDADA 6: SUPERVISORES ===", :mensaje)

    File.rm_rf(@carpeta_datos)
    {:ok, _pid} = SupervisorPrincipal.start_link()

    mostrar_arbol()
    probar_sesiones()
    probar_otros_servidores()
    probar_caida_de_recursos()
    probar_caida_de_usuarios()

    File.rm_rf(@carpeta_datos)
  end

  # ---------- Árbol de procesos ----------
  defp mostrar_arbol do
    titulo("1. Árbol de procesos")

    hijos = Supervisor.which_children(SupervisorPrincipal)
    Util2.mostrar("SupervisorPrincipal tiene #{length(hijos)} hijos:", :mensaje)

    hijos
    |> Enum.reverse()
    |> Util2.convertir_coleccion_mensaje(fn {id, pid, _tipo, _modulos} -> "  #{inspect(id)} #{inspect(pid)}" end)
    |> Enum.each(&Util2.mostrar(&1, :mensaje))

    verificar("los 9 hijos están vivos", length(hijos) == 9 and Enum.all?(hijos, fn {_, pid, _, _} -> is_pid(pid) end))
  end

  # ---------- Sesiones con DynamicSupervisor ----------
  defp probar_sesiones do
    titulo("2. Sesiones: un proceso por usuario conectado (DynamicSupervisor)")

    Util2.mostrar("Sesiones al inicio: #{contar_sesiones()}", :mensaje)

    {:ok, %{como: como_laura}} = ServidorUsuarios.conectar("laura", "1234", "coordinador", "centro")
    {:ok, %{como: como_andres}} = ServidorUsuarios.conectar("andres", "abc", "ciudadano", "norte")
    Util2.mostrar("laura: #{como_laura}. andres: #{como_andres}.", :mensaje)
    verificar("hay 2 sesiones (una por usuario)", contar_sesiones() == 2)

    ServidorUsuarios.conectar("laura", "1234", "coordinador", "centro")
    verificar("conectarse otra vez NO crea una sesión nueva", contar_sesiones() == 2)

    Util2.mostrar("Contraseña incorrecta: #{inspect(ServidorUsuarios.conectar("laura", "mala", "x", "y"))}", :mensaje)

    ServidorUsuarios.registrar_actividad("laura", "register_need agua 30 critica centro")
    ServidorUsuarios.registrar_actividad("laura", "summary")
    {:ok, info} = ServidorUsuarios.informacion_sesion("laura")
    # 2 conexiones + 2 acciones = 4
    verificar("la sesión de laura cuenta sus acciones (#{info.acciones})", info.acciones == 4)

    Util2.mostrar("Conectados: #{inspect(ServidorUsuarios.conectados())}", :mensaje)
    Util2.mostrar("Datos de laura (sin contraseña): #{inspect(ServidorUsuarios.sesion("laura"))}", :mensaje)

    :ok = ServidorUsuarios.desconectar("andres")
    verificar("al desconectar a andres queda 1 sesión", contar_sesiones() == 1)
    Util2.mostrar("andres actúa sin conexión: #{inspect(ServidorUsuarios.registrar_actividad("andres", "summary"))}", :mensaje)
    Util2.mostrar("desconectar otra vez: #{inspect(ServidorUsuarios.desconectar("andres"))}", :mensaje)

    {:ok, registros} = ServidorUsuarios.actividad("laura")
    verificar("la actividad de laura quedó en el archivo (#{length(registros)} líneas)", length(registros) == 4)
  end

  # ---------- Los otros cuatro servidores ----------
  defp probar_otros_servidores do
    titulo("3. Zonas, personas, mensajes y mascotas funcionando como procesos")

    :ok = ServidorZonas.registrar_zona("centro", "Centro", "critico", 100)
    :ok = ServidorZonas.agregar_sector("centro", "s1", "Sector 1", "alto", 50)
    :ok = ServidorZonas.agregar_punto("centro", "s1", "p1", "Punto 1", "bajo", 10)
    {:ok, estado} = ServidorZonas.estado_zona("centro")
    verificar("zona centro: #{estado.personas_afectadas} personas, #{estado.sectores} sector, #{estado.puntos_atencion} punto", estado.personas_afectadas == 160)

    {:ok, _} = ServidorPersonas.registrar("111", "Andrés", "norte", "localizada")
    {:ok, _} = ServidorPersonas.cambiar_estado("111", "en_albergue")
    {:ok, historial} = ServidorPersonas.historial("111")
    verificar("historial de Andrés: #{Enum.join(historial, " -> ")}", historial == ["localizada", "en_albergue"])

    {:ok, _} = ServidorMensajes.enviar("laura", "111", "Estoy bien, estoy en el albergue norte")
    verificar("mensaje para 111 pendiente", length(ServidorMensajes.listar_para("111", "pendiente")) == 1)

    {:ok, _} = ServidorMascotas.registrar("perdida", "perro", "Luna", "negra", "mediana", "norte", "300", "collar rojo")
    {:ok, _} = ServidorMascotas.registrar("encontrada", "perro", "desconocido", "negra", "mediana", "norte", "311", "collar rojo")
    {:ok, coincidencias} = ServidorMascotas.marcar_posibles()
    verificar("match_pets encontró 1 coincidencia (#{Enum.map_join(coincidencias, ", ", & &1.puntaje)} puntos)", length(coincidencias) == 1)
  end

  # ---------- Caída de un servidor ----------
  defp probar_caida_de_recursos do
    titulo("4. Se cae ServidorRecursos: el supervisor lo reinicia y recupera su inventario")

    {:ok, _} = ServidorRecursos.registrar("R001", "agua", "agua", 50, "litros", "centro_acopio_1", "centro")
    pid_recursos = Process.whereis(ServidorRecursos)
    pid_necesidades = Process.whereis(ServidorNecesidades)
    antes = ServidorRecursos.consultar()

    Util2.mostrar("Matando a ServidorRecursos #{inspect(pid_recursos)} con Process.exit(pid, :kill)...", :mensaje)
    Process.exit(pid_recursos, :kill)

    pid_nuevo = esperar_reinicio(ServidorRecursos, pid_recursos, 40)
    Util2.mostrar("Nuevo ServidorRecursos: #{inspect(pid_nuevo)}", :mensaje)

    verificar("el supervisor lo reinició con otro pid", is_pid(pid_nuevo) and pid_nuevo != pid_recursos)
    verificar("el inventario se recuperó del archivo", ServidorRecursos.consultar() == antes)
    verificar("ServidorNecesidades NO se reinició (one_for_one)", Process.whereis(ServidorNecesidades) == pid_necesidades)
  end

  defp probar_caida_de_usuarios do
    titulo("5. Se cae ServidorUsuarios: se conservan los usuarios, se pierden las sesiones")

    pid_usuarios = Process.whereis(ServidorUsuarios)
    Util2.mostrar("Sesiones antes: #{contar_sesiones()}", :mensaje)
    Process.exit(pid_usuarios, :kill)
    pid_nuevo = esperar_reinicio(ServidorUsuarios, pid_usuarios, 40)

    verificar("ServidorUsuarios se reinició", is_pid(pid_nuevo) and pid_nuevo != pid_usuarios)
    verificar("las sesiones huérfanas se cerraron (quedan #{contar_sesiones()})", contar_sesiones() == 0)
    verificar("laura ya no figura como conectada", ServidorUsuarios.sesion("laura") == {:error, :no_conectado})

    {:ok, %{como: como}} = ServidorUsuarios.conectar("laura", "1234", "coordinador", "centro")
    verificar("laura se conecta de nuevo y se reconoce (#{como}, no se vuelve a registrar)", como == :autenticado)
  end

  # ---------- El "cómo" ----------

  defp contar_sesiones, do: DynamicSupervisor.count_children(SupervisorSesiones).active

  # Espera a que el supervisor registre un proceso NUEVO con ese nombre.

  # Caso base: se acabaron los intentos
  defp esperar_reinicio(_nombre, _pid_viejo, 0), do: nil

  # Caso recursivo: si todavía es el mismo (o no existe), espera un poco y vuelve a mirar
  defp esperar_reinicio(nombre, pid_viejo, intentos) do
    case Process.whereis(nombre) do
      pid when is_pid(pid) and pid != pid_viejo ->
        pid

      _otro ->
        Process.sleep(50)
        esperar_reinicio(nombre, pid_viejo, intentos - 1)
    end
  end

  defp titulo(texto), do: Util2.mostrar("\n--- #{texto} ---", :mensaje)

  defp verificar(descripcion, true), do: Util2.mostrar("  [OK]    #{descripcion}", :mensaje)
  defp verificar(descripcion, false), do: Util2.mostrar("  [FALLO] #{descripcion}", :error)
end

Demo6Supervision.main()
