-- =====================================================================
-- 05_paquetes_operacion.sql
--   PKG_ASIGNACION_EQUIPO, PKG_ASIGNACION_LICENCIA, PKG_TICKET, PKG_COMENTARIO
-- =====================================================================

-- ---------------------------------------------------------------------
-- PAQUETE 8: PKG_ASIGNACION_EQUIPO  (RF-03)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_asignacion_equipo AS
  -- Historial filtrado por equipo y/o empleado; p_solo_vigentes = 'S' devuelve las activas
  FUNCTION  fn_listar (p_id_equipo IN NUMBER, p_id_empleado IN NUMBER,
                       p_solo_vigentes IN VARCHAR2) RETURN SYS_REFCURSOR;
  PROCEDURE pr_asignar  (p_id_equipo IN NUMBER, p_id_empleado IN NUMBER, p_id OUT NUMBER);
  PROCEDURE pr_devolver (p_id_equipo IN NUMBER);
END pkg_asignacion_equipo;
/

CREATE OR REPLACE PACKAGE BODY pkg_asignacion_equipo AS

  FUNCTION fn_listar (p_id_equipo IN NUMBER, p_id_empleado IN NUMBER,
                      p_solo_vigentes IN VARCHAR2) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT *
        FROM v_asignaciones_equipo
       WHERE (p_id_equipo IS NULL OR id_equipo = p_id_equipo)
         AND (p_id_empleado IS NULL OR id_empleado = p_id_empleado)
         AND (NVL(p_solo_vigentes, 'N') = 'N' OR situacion = 'VIGENTE')
       ORDER BY CASE WHEN NVL(p_solo_vigentes, 'N') = 'S' THEN empleado END,
                fecha_inicio DESC;
    RETURN v_cursor;
  END fn_listar;

  -- CURSOR 10: si el equipo ya estaba asignado, cierra esa asignación (traspaso)
  PROCEDURE pr_asignar (p_id_equipo IN NUMBER, p_id_empleado IN NUMBER, p_id OUT NUMBER) IS
    CURSOR c_vigente IS
      SELECT id_asig_equipo, id_empleado
        FROM asignacion_equipo
       WHERE id_equipo = p_id_equipo
         AND fecha_fin IS NULL
         FOR UPDATE OF fecha_fin;
    v_estado equipo.estado%TYPE;
    v_activo NUMBER;
  BEGIN
    BEGIN
      SELECT estado INTO v_estado FROM equipo WHERE id_equipo = p_id_equipo;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
          'El equipo con id ' || p_id_equipo || ' no existe.');
    END;
    IF v_estado IN ('BAJA','REPARACION') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'El equipo está en estado ' || v_estado || ' y no puede asignarse.');
    END IF;
    SELECT COUNT(*) INTO v_activo FROM empleado WHERE id_empleado = p_id_empleado AND activo = 'S';
    IF v_activo = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El empleado no existe o está inactivo.');
    END IF;

    FOR r IN c_vigente LOOP
      IF r.id_empleado = p_id_empleado THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El equipo ya está asignado a ese empleado.');
      END IF;
      UPDATE asignacion_equipo SET fecha_fin = SYSDATE WHERE CURRENT OF c_vigente;
    END LOOP;

    INSERT INTO asignacion_equipo (id_equipo, id_empleado, fecha_inicio)
    VALUES (p_id_equipo, p_id_empleado, SYSDATE)
    RETURNING id_asig_equipo INTO p_id;
  END pr_asignar;

  -- CURSOR 11: cierra la asignación vigente del equipo (registro de devolución)
  PROCEDURE pr_devolver (p_id_equipo IN NUMBER) IS
    CURSOR c_vigente IS
      SELECT id_asig_equipo
        FROM asignacion_equipo
       WHERE id_equipo = p_id_equipo
         AND fecha_fin IS NULL
         FOR UPDATE OF fecha_fin;
    v_cerradas NUMBER := 0;
  BEGIN
    FOR r IN c_vigente LOOP
      UPDATE asignacion_equipo SET fecha_fin = SYSDATE WHERE CURRENT OF c_vigente;
      v_cerradas := v_cerradas + 1;
    END LOOP;
    IF v_cerradas = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'El equipo ' || p_id_equipo || ' no tiene una asignación vigente.');
    END IF;
  END pr_devolver;

END pkg_asignacion_equipo;
/

-- ---------------------------------------------------------------------
-- PAQUETE 9: PKG_ASIGNACION_LICENCIA  (RF-08: a empleados o a equipos)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_asignacion_licencia AS
  FUNCTION  fn_listar (p_id_licencia IN NUMBER, p_id_empleado IN NUMBER,
                       p_id_equipo IN NUMBER) RETURN SYS_REFCURSOR;
  -- Se indica p_id_empleado O p_id_equipo (exactamente uno de los dos)
  PROCEDURE pr_asignar (p_id_licencia IN NUMBER, p_id_empleado IN NUMBER, p_id_equipo IN NUMBER,
                        p_id OUT NUMBER);
  -- Con p_id revoca ese puesto; con p_id = NULL libera todos los puestos de licencias vencidas
  PROCEDURE pr_revocar (p_id IN NUMBER, p_revocadas OUT NUMBER);
END pkg_asignacion_licencia;
/

CREATE OR REPLACE PACKAGE BODY pkg_asignacion_licencia AS

  FUNCTION fn_listar (p_id_licencia IN NUMBER, p_id_empleado IN NUMBER,
                      p_id_equipo IN NUMBER) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT *
        FROM v_asignaciones_licencia
       WHERE (p_id_licencia IS NULL OR id_licencia = p_id_licencia)
         AND (p_id_empleado IS NULL OR id_empleado = p_id_empleado)
         AND (p_id_equipo   IS NULL OR id_equipo = p_id_equipo)
       ORDER BY software, destino, asignada_a;
    RETURN v_cursor;
  END fn_listar;

  -- CURSOR 12 (con parámetro): lee la vigencia de la licencia antes de asignar
  PROCEDURE pr_asignar (p_id_licencia IN NUMBER, p_id_empleado IN NUMBER, p_id_equipo IN NUMBER,
                        p_id OUT NUMBER) IS
    CURSOR c_licencia (cp_id NUMBER) IS
      SELECT fecha_vencimiento FROM licencia WHERE id_licencia = cp_id;
    v_vencimiento licencia.fecha_vencimiento%TYPE;
    v_valido      NUMBER;
  BEGIN
    IF (p_id_empleado IS NULL AND p_id_equipo IS NULL)
       OR (p_id_empleado IS NOT NULL AND p_id_equipo IS NOT NULL) THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Indique un empleado o un equipo (solo uno) para asignar la licencia.');
    END IF;

    OPEN c_licencia(p_id_licencia);
    FETCH c_licencia INTO v_vencimiento;
    IF c_licencia%NOTFOUND THEN
      CLOSE c_licencia;
      pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
        'La licencia con id ' || p_id_licencia || ' no existe.');
    END IF;
    CLOSE c_licencia;

    IF v_vencimiento < TRUNC(SYSDATE) THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'La licencia está vencida y no puede asignarse.');
    END IF;
    IF pkg_licencia.fn_disponibles(p_id_licencia) <= 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'La licencia no tiene puestos disponibles.');
    END IF;

    IF p_id_empleado IS NOT NULL THEN
      SELECT COUNT(*) INTO v_valido FROM empleado WHERE id_empleado = p_id_empleado AND activo = 'S';
      IF v_valido = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El empleado no existe o está inactivo.');
      END IF;
    ELSE
      SELECT COUNT(*) INTO v_valido FROM equipo WHERE id_equipo = p_id_equipo AND estado <> 'BAJA';
      IF v_valido = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El equipo no existe o está dado de baja.');
      END IF;
    END IF;

    INSERT INTO asignacion_licencia (id_licencia, id_empleado, id_equipo)
    VALUES (p_id_licencia, p_id_empleado, p_id_equipo)
    RETURNING id_asig_licencia INTO p_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        CASE WHEN p_id_empleado IS NOT NULL THEN 'El empleado' ELSE 'El equipo' END ||
        ' ya tiene asignada esa licencia.');
  END pr_asignar;

  -- CURSOR 13: libera los puestos de licencias que ya vencieron
  PROCEDURE pr_revocar (p_id IN NUMBER, p_revocadas OUT NUMBER) IS
    CURSOR c_vencidas IS
      SELECT al.id_asig_licencia
        FROM asignacion_licencia al
        JOIN licencia l ON l.id_licencia = al.id_licencia
       WHERE l.fecha_vencimiento < TRUNC(SYSDATE);
  BEGIN
    p_revocadas := 0;
    IF p_id IS NOT NULL THEN
      DELETE FROM asignacion_licencia WHERE id_asig_licencia = p_id;
      IF SQL%ROWCOUNT = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
          'La asignación de licencia con id ' || p_id || ' no existe.');
      END IF;
      p_revocadas := 1;
    ELSE
      FOR r IN c_vencidas LOOP
        DELETE FROM asignacion_licencia WHERE id_asig_licencia = r.id_asig_licencia;
        p_revocadas := p_revocadas + 1;
      END LOOP;
    END IF;
  END pr_revocar;

END pkg_asignacion_licencia;
/

-- ---------------------------------------------------------------------
-- PAQUETE 10: PKG_TICKET  (RF-04, RF-05, RF-06)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_ticket AS
  FUNCTION  fn_transicion_valida (p_actual IN VARCHAR2, p_nuevo IN VARCHAR2) RETURN NUMBER;
  -- RF-06: con p_id devuelve un ticket; los demás filtros son opcionales (NULL = sin filtro)
  FUNCTION  fn_listar (p_id IN NUMBER, p_estado IN VARCHAR2, p_prioridad IN VARCHAR2,
                       p_id_tecnico IN NUMBER, p_id_empleado IN NUMBER,
                       p_sin_asignar IN VARCHAR2) RETURN SYS_REFCURSOR;
  FUNCTION  fn_promedio_resolucion (p_id_tecnico IN NUMBER DEFAULT NULL) RETURN NUMBER;
  -- Crea el ticket si p_id es NULL; si trae valor modifica título, descripción y clasificación
  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_id_empleado IN NUMBER, p_id_equipo IN NUMBER,
                        p_titulo IN VARCHAR2, p_descripcion IN VARCHAR2, p_categoria IN VARCHAR2,
                        p_prioridad IN VARCHAR2);
  PROCEDURE pr_asignar_tecnico (p_id IN NUMBER, p_id_tecnico IN NUMBER);
  PROCEDURE pr_cambiar_estado  (p_id IN NUMBER, p_estado IN VARCHAR2);
  PROCEDURE pr_asignar_automatico (p_asignados OUT NUMBER);
  PROCEDURE pr_eliminar (p_id IN NUMBER);
END pkg_ticket;
/

CREATE OR REPLACE PACKAGE BODY pkg_ticket AS

  -- Ciclo de vida: ABIERTO -> EN_PROCESO -> RESUELTO -> CERRADO
  FUNCTION fn_transicion_valida (p_actual IN VARCHAR2, p_nuevo IN VARCHAR2) RETURN NUMBER IS
  BEGIN
    IF p_actual = p_nuevo THEN
      RETURN 1;
    END IF;
    RETURN CASE p_actual || '>' || p_nuevo
             WHEN 'ABIERTO>EN_PROCESO'  THEN 1
             WHEN 'ABIERTO>CERRADO'     THEN 1   -- cancelación
             WHEN 'EN_PROCESO>ABIERTO'  THEN 1   -- devolver a la cola
             WHEN 'EN_PROCESO>RESUELTO' THEN 1
             WHEN 'RESUELTO>EN_PROCESO' THEN 1   -- reapertura
             WHEN 'RESUELTO>CERRADO'    THEN 1
             ELSE 0
           END;
  END fn_transicion_valida;

  FUNCTION fn_listar (p_id IN NUMBER, p_estado IN VARCHAR2, p_prioridad IN VARCHAR2,
                      p_id_tecnico IN NUMBER, p_id_empleado IN NUMBER,
                      p_sin_asignar IN VARCHAR2) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT *
        FROM v_tickets_detalle
       WHERE (p_id          IS NULL OR id_ticket = p_id)
         AND (p_estado      IS NULL OR estado = UPPER(p_estado))
         AND (p_prioridad   IS NULL OR prioridad = UPPER(p_prioridad))
         AND (p_id_tecnico  IS NULL OR id_tecnico = p_id_tecnico)
         AND (p_id_empleado IS NULL OR id_empleado = p_id_empleado)
         AND (NVL(p_sin_asignar, 'N') = 'N' OR id_tecnico IS NULL)
       ORDER BY CASE WHEN estado IN ('ABIERTO','EN_PROCESO') THEN 0 ELSE 1 END,
                orden_prioridad, fecha_creacion;
    RETURN v_cursor;
  END fn_listar;

  -- CURSOR 14 (con parámetro): promedia las horas de resolución
  FUNCTION fn_promedio_resolucion (p_id_tecnico IN NUMBER DEFAULT NULL) RETURN NUMBER IS
    CURSOR c_resueltos (cp_tecnico NUMBER) IS
      SELECT (fecha_cierre - fecha_creacion) * 24 AS horas
        FROM ticket
       WHERE fecha_cierre IS NOT NULL
         AND id_tecnico IS NOT NULL
         AND (cp_tecnico IS NULL OR id_tecnico = cp_tecnico);
    v_horas    NUMBER;
    v_suma     NUMBER := 0;
    v_cantidad NUMBER := 0;
  BEGIN
    OPEN c_resueltos(p_id_tecnico);
    LOOP
      FETCH c_resueltos INTO v_horas;
      EXIT WHEN c_resueltos%NOTFOUND;
      v_suma := v_suma + v_horas;
      v_cantidad := v_cantidad + 1;
    END LOOP;
    CLOSE c_resueltos;
    IF v_cantidad = 0 THEN
      RETURN 0;
    END IF;
    RETURN ROUND(v_suma / v_cantidad, 2);
  END fn_promedio_resolucion;

  -- CURSOR 15 (con parámetros): evita tickets duplicados del mismo solicitante
  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_id_empleado IN NUMBER, p_id_equipo IN NUMBER,
                        p_titulo IN VARCHAR2, p_descripcion IN VARCHAR2, p_categoria IN VARCHAR2,
                        p_prioridad IN VARCHAR2) IS
    CURSOR c_duplicado (cp_empleado NUMBER, cp_titulo VARCHAR2) IS
      SELECT id_ticket
        FROM ticket
       WHERE id_empleado = cp_empleado
         AND UPPER(titulo) = UPPER(TRIM(cp_titulo))
         AND estado IN ('ABIERTO','EN_PROCESO')
       ORDER BY id_ticket;
    v_duplicado     NUMBER;
    v_estado        ticket.estado%TYPE;
    v_estado_equipo equipo.estado%TYPE;
    v_activo        NUMBER;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_titulo, 'título');
    pkg_utilidades.pr_validar_requerido(p_descripcion, 'descripción');
    IF p_categoria IS NULL OR UPPER(p_categoria) NOT IN ('HARDWARE','SOFTWARE','RED','ACCESOS','OTRO') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Categoría inválida. Use HARDWARE, SOFTWARE, RED, ACCESOS u OTRO.');
    END IF;
    IF p_prioridad IS NULL OR UPPER(p_prioridad) NOT IN ('BAJA','MEDIA','ALTA','CRITICA') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Prioridad inválida. Use BAJA, MEDIA, ALTA o CRITICA.');
    END IF;

    IF p_id IS NULL THEN
      SELECT COUNT(*) INTO v_activo FROM empleado WHERE id_empleado = p_id_empleado AND activo = 'S';
      IF v_activo = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El empleado solicitante no existe o está inactivo.');
      END IF;
      IF p_id_equipo IS NOT NULL THEN
        BEGIN
          SELECT estado INTO v_estado_equipo FROM equipo WHERE id_equipo = p_id_equipo;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
              'El equipo con id ' || p_id_equipo || ' no existe.');
        END;
        IF v_estado_equipo = 'BAJA' THEN
          pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El equipo indicado está dado de baja.');
        END IF;
      END IF;

      OPEN c_duplicado(p_id_empleado, p_titulo);
      FETCH c_duplicado INTO v_duplicado;
      CLOSE c_duplicado;
      IF v_duplicado IS NOT NULL THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
          'Ya tiene un ticket pendiente con ese título (#' || v_duplicado || ').');
      END IF;

      INSERT INTO ticket (id_empleado, id_equipo, titulo, descripcion, categoria, prioridad)
      VALUES (p_id_empleado, p_id_equipo, TRIM(p_titulo), TRIM(p_descripcion),
              UPPER(p_categoria), UPPER(p_prioridad))
      RETURNING id_ticket INTO p_id;
    ELSE
      BEGIN
        SELECT estado INTO v_estado FROM ticket WHERE id_ticket = p_id;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El ticket con id ' || p_id || ' no existe.');
      END;
      IF v_estado = 'CERRADO' THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El ticket está cerrado y no puede modificarse.');
      END IF;
      UPDATE ticket
         SET titulo = TRIM(p_titulo),
             descripcion = TRIM(p_descripcion),
             categoria = UPPER(p_categoria),
             prioridad = UPPER(p_prioridad)
       WHERE id_ticket = p_id;
    END IF;
  END pr_guardar;

  PROCEDURE pr_asignar_tecnico (p_id IN NUMBER, p_id_tecnico IN NUMBER) IS
    v_estado ticket.estado%TYPE;
    v_activo NUMBER;
  BEGIN
    BEGIN
      SELECT estado INTO v_estado FROM ticket WHERE id_ticket = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El ticket con id ' || p_id || ' no existe.');
    END;
    IF v_estado IN ('RESUELTO','CERRADO') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El ticket está ' || v_estado || '; no se puede reasignar.');
    END IF;

    SELECT COUNT(*) INTO v_activo
      FROM tecnico t
      JOIN empleado e ON e.id_empleado = t.id_empleado
     WHERE t.id_tecnico = p_id_tecnico
       AND t.activo = 'S'
       AND e.activo = 'S';
    IF v_activo = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El técnico no existe o está inactivo.');
    END IF;

    -- Al asignarse, un ticket ABIERTO pasa a EN_PROCESO
    UPDATE ticket
       SET id_tecnico = p_id_tecnico,
           estado = CASE WHEN estado = 'ABIERTO' THEN 'EN_PROCESO' ELSE estado END
     WHERE id_ticket = p_id;
  END pr_asignar_tecnico;

  PROCEDURE pr_cambiar_estado (p_id IN NUMBER, p_estado IN VARCHAR2) IS
    v_actual  ticket.estado%TYPE;
    v_tecnico ticket.id_tecnico%TYPE;
    v_nuevo   ticket.estado%TYPE := UPPER(TRIM(p_estado));
  BEGIN
    BEGIN
      SELECT estado, id_tecnico INTO v_actual, v_tecnico FROM ticket WHERE id_ticket = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El ticket con id ' || p_id || ' no existe.');
    END;
    IF v_nuevo IS NULL OR v_nuevo NOT IN ('ABIERTO','EN_PROCESO','RESUELTO','CERRADO') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Estado inválido. Use ABIERTO, EN_PROCESO, RESUELTO o CERRADO.');
    END IF;
    IF fn_transicion_valida(v_actual, v_nuevo) = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'No se puede pasar de ' || v_actual || ' a ' || v_nuevo || '.');
    END IF;
    IF v_nuevo IN ('EN_PROCESO','RESUELTO') AND v_tecnico IS NULL THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'Asigne un técnico antes de pasar el ticket a ' || v_nuevo || '.');
    END IF;

    UPDATE ticket
       SET estado = v_nuevo,
           id_tecnico = CASE WHEN v_nuevo = 'ABIERTO' THEN NULL ELSE id_tecnico END
     WHERE id_ticket = p_id;
  END pr_cambiar_estado;

  -- CURSOR 16: reparte los tickets sin técnico al técnico con menos carga
  PROCEDURE pr_asignar_automatico (p_asignados OUT NUMBER) IS
    CURSOR c_pendientes IS
      SELECT id_ticket
        FROM ticket
       WHERE id_tecnico IS NULL
         AND estado = 'ABIERTO'
       ORDER BY CASE prioridad WHEN 'CRITICA' THEN 1 WHEN 'ALTA' THEN 2
                               WHEN 'MEDIA' THEN 3 ELSE 4 END,
                fecha_creacion;
    v_tecnico NUMBER;
  BEGIN
    p_asignados := 0;
    FOR r IN c_pendientes LOOP
      v_tecnico := pkg_tecnico.fn_menor_carga;
      EXIT WHEN v_tecnico IS NULL;
      pr_asignar_tecnico(r.id_ticket, v_tecnico);
      p_asignados := p_asignados + 1;
    END LOOP;
  END pr_asignar_automatico;

  -- Solo se elimina un ticket creado por error (abierto y sin técnico)
  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
    v_estado  ticket.estado%TYPE;
    v_tecnico ticket.id_tecnico%TYPE;
  BEGIN
    BEGIN
      SELECT estado, id_tecnico INTO v_estado, v_tecnico FROM ticket WHERE id_ticket = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El ticket con id ' || p_id || ' no existe.');
    END;
    IF v_estado <> 'ABIERTO' OR v_tecnico IS NOT NULL THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'Solo se eliminan tickets ABIERTOS sin técnico. Para los demás, ciérrelos.');
    END IF;
    DELETE FROM ticket WHERE id_ticket = p_id;
  END pr_eliminar;

END pkg_ticket;
/

-- ---------------------------------------------------------------------
-- PAQUETE 11: PKG_COMENTARIO  (RF-07)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_comentario AS
  FUNCTION  fn_listar (p_id_ticket IN NUMBER) RETURN SYS_REFCURSOR;
  -- Registra el comentario si p_id es NULL; si trae valor corrige su texto
  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_id_ticket IN NUMBER, p_id_tecnico IN NUMBER,
                        p_texto IN VARCHAR2);
END pkg_comentario;
/

CREATE OR REPLACE PACKAGE BODY pkg_comentario AS

  FUNCTION fn_listar (p_id_ticket IN NUMBER) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT id_comentario, id_ticket, fecha, id_tecnico, tecnico, texto
        FROM v_comentarios_detalle
       WHERE id_ticket = p_id_ticket
       ORDER BY fecha;
    RETURN v_cursor;
  END fn_listar;

  -- CURSOR 17 (con parámetro): valida el ticket antes de comentarlo
  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_id_ticket IN NUMBER, p_id_tecnico IN NUMBER,
                        p_texto IN VARCHAR2) IS
    CURSOR c_ticket (cp_id NUMBER) IS
      SELECT estado FROM ticket WHERE id_ticket = cp_id;
    v_estado ticket.estado%TYPE;
    v_activo NUMBER;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_texto, 'texto');
    IF p_id IS NULL THEN
      OPEN c_ticket(p_id_ticket);
      FETCH c_ticket INTO v_estado;
      IF c_ticket%NOTFOUND THEN
        CLOSE c_ticket;
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
          'El ticket con id ' || p_id_ticket || ' no existe.');
      END IF;
      CLOSE c_ticket;
      SELECT COUNT(*) INTO v_activo FROM tecnico WHERE id_tecnico = p_id_tecnico AND activo = 'S';
      IF v_activo = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'Solo un técnico activo puede comentar tickets.');
      END IF;
      INSERT INTO comentario_ticket (id_ticket, id_tecnico, texto)
      VALUES (p_id_ticket, p_id_tecnico, p_texto)
      RETURNING id_comentario INTO p_id;
    ELSE
      UPDATE comentario_ticket SET texto = TRIM(p_texto) WHERE id_comentario = p_id;
      IF SQL%ROWCOUNT = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El comentario con id ' || p_id || ' no existe.');
      END IF;
    END IF;
  END pr_guardar;

END pkg_comentario;
/
