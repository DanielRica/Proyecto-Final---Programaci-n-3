# Integrantes: (Juan José Lopez Cuartas - Daniel Ricardo Chacón Montenegro)

# Pruebas de la lógica pura (carpeta dominio/) y de la persistencia.
# No se ejecuta solo: lo carga `pruebas.exs`.

defmodule PruebasDominio do
  use ExUnit.Case

  # Antes de CADA prueba: una carpeta de datos nueva y vacía, para no tocar los datos reales.
  setup do
    carpeta = Path.join(System.tmp_dir!(), "emergencias_dominio_#{System.unique_integer([:positive])}")
    System.put_env("DATOS_DIR", carpeta)

    on_exit(fn ->
      System.delete_env("DATOS_DIR")
      File.rm_rf(carpeta)
    end)

    :ok
  end

  # ---------- Datos de ejemplo ----------

  defp zonas_de_ejemplo do
    {:ok, zonas} = Zonas.registrar_zona(%{}, "centro", "Centro", "critico", 100)
    {:ok, zonas} = Zonas.agregar_sector(zonas, "centro", "s1", "Sector 1", "alto", 50)
    {:ok, zonas} = Zonas.agregar_sector(zonas, "centro", "s2", "Sector 2", "medio", 30)
    {:ok, zonas} = Zonas.agregar_punto(zonas, "centro", "s2", "p1", "Punto 1", "bajo", 10)
    zonas
  end

  defp necesidades_de_ejemplo do
    {:ok, n, _} = Necesidades.registrar(%{}, "agua", 30, "critica", "centro", "Punto sector 3", "laura")
    {:ok, n, _} = Necesidades.registrar(n, "alimentos", 10, "baja", "centro", "Albergue", "laura")
    {:ok, n, _} = Necesidades.registrar(n, "rescate", 2, "critica", "norte", "Edificio", "andres")
    {:ok, n, _} = Necesidades.registrar(n, "medicamentos", 5, "alta", "centro", "Clínica", "laura")
    n
  end

  defp inventario_de_ejemplo do
    {:ok, inv, _} = Recursos.registrar(Recursos.nuevo(), "R001", "agua", "agua", 30, "litros", "acopio_1", "centro")
    {:ok, inv, _} = Recursos.registrar(inv, "R002", "agua", "agua", 100, "litros", "acopio_2", "norte")
    inv
  end

  defp reportes_de_ejemplo do
    {:ok, r, _} = Mascotas.registrar(%{}, "perdida", "perro", "Luna", "negra", "mediana", "norte", "300", "collar rojo manchas blancas")
    {:ok, r, _} = Mascotas.registrar(r, "perdida", "gato", "Michi", "blanco", "pequena", "centro", "301")
    {:ok, r, _} = Mascotas.registrar(r, "encontrada", "perro", "desconocido", "negra", "mediana", "norte", "311", "collar rojo")
    {:ok, r, _} = Mascotas.registrar(r, "encontrada", "perro", "desconocido", "cafe", "grande", "sur", "312")
    r
  end

  # ---------- Usuarios ----------

  describe "Usuarios" do
    test "connect registra automáticamente al usuario nuevo y luego lo autentica" do
      assert {:ok, usuarios, usuario, :registrado} = Usuarios.conectar(%{}, "laura", "1234", "coordinador", "centro")
      assert usuario.tipo == "coordinador"
      assert usuario.zona == "centro"

      assert {:ok, _usuarios, _usuario, :autenticado} = Usuarios.conectar(usuarios, "laura", "1234", "otro", "otra")
    end

    test "rechaza una contraseña incorrecta" do
      {:ok, usuarios, _usuario, _como} = Usuarios.conectar(%{}, "laura", "1234", "coordinador", "centro")
      assert {:error, :contrasena_incorrecta} = Usuarios.conectar(usuarios, "laura", "9999", "coordinador", "centro")
    end

    test "rechaza un tipo de usuario inválido, un dato vacío y un carácter no permitido" do
      assert {:error, :tipo_invalido} = Usuarios.conectar(%{}, "pedro", "abc", "jefe", "norte")
      assert {:error, :campo_vacio} = Usuarios.conectar(%{}, "pedro", "", "ciudadano", "norte")
      assert {:error, :caracter_invalido} = Usuarios.conectar(%{}, "pe;dro", "abc", "ciudadano", "norte")
    end

    test "no se puede registrar dos veces el mismo usuario" do
      {:ok, usuarios} = Usuarios.registrar(%{}, "laura", "1234", "Laura", "coordinador", "centro")
      assert {:error, :usuario_existente} = Usuarios.registrar(usuarios, "laura", "1234", "Laura", "coordinador", "centro")
    end

    test "la contraseña no se guarda en texto plano" do
      {:ok, usuarios} = Usuarios.registrar(%{}, "laura", "1234", "Laura", "coordinador", "centro")
      assert usuarios["laura"].clave != "1234"
    end

    test "los usuarios se guardan en archivo y se recuperan iguales" do
      {:ok, usuarios, _usuario, _como} = Usuarios.conectar(%{}, "laura", "1234", "coordinador", "centro")
      assert :ok = Usuarios.guardar(usuarios)
      assert {:ok, ^usuarios} = Usuarios.cargar()
    end

    test "la actividad de un usuario queda registrada" do
      :ok = Usuarios.registrar_actividad("laura", "summary")
      :ok = Usuarios.registrar_actividad("andres", "find_person 111")
      {:ok, registros} = Usuarios.consultar_actividad("laura")
      assert length(registros) == 1
    end
  end

  # ---------- Zonas (estructura recursiva) ----------

  describe "Zonas" do
    test "total_personas suma recursivamente la zona, sus sectores y sus puntos" do
      zonas = zonas_de_ejemplo()
      # 100 (zona) + 50 (s1) + 30 (s2) + 10 (p1)
      assert Zonas.total_personas(zonas["centro"]) == 190
    end

    test "contar_tipo cuenta sectores y puntos de atención" do
      zonas = zonas_de_ejemplo()
      assert Zonas.contar_tipo(zonas["centro"], "sector") == 2
      assert Zonas.contar_tipo(zonas["centro"], "punto") == 1
    end

    test "estado_zona entrega estadísticas acumuladas de la zona y de cada sector" do
      {:ok, estado} = Zonas.estado_zona(zonas_de_ejemplo(), "centro")
      assert estado.personas_afectadas == 190
      assert estado.sectores == 2
      assert estado.puntos_atencion == 1
      assert Enum.find(estado.detalle_sectores, &(&1.codigo == "s2")).personas_afectadas == 40
    end

    test "rechaza zonas repetidas, niveles inválidos y rutas inexistentes" do
      zonas = zonas_de_ejemplo()
      assert {:error, :zona_existente} = Zonas.registrar_zona(zonas, "centro", "Otra", "bajo")
      assert {:error, :nivel_invalido} = Zonas.registrar_zona(zonas, "sur", "Sur", "gigante")
      assert {:error, :zona_inexistente} = Zonas.agregar_sector(zonas, "sur", "s1", "S", "bajo")
      assert {:error, :ruta_inexistente} = Zonas.agregar_punto(zonas, "centro", "s9", "p1", "P", "bajo")
      assert {:error, :codigo_existente} = Zonas.agregar_sector(zonas, "centro", "s1", "Repetido", "bajo")
      assert {:error, :cantidad_invalida} = Zonas.agregar_sector(zonas, "centro", "s5", "S", "bajo", -5)
    end

    test "el árbol se guarda en archivo y se recupera igual" do
      zonas = zonas_de_ejemplo()
      assert :ok = Zonas.guardar(zonas)
      assert {:ok, ^zonas} = Zonas.cargar()
    end
  end

  # ---------- Necesidades ----------

  describe "Necesidades" do
    test "cada necesidad recibe un identificador único y empieza pendiente" do
      necesidades = necesidades_de_ejemplo()
      assert Map.keys(necesidades) |> Enum.sort() == ["N001", "N002", "N003", "N004"]
      assert Enum.all?(Map.values(necesidades), &(&1.estado == "pendiente"))
    end

    test "valida tipo, prioridad y cantidad" do
      assert {:error, :tipo_invalido} = Necesidades.registrar(%{}, "oro", 5, "alta", "centro", "x", "laura")
      assert {:error, :prioridad_invalida} = Necesidades.registrar(%{}, "agua", 5, "urgente", "centro", "x", "laura")
      assert {:error, :cantidad_invalida} = Necesidades.registrar(%{}, "agua", 0, "alta", "centro", "x", "laura")
    end

    test "la prioridad ordena: crítica primero y, a igual prioridad, la más antigua" do
      ids = necesidades_de_ejemplo() |> Necesidades.consultar() |> Enum.map(& &1.id)
      assert ids == ["N001", "N003", "N004", "N002"]
    end

    test "siguiente_a_atender elige la pendiente más urgente" do
      assert {:ok, %{id: "N001"}} = Necesidades.siguiente_a_atender(necesidades_de_ejemplo())
    end

    test "consultar filtra por zona, tipo, prioridad y estado" do
      necesidades = necesidades_de_ejemplo()
      assert [%{id: "N001"}] = Necesidades.consultar(necesidades, %{zona: "centro", prioridad: "critica"})
      assert [%{id: "N003"}] = Necesidades.consultar(necesidades, %{tipo: "rescate"})
      assert [] = Necesidades.consultar(necesidades, %{estado: "atendida"})
    end

    test "las asignaciones parciales suman y completan la necesidad" do
      necesidades = necesidades_de_ejemplo()
      {:ok, necesidades, n} = Necesidades.registrar_asignacion(necesidades, "N001", 20)
      assert n.estado == "pendiente" and n.cantidad_asignada == 20

      assert {:error, :excede_cantidad_requerida} = Necesidades.registrar_asignacion(necesidades, "N001", 15)

      {:ok, _necesidades, n} = Necesidades.registrar_asignacion(necesidades, "N001", 10)
      assert n.estado == "asignada" and n.cantidad_asignada == 30
    end

    test "una necesidad atendida o cancelada no puede volver a consumir recursos" do
      {:ok, n, _} = Necesidades.registrar_asignacion(necesidades_de_ejemplo(), "N001", 30)
      {:ok, n, _} = Necesidades.cambiar_estado(n, "N001", "en_atencion")
      {:ok, n, _} = Necesidades.cambiar_estado(n, "N001", "atendida")
      assert {:error, :estado_no_admite_asignacion} = Necesidades.registrar_asignacion(n, "N001", 1)
    end

    test "no se puede cerrar dos veces una necesidad" do
      {:ok, n, _} = Necesidades.registrar_asignacion(necesidades_de_ejemplo(), "N001", 30)
      {:ok, n, _} = Necesidades.cambiar_estado(n, "N001", "en_atencion")
      {:ok, n, _} = Necesidades.cambiar_estado(n, "N001", "atendida")
      assert {:error, :necesidad_cerrada} = Necesidades.cambiar_estado(n, "N001", "atendida")
      assert {:error, :necesidad_cerrada} = Necesidades.cambiar_estado(n, "N001", "cancelada")
    end

    test "solo se permiten transiciones de estado válidas" do
      n = necesidades_de_ejemplo()
      assert {:error, :transicion_invalida} = Necesidades.cambiar_estado(n, "N002", "atendida")
      assert {:error, :estado_invalido} = Necesidades.cambiar_estado(n, "N002", "volando")
      assert {:error, :necesidad_inexistente} = Necesidades.cambiar_estado(n, "N999", "cancelada")
      assert {:ok, _n, %{estado: "cancelada"}} = Necesidades.cambiar_estado(n, "N002", "cancelada")
    end

    test "revertir_asignacion deshace una reserva" do
      {:ok, n, _} = Necesidades.registrar_asignacion(necesidades_de_ejemplo(), "N001", 30)
      assert {:ok, _n, %{cantidad_asignada: 0, estado: "pendiente"}} = Necesidades.revertir_asignacion(n, "N001", 30)
      assert {:error, :reversion_invalida} = Necesidades.revertir_asignacion(n, "N001", 31)
    end

    test "las necesidades se guardan en archivo y se recuperan iguales" do
      necesidades = necesidades_de_ejemplo()
      assert :ok = Necesidades.guardar(necesidades)
      assert {:ok, ^necesidades} = Necesidades.cargar()
    end
  end

  # ---------- Recursos ----------

  describe "Recursos" do
    test "no acepta cantidades negativas ni códigos repetidos" do
      inv = inventario_de_ejemplo()
      assert {:error, :cantidad_invalida} = Recursos.registrar(inv, "R9", "x", "x", -5, "u", "u", "z")
      assert {:error, :codigo_existente} = Recursos.registrar(inv, "R001", "x", "x", 1, "u", "u", "z")
    end

    test "una salida mayor al inventario falla y no cambia nada" do
      inv = inventario_de_ejemplo()
      assert {:error, :inventario_insuficiente} = Recursos.registrar_salida(inv, "R001", 31, "reparto")
      assert Recursos.disponible_total(inv, %{categoria: "agua"}) == 130
    end

    test "entradas y salidas actualizan el inventario y dejan historial" do
      inv = inventario_de_ejemplo()
      {:ok, inv, _} = Recursos.registrar_entrada(inv, "R001", 10, "donación")
      {:ok, inv, r} = Recursos.registrar_salida(inv, "R001", 5, "reparto")
      assert r.cantidad == 35

      tipos = inv |> Recursos.historial("R001") |> Enum.map(& &1.tipo)
      assert tipos == ["registro", "entrada", "salida"]
    end

    test "asignar toma primero de la zona de la necesidad y luego de otras zonas" do
      # R001 tiene 30 en "centro" y R002 tiene 100 en "norte"
      assert {:ok, inv, tomas} = Recursos.asignar(inventario_de_ejemplo(), "agua", 40, "N003", "centro")
      assert tomas == [{"R001", 30}, {"R002", 10}]
      assert Recursos.disponible_total(inv, %{categoria: "agua"}) == 90
    end

    test "asignar más de lo que hay falla y NO descuenta nada" do
      inv = inventario_de_ejemplo()
      assert {:error, :inventario_insuficiente} = Recursos.asignar(inv, "agua", 131, "N001", "centro")
      assert Recursos.disponible_total(inv, %{categoria: "agua"}) == 130
    end

    test "asignar exactamente todo el inventario deja 0, nunca negativo" do
      {:ok, inv, _tomas} = Recursos.asignar(inventario_de_ejemplo(), "agua", 130, "N001", "centro")
      assert Recursos.disponible_total(inv, %{categoria: "agua"}) == 0
      assert Enum.all?(Map.values(inv.recursos), &(&1.cantidad >= 0))
    end

    test "transferir mueve unidades sin crear ni perder ninguna" do
      inv = inventario_de_ejemplo()
      {:ok, inv2, codigo_destino} = Recursos.transferir(inv, "R001", "acopio_1", "albergue_2", 10)

      assert codigo_destino == "R001-albergue_2"
      assert inv2.recursos["R001"].cantidad == 20
      assert inv2.recursos[codigo_destino].cantidad == 10
      assert Recursos.disponible_total(inv2) == Recursos.disponible_total(inv)
    end

    test "transferir valida origen, destino y cantidad" do
      inv = inventario_de_ejemplo()
      assert {:error, :inventario_insuficiente} = Recursos.transferir(inv, "R001", "acopio_1", "otro", 31)
      assert {:error, :origen_incorrecto} = Recursos.transferir(inv, "R001", "no_es_aqui", "otro", 1)
      assert {:error, :destino_igual_al_origen} = Recursos.transferir(inv, "R001", "acopio_1", "acopio_1", 1)
      assert {:error, :recurso_inexistente} = Recursos.transferir(inv, "R999", "acopio_1", "otro", 1)
    end

    test "liberar_necesidad devuelve lo asignado y no lo devuelve dos veces" do
      {:ok, inv, _tomas} = Recursos.asignar(inventario_de_ejemplo(), "agua", 40, "N003", "centro")
      {:ok, inv, devueltos} = Recursos.liberar_necesidad(inv, "N003")
      assert devueltos == [{"R001", 30}, {"R002", 10}]
      assert Recursos.disponible_total(inv, %{categoria: "agua"}) == 130

      {:ok, inv, devueltos} = Recursos.liberar_necesidad(inv, "N003")
      assert devueltos == []
      assert Recursos.disponible_total(inv, %{categoria: "agua"}) == 130
    end

    test "con_poco_inventario lista los recursos con existencias bajas" do
      {:ok, inv, _} = Recursos.registrar(inventario_de_ejemplo(), "R003", "arroz", "alimentos", 4, "kg", "acopio_1", "centro")
      assert [%{codigo: "R003"}] = Recursos.con_poco_inventario(inv, 10)
    end

    test "el inventario y su historial se guardan en archivo y se recuperan iguales" do
      {:ok, inv, _tomas} = Recursos.asignar(inventario_de_ejemplo(), "agua", 40, "N003", "centro")
      assert :ok = Recursos.guardar(inv)
      assert {:ok, ^inv} = Recursos.cargar()
    end
  end

  # ---------- Albergues ----------

  describe "Albergues" do
    test "no permite superar la capacidad máxima" do
      {:ok, albergues, _} = Albergues.registrar(%{}, "A01", "Norte", "norte", 2)
      {:ok, albergues, _} = Albergues.registrar_ingreso(albergues, "A01", "111")
      {:ok, albergues, _} = Albergues.registrar_ingreso(albergues, "A01", "222")
      assert {:error, :albergue_lleno} = Albergues.registrar_ingreso(albergues, "A01", "333")
      assert {:ok, %{cupos: 0}} = Albergues.consultar_cupos(albergues, "A01")
    end

    test "una persona no puede estar en dos albergues ni salir de donde no está" do
      {:ok, albergues, _} = Albergues.registrar(%{}, "A01", "Norte", "norte", 5)
      {:ok, albergues, _} = Albergues.registrar(albergues, "A02", "Sur", "sur", 5)
      {:ok, albergues, _} = Albergues.registrar_ingreso(albergues, "A01", "111")

      assert {:error, :persona_ya_alojada} = Albergues.registrar_ingreso(albergues, "A02", "111")
      assert {:error, :persona_no_alojada} = Albergues.registrar_salida(albergues, "A02", "111")

      {:ok, albergues, _} = Albergues.registrar_salida(albergues, "A01", "111")
      assert {:ok, %{cupos: 5}} = Albergues.consultar_cupos(albergues, "A01")
    end

    test "valida capacidad, ocupación inicial y códigos repetidos" do
      assert {:error, :capacidad_invalida} = Albergues.registrar(%{}, "A01", "N", "z", 0)
      assert {:error, :capacidad_invalida} = Albergues.registrar(%{}, "A01", "N", "z", -3)
      assert {:error, :ocupacion_invalida} = Albergues.registrar(%{}, "A01", "N", "z", 5, 9)

      {:ok, albergues, _} = Albergues.registrar(%{}, "A01", "N", "z", 5)
      assert {:error, :albergue_existente} = Albergues.registrar(albergues, "A01", "N", "z", 5)
    end

    test "el reporte ordena los albergues del más lleno al menos lleno" do
      {:ok, albergues, _} = Albergues.registrar(%{}, "A01", "Norte", "norte", 3, 1)
      {:ok, albergues, _} = Albergues.registrar(albergues, "A02", "Sur", "sur", 10, 9)
      assert [%{codigo: "A02", porcentaje: 90.0}, %{codigo: "A01"}] = Albergues.mayor_ocupacion(albergues)
    end

    test "los albergues se guardan en archivo (con las personas alojadas) y se recuperan iguales" do
      {:ok, albergues, _} = Albergues.registrar(%{}, "A01", "Norte", "norte", 5)
      {:ok, albergues, _} = Albergues.registrar_ingreso(albergues, "A01", "111")
      assert :ok = Albergues.guardar(albergues)
      assert {:ok, ^albergues} = Albergues.cargar()
    end
  end

  # ---------- Personas y mensajes ----------

  describe "Personas" do
    test "conservan el historial de cambios de estado" do
      {:ok, p, _} = Personas.registrar(%{}, "111", "Andrés", "norte", "localizada")
      {:ok, p, _} = Personas.cambiar_estado(p, "111", "en_albergue")
      {:ok, p, _} = Personas.cambiar_estado(p, "111", "reunificada")
      assert {:ok, ["localizada", "en_albergue", "reunificada"]} = Personas.historial(p, "111")
    end

    test "solo permite transiciones válidas y el estado reunificada es final" do
      {:ok, p, _} = Personas.registrar(%{}, "111", "Andrés", "norte", "localizada")
      assert {:error, :transicion_invalida} = Personas.cambiar_estado(p, "111", "reportada")
      {:ok, p, _} = Personas.cambiar_estado(p, "111", "reunificada")
      assert {:error, :persona_reunificada} = Personas.cambiar_estado(p, "111", "localizada")
    end

    test "valida documento repetido, estado y edad" do
      {:ok, p, _} = Personas.registrar(%{}, "111", "Andrés", "norte", "localizada")
      assert {:error, :documento_existente} = Personas.registrar(p, "111", "Otro", "norte", "reportada")
      assert {:error, :estado_invalido} = Personas.registrar(p, "222", "Otro", "norte", "perdido")
      assert {:error, :edad_invalida} = Personas.registrar(p, "222", "Otro", "norte", "reportada", -1)
    end

    test "se busca por nombre (parcial), documento, zona y estado" do
      {:ok, p, _} = Personas.registrar(%{}, "111", "Andrés", "norte", "localizada")
      {:ok, p, _} = Personas.registrar(p, "222", "María López", "centro", "reportada", 34)

      assert [%{documento: "111"}] = Personas.buscar(p, %{nombre: "and"})
      assert [%{documento: "222"}] = Personas.buscar(p, %{zona: "centro"})
      assert [%{documento: "222"}] = Personas.buscar(p, %{estado: "reportada"})
      assert [%{documento: "111"}] = Personas.buscar(p, %{documento: "111"})
    end

    test "las personas se guardan en archivo y se recuperan iguales (incluida la edad desconocida)" do
      {:ok, p, _} = Personas.registrar(%{}, "111", "Andrés", "norte", "localizada")
      {:ok, p, _} = Personas.registrar(p, "222", "María", "centro", "reportada", 34)
      assert :ok = Personas.guardar(p)
      assert {:ok, ^p} = Personas.cargar()
    end
  end

  describe "Mensajes" do
    test "se registran como pendientes y pueden marcarse entregados o pendientes" do
      {:ok, m, mensaje} = Mensajes.enviar(%{}, "2026-11-09T10:00:00Z", "laura", "111", "Estoy bien")
      assert mensaje.estado == "pendiente"

      {:ok, m, %{estado: "entregado"}} = Mensajes.marcar_entregado(m, mensaje.id)
      assert {:error, :sin_cambios} = Mensajes.marcar_entregado(m, mensaje.id)
      assert {:ok, _m, %{estado: "pendiente"}} = Mensajes.marcar_pendiente(m, mensaje.id)
    end

    test "se listan por destinatario y por estado" do
      {:ok, m, _} = Mensajes.enviar(%{}, "f", "laura", "111", "uno")
      {:ok, m, _} = Mensajes.enviar(m, "f", "pedro", "111", "dos")
      {:ok, m, _} = Mensajes.enviar(m, "f", "ana", "222", "tres")
      {:ok, m, _} = Mensajes.marcar_entregado(m, "MSG001")

      assert length(Mensajes.listar_para(m, "111")) == 2
      assert [%{id: "MSG002"}] = Mensajes.listar_para(m, "111", "pendiente")
    end

    test "rechaza contenido vacío o con el separador del archivo" do
      assert {:error, :campo_vacio} = Mensajes.enviar(%{}, "f", "laura", "111", "")
      assert {:error, :caracter_invalido} = Mensajes.enviar(%{}, "f", "laura", "111", "hola; adiós")
    end

    test "los mensajes se guardan en archivo y se recuperan iguales" do
      {:ok, m, _} = Mensajes.enviar(%{}, "2026-11-09T10:00:00Z", "laura", "111", "Estoy bien, estoy en el albergue norte")
      assert :ok = Mensajes.guardar(m)
      assert {:ok, ^m} = Mensajes.cargar()
    end
  end

  # ---------- Mascotas ----------

  describe "Mascotas" do
    test "el puntaje combina especie, zona, color, tamaño y características" do
      r = reportes_de_ejemplo()
      # 30 + 25 + 20 + 15 + (2 palabras comunes de 4) = 95
      assert Mascotas.puntaje(r["PET001"], r["PET003"]) == 95
      # solo coincide la especie
      assert Mascotas.puntaje(r["PET001"], r["PET004"]) == 30
      # la especie distinta anula todo
      assert Mascotas.puntaje(r["PET002"], r["PET003"]) == 0
    end

    test "buscar_coincidencias solo devuelve parejas desde el umbral" do
      assert [%{perdida: "PET001", encontrada: "PET003", puntaje: 95}] = Mascotas.buscar_coincidencias(reportes_de_ejemplo())
    end

    test "marcar_posibles deja los reportes como posible_coincidencia" do
      {:ok, r, _coincidencias} = Mascotas.marcar_posibles(reportes_de_ejemplo())
      assert r["PET001"].estado == "posible_coincidencia"
      assert r["PET003"].estado == "posible_coincidencia"
      assert r["PET004"].estado == "activa"
    end

    test "confirmar la coincidencia cierra ambos reportes y no se puede repetir" do
      {:ok, r, {perdida, encontrada}} = Mascotas.confirmar_coincidencia(reportes_de_ejemplo(), "PET001", "PET003")
      assert perdida.estado == "resuelta" and perdida.coincidencia == "PET003"
      assert encontrada.estado == "resuelta" and encontrada.coincidencia == "PET001"
      assert {:error, :reporte_ya_resuelto} = Mascotas.confirmar_coincidencia(r, "PET001", "PET003")
    end

    test "confirmar valida el orden perdida/encontrada y que existan los reportes" do
      r = reportes_de_ejemplo()
      assert {:error, :tipos_incompatibles} = Mascotas.confirmar_coincidencia(r, "PET003", "PET001")
      assert {:error, :reporte_inexistente} = Mascotas.confirmar_coincidencia(r, "PET001", "PET999")
    end

    test "valida tipo y tamaño, y consulta por especie, zona y estado" do
      r = reportes_de_ejemplo()
      assert {:error, :tipo_invalido} = Mascotas.registrar(r, "vista", "perro", "x", "negra", "mediana", "norte", "1")
      assert {:error, :tamano_invalido} = Mascotas.registrar(r, "perdida", "perro", "x", "negra", "enorme", "norte", "1")
      assert length(Mascotas.consultar(r, %{especie: "perro"})) == 3
      assert [%{id: "PET002"}] = Mascotas.consultar(r, %{zona: "centro"})
      assert length(Mascotas.consultar(r, %{estado: "activa"})) == 4
    end

    test "los reportes se guardan en archivo y se recuperan iguales" do
      r = reportes_de_ejemplo()
      assert :ok = Mascotas.guardar(r)
      assert {:ok, ^r} = Mascotas.cargar()
    end
  end

  # ---------- Persistencia ----------

  describe "Persistencia" do
    test "validar_campos rechaza datos vacíos y el separador (función recursiva)" do
      assert :ok = Persistencia.validar_campos(["laura", "1234"])
      assert :ok = Persistencia.validar_campos([])
      assert {:error, :campo_vacio} = Persistencia.validar_campos(["laura", "  "])
      assert {:error, :caracter_invalido} = Persistencia.validar_campos(["a", "b;c"])
      assert {:error, :caracter_invalido} = Persistencia.validar_campos(["a\nb"])
    end

    test "guardar y cargar devuelven los mismos registros" do
      registros = [["a", "b", "c"], ["1", "", "3"]]
      assert :ok = Persistencia.guardar("prueba.txt", registros)
      assert {:ok, ^registros} = Persistencia.cargar("prueba.txt")
    end

    test "agregar suma un registro al final sin borrar lo anterior" do
      :ok = Persistencia.guardar("prueba.txt", [["a"]])
      :ok = Persistencia.agregar("prueba.txt", ["b"])
      assert {:ok, [["a"], ["b"]]} = Persistencia.cargar("prueba.txt")
    end

    test "un archivo que todavía no existe se carga como lista vacía" do
      assert {:ok, []} = Persistencia.cargar("no_existe.txt")
    end

    test "a_entero convierte textos numéricos y rechaza el resto" do
      assert {:ok, 30} = Persistencia.a_entero("30")
      assert {:error, :numero_invalido} = Persistencia.a_entero("treinta")
      assert {:error, :numero_invalido} = Persistencia.a_entero("30abc")
    end
  end
end
