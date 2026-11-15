# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Pruebas de los procesos (GenServer, supervisores), la concurrencia y el flujo
# completo de comandos. No se ejecuta solo: lo carga `pruebas.exs`.

defmodule PruebasProcesos do
  use ExUnit.Case

  # Antes de CADA prueba: carpeta de datos nueva y todo el sistema recién iniciado.
  # `start_supervised!` arranca el supervisor y ExUnit lo detiene al terminar la prueba.
  setup do
    carpeta = Path.join(System.tmp_dir!(), "emergencias_procesos_#{System.unique_integer([:positive])}")
    System.put_env("DATOS_DIR", carpeta)
    start_supervised!(SupervisorPrincipal)

    on_exit(fn ->
      System.delete_env("DATOS_DIR")
      File.rm_rf(carpeta)
    end)

    :ok
  end

  # ---------- Ayudas ----------

  # Ejecuta todas las funciones AL MISMO TIEMPO (un proceso por función) y
  # devuelve sus resultados (en el orden en que terminen).
  defp en_paralelo(funciones) do
    padre = self()
    Enum.each(funciones, fn funcion -> spawn(fn -> send(padre, {:resultado, funcion.()}) end) end)
    recoger(length(funciones))
  end

  # Caso base: no faltan resultados
  defp recoger(0), do: []

  # Caso recursivo: recibe un resultado y espera los que faltan
  defp recoger(faltan) do
    receive do
      {:resultado, resultado} -> [resultado | recoger(faltan - 1)]
    after
      5_000 -> flunk("un proceso no respondió a tiempo")
    end
  end

  defp exitos(resultados), do: Enum.count(resultados, &match?({:ok, _}, &1))

  # Escribe un comando como lo haría un cliente y lo ejecuta en el servicio
  defp comando(usuario, linea) do
    [nombre | argumentos] = OptionParser.split(linea)
    Servicio.ejecutar({usuario, nombre, argumentos})
  end

  # Espera a que el supervisor registre un proceso NUEVO con ese nombre.
  # Caso base: se acabaron los intentos
  defp esperar_reinicio(_nombre, _pid_viejo, 0), do: nil

  # Caso recursivo: si todavía es el mismo (o no existe), espera y vuelve a mirar
  defp esperar_reinicio(nombre, pid_viejo, intentos) do
    case Process.whereis(nombre) do
      pid when is_pid(pid) and pid != pid_viejo ->
        pid

      _otro ->
        Process.sleep(50)
        esperar_reinicio(nombre, pid_viejo, intentos - 1)
    end
  end

  # ---------- Concurrencia: el conflicto obligatorio ----------

  describe "Conflicto concurrente de recursos" do
    test "30 y 25 litros al mismo tiempo sobre 50 litros: solo se confirma una asignación" do
      {:ok, _} = ServidorRecursos.registrar("R001", "agua", "agua", 50, "litros", "acopio_1", "centro")
      {:ok, n1} = ServidorNecesidades.registrar("agua", 30, "critica", "centro", "Punto sector 3", "laura")
      {:ok, n2} = ServidorNecesidades.registrar("agua", 25, "critica", "centro", "Albergue", "pedro")

      resultados =
        en_paralelo([
          fn -> Asignador.asignar(n1.id, "agua", 30) end,
          fn -> Asignador.asignar(n2.id, "agua", 25) end
        ])

      assert exitos(resultados) == 1
      assert Enum.any?(resultados, &(&1 == {:error, :inventario_insuficiente}))

      disponible = ServidorRecursos.disponible_total(%{categoria: "agua"})
      assert disponible in [20, 25]
      assert 50 - disponible <= 50
    end

    test "la necesidad que no obtuvo recursos queda pendiente y sin nada asignado" do
      {:ok, _} = ServidorRecursos.registrar("R001", "agua", "agua", 50, "litros", "acopio_1", "centro")
      {:ok, n1} = ServidorNecesidades.registrar("agua", 30, "critica", "centro", "a", "laura")
      {:ok, n2} = ServidorNecesidades.registrar("agua", 25, "critica", "centro", "b", "pedro")

      _resultados =
        en_paralelo([
          fn -> Asignador.asignar(n1.id, "agua", 30) end,
          fn -> Asignador.asignar(n2.id, "agua", 25) end
        ])

      necesidades = ServidorNecesidades.consultar()
      asignadas = Enum.filter(necesidades, &(&1.estado == "asignada"))
      pendientes = Enum.filter(necesidades, &(&1.estado == "pendiente"))

      assert length(asignadas) == 1
      assert [%{cantidad_asignada: 0}] = pendientes
    end

    test "veinte pedidos de 10 contra 50 unidades: se aceptan exactamente 5 y el inventario queda en 0" do
      {:ok, _} = ServidorRecursos.registrar("R010", "arroz", "alimentos", 50, "kg", "acopio_1", "centro")

      ids =
        Enum.map(1..20, fn numero ->
          {:ok, necesidad} = ServidorNecesidades.registrar("alimentos", 10, "media", "centro", "Familia #{numero}", "laura")
          necesidad.id
        end)

      resultados = en_paralelo(Enum.map(ids, fn id -> fn -> Asignador.asignar(id, "alimentos", 10) end end))

      assert exitos(resultados) == 5
      assert ServidorRecursos.disponible_total(%{categoria: "alimentos"}) == 0

      todas = ServidorNecesidades.consultar(%{tipo: "alimentos"})
      assert Enum.count(todas, &(&1.estado == "asignada")) == 5
      assert Enum.count(todas, &(&1.estado == "pendiente" and &1.cantidad_asignada == 0)) == 15
    end

    test "cinco pedidos simultáneos para la misma necesidad: solo uno consume recursos" do
      {:ok, _} = ServidorRecursos.registrar("R020", "suero", "medicamentos", 100, "unidades", "acopio_2", "norte")
      {:ok, necesidad} = ServidorNecesidades.registrar("medicamentos", 10, "alta", "norte", "Clínica", "laura")

      resultados = en_paralelo(List.duplicate(fn -> Asignador.asignar(necesidad.id, "medicamentos", 10) end, 5))

      assert exitos(resultados) == 1
      assert ServidorRecursos.disponible_total(%{categoria: "medicamentos"}) == 90
    end

    test "una necesidad cancelada no vuelve a consumir recursos" do
      {:ok, _} = ServidorRecursos.registrar("R001", "agua", "agua", 50, "litros", "acopio_1", "centro")
      {:ok, necesidad} = ServidorNecesidades.registrar("agua", 10, "alta", "centro", "x", "laura")

      assert {:ok, _devueltos} = Asignador.cancelar_necesidad(necesidad.id)
      assert {:error, :estado_no_admite_asignacion} = Asignador.asignar(necesidad.id, "agua", 10)
      assert ServidorRecursos.disponible_total(%{categoria: "agua"}) == 50
    end

    test "cancelar una necesidad devuelve sus recursos una sola vez" do
      {:ok, _} = ServidorRecursos.registrar("R001", "agua", "agua", 50, "litros", "acopio_1", "centro")
      {:ok, necesidad} = ServidorNecesidades.registrar("agua", 30, "critica", "centro", "x", "laura")
      {:ok, _tomas} = Asignador.asignar(necesidad.id, "agua", 30)
      assert ServidorRecursos.disponible_total(%{categoria: "agua"}) == 20

      assert {:ok, [{"R001", 30}]} = Asignador.cancelar_necesidad(necesidad.id)
      assert ServidorRecursos.disponible_total(%{categoria: "agua"}) == 50

      assert {:error, :necesidad_cerrada} = Asignador.cancelar_necesidad(necesidad.id)
      assert ServidorRecursos.disponible_total(%{categoria: "agua"}) == 50
    end

    test "el tipo de la necesidad debe coincidir con la categoría del recurso" do
      {:ok, _} = ServidorRecursos.registrar("R001", "agua", "agua", 50, "litros", "acopio_1", "centro")
      {:ok, necesidad} = ServidorNecesidades.registrar("rescate", 2, "critica", "centro", "x", "laura")

      assert {:error, :categoria_no_coincide} = Asignador.asignar(necesidad.id, "agua", 2)
      assert ServidorRecursos.disponible_total(%{categoria: "agua"}) == 50
    end
  end

  describe "Otros conflictos concurrentes" do
    test "diez personas piden entrar a la vez a un albergue de 3 cupos: entran exactamente 3" do
      {:ok, _} = ServidorAlbergues.registrar("A01", "Norte", "norte", 3)

      resultados = en_paralelo(Enum.map(1..10, fn n -> fn -> ServidorAlbergues.registrar_ingreso("A01", "doc#{n}") end end))

      assert exitos(resultados) == 3
      assert {:ok, %{ocupacion: 3, cupos: 0}} = ServidorAlbergues.consultar_cupos("A01")
    end

    test "la misma persona intenta entrar a dos albergues a la vez: queda en uno solo" do
      {:ok, _} = ServidorAlbergues.registrar("A01", "Norte", "norte", 5)
      {:ok, _} = ServidorAlbergues.registrar("A02", "Sur", "sur", 5)

      resultados =
        en_paralelo([
          fn -> ServidorAlbergues.registrar_ingreso("A01", "111") end,
          fn -> ServidorAlbergues.registrar_ingreso("A02", "111") end
        ])

      assert exitos(resultados) == 1
    end

    test "dos usuarios confirman a la vez la misma coincidencia de mascotas: un reporte no se cierra dos veces" do
      {:ok, _} = ServidorMascotas.registrar("perdida", "perro", "Luna", "negra", "mediana", "norte", "300")
      {:ok, _} = ServidorMascotas.registrar("encontrada", "perro", "desconocido", "negra", "mediana", "norte", "311")

      resultados =
        en_paralelo([
          fn -> ServidorMascotas.confirmar_coincidencia("PET001", "PET002") end,
          fn -> ServidorMascotas.confirmar_coincidencia("PET001", "PET002") end
        ])

      assert exitos(resultados) == 1
      assert Enum.any?(resultados, &(&1 == {:error, :reporte_ya_resuelto}))
    end

    test "dos personas se registran a la vez con el mismo documento: solo se acepta una" do
      resultados =
        en_paralelo([
          fn -> ServidorPersonas.registrar("111", "Andrés", "norte", "localizada") end,
          fn -> ServidorPersonas.registrar("111", "Otro Andrés", "sur", "reportada") end
        ])

      assert exitos(resultados) == 1
      assert length(ServidorPersonas.buscar()) == 1
    end

    test "cien necesidades registradas a la vez reciben identificadores distintos" do
      resultados = en_paralelo(Enum.map(1..100, fn n -> fn -> ServidorNecesidades.registrar("agua", 1, "baja", "centro", "n#{n}", "laura") end end))

      ids = Enum.map(resultados, fn {:ok, necesidad} -> necesidad.id end)
      assert length(Enum.uniq(ids)) == 100
    end
  end

  # ---------- Supervisión y persistencia ----------

  describe "Supervisión" do
    test "el árbol tiene los 9 procesos vivos" do
      hijos = Supervisor.which_children(SupervisorPrincipal)
      assert length(hijos) == 9
      assert Enum.all?(hijos, fn {_id, pid, _tipo, _modulos} -> is_pid(pid) end)
    end

    test "si se cae un servidor, el supervisor lo reinicia y recupera su información del archivo" do
      {:ok, _} = ServidorRecursos.registrar("R001", "agua", "agua", 50, "litros", "acopio_1", "centro")
      pid_recursos = Process.whereis(ServidorRecursos)
      pid_necesidades = Process.whereis(ServidorNecesidades)
      antes = ServidorRecursos.consultar()

      Process.exit(pid_recursos, :kill)
      pid_nuevo = esperar_reinicio(ServidorRecursos, pid_recursos, 40)

      assert is_pid(pid_nuevo) and pid_nuevo != pid_recursos
      assert ServidorRecursos.consultar() == antes
      # one_for_one: los demás no se reinician
      assert Process.whereis(ServidorNecesidades) == pid_necesidades
    end

    test "al reiniciar todo el sistema, la información se recupera de los archivos" do
      :ok = ServidorZonas.registrar_zona("centro", "Centro", "critico", 100)
      {:ok, _} = ServidorRecursos.registrar("R001", "agua", "agua", 50, "litros", "acopio_1", "centro")
      {:ok, _} = ServidorNecesidades.registrar("agua", 30, "critica", "centro", "x", "laura")
      {:ok, _} = ServidorPersonas.registrar("111", "Andrés", "norte", "localizada")
      {:ok, _} = ServidorMensajes.enviar("laura", "111", "Estoy bien")

      assert :ok = stop_supervised(SupervisorPrincipal)
      start_supervised!(SupervisorPrincipal)

      assert {:ok, %{personas_afectadas: 100}} = ServidorZonas.estado_zona("centro")
      assert [%{codigo: "R001", cantidad: 50}] = ServidorRecursos.consultar()
      assert [%{id: "N001"}] = ServidorNecesidades.consultar()
      assert [%{documento: "111"}] = ServidorPersonas.buscar()
      assert [%{contenido: "Estoy bien"}] = ServidorMensajes.listar_para("111")
    end
  end

  describe "Sesiones de usuario" do
    test "cada usuario conectado tiene su propio proceso, y se termina al desconectarse" do
      assert DynamicSupervisor.count_children(SupervisorSesiones).active == 0

      {:ok, %{como: :registrado}} = ServidorUsuarios.conectar("laura", "1234", "coordinador", "centro")
      {:ok, %{como: :registrado}} = ServidorUsuarios.conectar("andres", "abc", "ciudadano", "norte")
      assert DynamicSupervisor.count_children(SupervisorSesiones).active == 2

      # conectarse otra vez no crea una sesión nueva
      {:ok, %{como: :autenticado}} = ServidorUsuarios.conectar("laura", "1234", "coordinador", "centro")
      assert DynamicSupervisor.count_children(SupervisorSesiones).active == 2

      assert :ok = ServidorUsuarios.desconectar("andres")
      assert DynamicSupervisor.count_children(SupervisorSesiones).active == 1
      assert {:error, :no_conectado} = ServidorUsuarios.desconectar("andres")
    end

    test "no se devuelven las contraseñas y una contraseña mala no abre sesión" do
      {:ok, %{usuario: usuario}} = ServidorUsuarios.conectar("laura", "1234", "coordinador", "centro")
      refute Map.has_key?(usuario, :clave)

      assert {:error, :contrasena_incorrecta} = ServidorUsuarios.conectar("laura", "mala", "coordinador", "centro")
      assert ServidorUsuarios.conectados() == ["laura"]
    end

    test "si se cae ServidorUsuarios se cierran las sesiones huérfanas y los usuarios se conservan" do
      {:ok, _} = ServidorUsuarios.conectar("laura", "1234", "coordinador", "centro")
      pid = Process.whereis(ServidorUsuarios)

      Process.exit(pid, :kill)
      assert is_pid(esperar_reinicio(ServidorUsuarios, pid, 40))

      assert DynamicSupervisor.count_children(SupervisorSesiones).active == 0
      assert {:error, :no_conectado} = ServidorUsuarios.sesion("laura")
      # sigue registrada: al conectarse se reconoce, no se vuelve a registrar
      assert {:ok, %{como: :autenticado}} = ServidorUsuarios.conectar("laura", "1234", "coordinador", "centro")
    end

    test "la actividad del usuario queda registrada en su sesión y en el archivo" do
      {:ok, _} = ServidorUsuarios.conectar("laura", "1234", "coordinador", "centro")
      :ok = ServidorUsuarios.registrar_actividad("laura", "summary")

      assert {:ok, %{acciones: 2}} = ServidorUsuarios.informacion_sesion("laura")
      assert {:ok, [_connect, [_fecha, "laura", "summary"]]} = ServidorUsuarios.actividad("laura")
      assert {:error, :no_conectado} = ServidorUsuarios.registrar_actividad("fantasma", "summary")
    end
  end

  # ---------- Comandos: sesión, permisos y validaciones ----------

  describe "Comandos" do
    test "hay que conectarse antes de usar cualquier comando" do
      assert {:error, mensaje} = comando(nil, "summary")
      assert mensaje =~ "connect"
    end

    test "un comando mal escrito o inexistente da un mensaje claro" do
      comando(nil, "connect laura 1234 coordinador centro")
      assert {:error, mensaje} = comando("laura", "volar_a_la_luna")
      assert mensaje =~ "desconocido"
      assert {:error, mensaje} = comando("laura", "zone_status")
      assert mensaje =~ "Sintaxis"
    end

    test "cada tipo de usuario solo ejecuta los comandos que le corresponden" do
      comando(nil, "connect andres abc ciudadano centro")
      comando(nil, "connect pedro xyz voluntario centro")
      comando(nil, "connect laura 1234 coordinador centro")
      comando(nil, "connect root 0000 administrador centro")

      assert {:error, m} = comando("andres", "summary")
      assert m =~ "No tiene permiso"
      assert {:error, m} = comando("andres", "assign_resource N001 agua 10")
      assert m =~ "No tiene permiso"
      assert {:error, m} = comando("pedro", "register_zone sur Sur bajo")
      assert m =~ "No tiene permiso"
      assert {:error, m} = comando("pedro", "assign_resource N001 agua 10")
      assert m =~ "No tiene permiso"

      assert {:ok, _} = comando("laura", "register_zone sur Sur bajo")
      assert {:ok, _} = comando("laura", "summary")
      assert {:ok, _} = comando("root", "activity laura")
      assert {:error, m} = comando("laura", "activity root")
      assert m =~ "No tiene permiso"
    end

    test "valida números, zonas y tipos antes de modificar el estado" do
      comando(nil, "connect laura 1234 coordinador centro")
      comando("laura", "register_zone centro Centro critico")

      assert {:error, m} = comando("laura", "register_need agua veinte critica centro mal")
      assert m =~ "número"
      assert {:error, m} = comando("laura", "register_need agua 20 critica sur mal")
      assert m =~ "zona no existe"
      assert {:error, m} = comando("laura", "register_need oro 20 critica centro mal")
      assert m =~ "no es válido"
      assert {:error, m} = comando("laura", "register_resource R1 agua -5 litros acopio centro")
      assert m =~ "cantidad"

      assert ServidorNecesidades.consultar() == []
      assert ServidorRecursos.consultar() == []
    end

    test "los filtros de las listas se validan" do
      comando(nil, "connect laura 1234 coordinador centro")
      assert {:error, m} = comando("laura", "list_needs color=rojo")
      assert m =~ "Filtro no válido"
      assert {:ok, _} = comando("laura", "list_needs zona=centro prioridad=critica")
    end
  end

  # ---------- Flujo de ejemplo del enunciado, de punta a punta ----------

  describe "Flujo de ejemplo del enunciado" do
    test "emergencia completa con varios usuarios" do
      # Laura se conecta como coordinadora de la zona centro
      assert {:ok, m} = comando(nil, "connect laura 1234 coordinador centro")
      assert m =~ "coordinador"
      assert {:ok, _} = comando("laura", ~s(register_zone centro "Zona Centro" critico 500))
      assert {:ok, _} = comando("laura", ~s(register_sector centro s3 "Sector 3" alto 120))
      assert {:ok, _} = comando("laura", ~s(register_point centro s3 p1 "Punto de atención sector 3" medio 40))
      assert {:ok, _} = comando("laura", ~s(register_shelter A01 "Albergue Norte" centro 150))

      # Registra una necesidad crítica de 30 litros de agua
      assert {:ok, m} = comando("laura", ~s(register_need agua 30 critica centro "Punto de atención sector 3"))
      assert m =~ "N001"

      # El centro de acopio registra 50 litros disponibles
      assert {:ok, _} = comando("laura", "register_resource R001 agua 50 litros centro_acopio_1")

      # Al mismo tiempo, otro usuario registra una necesidad de 25 litros
      assert {:ok, _} = comando(nil, "connect pedro xyz coordinador centro")
      assert {:ok, m} = comando("pedro", ~s(register_need agua 25 critica centro "Albergue centro"))
      assert m =~ "N002"

      # El sistema procesa ambas asignaciones sin permitir 55 litros de 50
      resultados =
        en_paralelo([
          fn -> comando("laura", "assign_resource N001 agua 30") end,
          fn -> comando("pedro", "assign_resource N002 agua 25") end
        ])

      assert exitos(resultados) == 1
      assert ServidorRecursos.disponible_total(%{categoria: "agua"}) in [20, 25]

      # Un ciudadano registra a Andrés como persona localizada en el Albergue Norte
      assert {:ok, _} = comando(nil, "connect ciudadano1 abc ciudadano centro")
      assert {:ok, _} = comando("ciudadano1", "report_person 111 Andres centro localizada 30")
      assert {:ok, m} = comando("laura", "register_entry A01 111")
      assert m =~ "en_albergue"

      # Un familiar deja un mensaje para Andrés
      assert {:ok, _} = comando("ciudadano1", ~s(send_family_message 111 "Estoy bien, estoy en el albergue norte"))
      assert {:ok, m} = comando("ciudadano1", "list_family_messages 111")
      assert m =~ "Estoy bien, estoy en el albergue norte"

      # Un voluntario registra una mascota encontrada donde existe una perdida
      assert {:ok, _} = comando("ciudadano1", "report_pet lost perro Luna negra mediana centro 300 collar rojo")
      assert {:ok, _} = comando(nil, "connect voluntario1 xyz voluntario centro")
      assert {:ok, _} = comando("voluntario1", "report_pet found perro desconocido negra mediana centro 311 collar rojo")

      # El sistema calcula posibles coincidencias
      assert {:ok, m} = comando("voluntario1", "match_pets")
      assert m =~ "PET001 <-> PET002"

      # Un coordinador consulta el resumen global
      assert {:ok, resumen} = comando("laura", "summary")
      assert resumen =~ "Recursos restantes: agua:"
      assert resumen =~ "Pendientes: 1"
      assert resumen =~ "en_albergue: 1"
      assert resumen =~ "Mensajes: 1 (pendientes: 1)"
      assert resumen =~ "posible_coincidencia: 2"
      assert resumen =~ "A01 1/150"
    end

    test "persona: registrar, buscar por documento y por filtros, e historial" do
      comando(nil, "connect laura 1234 coordinador centro")
      comando("laura", "register_zone centro Centro critico")
      comando("laura", "register_zone norte Norte medio")

      assert {:ok, _} = comando("laura", "report_person 111 Andres centro localizada")
      assert {:ok, _} = comando("laura", ~s(report_person 222 "María López" norte reportada 34))
      assert {:ok, _} = comando("laura", "change_person_status 111 trasladada")

      assert {:ok, m} = comando("laura", "find_person 111")
      assert m =~ "Historial de estados: localizada -> trasladada"
      assert {:ok, m} = comando("laura", "find_person nombre=mar")
      assert m =~ "María López"
      assert {:ok, m} = comando("laura", "find_person zona=norte estado=reportada")
      assert m =~ "222"
      assert {:error, m} = comando("laura", "find_person 999")
      assert m =~ "No hay una persona"
    end

    test "cancel_need devuelve los recursos y critical_resources avisa cuando faltan" do
      comando(nil, "connect laura 1234 coordinador centro")
      comando("laura", "register_zone centro Centro critico")
      comando("laura", "register_resource R001 agua 20 litros acopio_1")
      comando("laura", "register_need agua 30 critica centro Pozo")
      comando("laura", "register_need agua 15 alta centro Escuela")

      assert {:ok, m} = comando("laura", "critical_resources")
      assert m =~ "agua: faltan 30, disponibles 20"

      assert {:ok, _} = comando("laura", "assign_resource N002 agua 15")
      assert {:ok, m} = comando("laura", "cancel_need N002")
      assert m =~ "R001: 15"
      assert ServidorRecursos.disponible_total(%{categoria: "agua"}) == 20
    end
  end
end
