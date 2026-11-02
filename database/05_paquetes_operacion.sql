-- =====================================================================
-- 05_paquetes_operacion.sql
--   PKG_ASIGNACION_EQUIPO, PKG_ASIGNACION_LICENCIA, PKG_TICKET, PKG_COMENTARIO
-- =====================================================================

-- ---------------------------------------------------------------------
-- PAQUETE 8: PKG_ASIGNACION_EQUIPO  (RF-03)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_asignacion_equipo AS
  FUNCTION  fn_empleado_actual (p_id_equipo IN NUMBER) RETURN NUMBER;
  FUNCTION  fn_equipos_de_empleado (p_id_empleado IN NUMBER) RETURN NUMBER;

  PROCEDURE pr_asignar   (p_id_equipo IN NUMBER, p_id_empleado IN NUMBER, p_id OUT NUMBER);
  PROCEDURE pr_devolver  (p_id_equipo IN NUMBER);
  PROCEDURE pr_actualizar_fechas (p_id IN NUMBER, p_fecha_inicio IN DATE, p_fecha_fin IN DATE);
  PROCEDURE pr_eliminar  (p_id IN NUMBER);
  PROCEDURE pr_obtener   (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_listar_activas (p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_historial_equipo   (p_id_equipo IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_historial_empleado (p_id_empleado IN NUMBER, p_cursor OUT SYS_REFCURSOR);
END pkg_asignacion_equipo;
/

CREATE OR REPLACE PACKAGE BODY pkg_asignacion_equipo AS

  FUNCTION fn_empleado_actual (p_id_equipo IN NUMBER) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT id_empleado INTO v_id
      FROM asignacion_equipo
     WHERE id_equipo = p_id_equipo AND fecha_fin IS NULL;
    RETURN v_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END fn_empleado_actual;

  FUNCTION fn_equipos_de_empleado (p_id_empleado IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total
      FROM asignacion_equipo
     WHERE id_empleado = p_id_empleado AND fecha_fin IS NULL;
    RETURN v_total;
  END fn_equipos_de_empleado;

  -- CURSOR 9: si el equipo ya estaba asignado, cierra esa asignación (traspaso)
  PROCEDURE pr_asignar (p_id_equipo IN NUMBER, p_id_empleado IN NUMBER, p_id OUT NUMBER) IS
    CURSOR c_vigente IS
      SELECT id_asig_equipo, id_empleado
        FROM asignacion_equipo
       WHERE id_equipo = p_id_equipo
         AND fecha_fin IS NULL
         FOR UPDATE OF fecha_fin;
    v_estado equipo.estado%TYPE;
  BEGIN
    v_estado := pkg_equipo.fn_estado(p_id_equipo);
    IF v_estado IS NULL THEN
      pkg_utilidades.pr_error_no_existe('Equipo', p_id_equipo);
    ELSIF v_estado IN ('BAJA','REPARACION') THEN
      pkg_utilidades.pr_error_regla('El equipo está en estado ' || v_estado || ' y no puede asignarse.');
    END IF;
    IF pkg_empleado.fn_empleado_activo(p_id_empleado) = 0 THEN
      pkg_utilidades.pr_error_regla('El empleado no existe o está inactivo.');
    END IF;

    FOR r IN c_vigente LOOP
      IF r.id_empleado = p_id_empleado THEN
        pkg_utilidades.pr_error_regla('El equipo ya está asignado a ese empleado.');
      END IF;
      UPDATE asignacion_equipo SET fecha_fin = SYSDATE WHERE CURRENT OF c_vigente;
    END LOOP;

    INSERT INTO asignacion_equipo (id_equipo, id_empleado, fecha_inicio)
    VALUES (p_id_equipo, p_id_empleado, SYSDATE)
    RETURNING id_asig_equipo INTO p_id;
  END pr_asignar;

  PROCEDURE pr_devolver (p_id_equipo IN NUMBER) IS
  BEGIN
    UPDATE asignacion_equipo
       SET fecha_fin = SYSDATE
     WHERE id_equipo = p_id_equipo
       AND fecha_fin IS NULL;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_regla('El equipo ' || p_id_equipo || ' no tiene una asignación vigente.');
    END IF;
  END pr_devolver;

  -- Corrección de fechas del historial (no permite reabrir una asignación cerrada)
  PROCEDURE pr_actualizar_fechas (p_id IN NUMBER, p_fecha_inicio IN DATE, p_fecha_fin IN DATE) IS
    v_fin_actual DATE;
  BEGIN
    BEGIN
      SELECT fecha_fin INTO v_fin_actual FROM asignacion_equipo WHERE id_asig_equipo = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error_no_existe('Asignación de equipo', p_id);
    END;
    IF p_fecha_inicio IS NULL THEN
      pkg_utilidades.pr_error_validacion('La fecha de inicio es obligatoria.');
    END IF;
    IF v_fin_actual IS NOT NULL AND p_fecha_fin IS NULL THEN
      pkg_utilidades.pr_error_regla('No se puede reabrir una asignación finalizada; cree una nueva.');
    END IF;
    IF p_fecha_fin IS NOT NULL AND p_fecha_fin < p_fecha_inicio THEN
      pkg_utilidades.pr_error_validacion('La fecha de fin no puede ser anterior a la de inicio.');
    END IF;
    UPDATE asignacion_equipo
       SET fecha_inicio = p_fecha_inicio,
           fecha_fin = p_fecha_fin
     WHERE id_asig_equipo = p_id;
  END pr_actualizar_fechas;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
    v_fin DATE;
  BEGIN
    BEGIN
      SELECT fecha_fin INTO v_fin FROM asignacion_equipo WHERE id_asig_equipo = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error_no_existe('Asignación de equipo', p_id);
    END;
    IF v_fin IS NULL THEN
      pkg_utilidades.pr_error_regla('La asignación está vigente. Registre la devolución antes de eliminarla.');
    END IF;
    DELETE FROM asignacion_equipo WHERE id_asig_equipo = p_id;
  END pr_eliminar;

  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_historial_asignaciones WHERE id_asig_equipo = p_id;
  END pr_obtener;

  PROCEDURE pr_listar_activas (p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_asignaciones_activas ORDER BY empleado;
  END pr_listar_activas;

  PROCEDURE pr_historial_equipo (p_id_equipo IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT * FROM v_historial_asignaciones
       WHERE id_equipo = p_id_equipo
       ORDER BY fecha_inicio DESC;
  END pr_historial_equipo;

  PROCEDURE pr_historial_empleado (p_id_empleado IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT * FROM v_historial_asignaciones
       WHERE id_empleado = p_id_empleado
       ORDER BY fecha_inicio DESC;
  END pr_historial_empleado;

END pkg_asignacion_equipo;
/

-- ---------------------------------------------------------------------
-- PAQUETE 9: PKG_ASIGNACION_LICENCIA  (RF-08)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_asignacion_licencia AS
  FUNCTION  fn_licencias_de_empleado (p_id_empleado IN NUMBER) RETURN NUMBER;
  FUNCTION  fn_esta_asignada (p_id_licencia IN NUMBER, p_id_empleado IN NUMBER) RETURN NUMBER;

  PROCEDURE pr_asignar    (p_id_licencia IN NUMBER, p_id_empleado IN NUMBER, p_id OUT NUMBER);
  PROCEDURE pr_reasignar  (p_id IN NUMBER, p_id_empleado IN NUMBER);
  PROCEDURE pr_revocar    (p_id IN NUMBER);
  PROCEDURE pr_revocar_vencidas (p_revocadas OUT NUMBER);
  PROCEDURE pr_obtener    (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_listar     (p_id_licencia IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_licencias_empleado (p_id_empleado IN NUMBER, p_cursor OUT SYS_REFCURSOR);
END pkg_asignacion_licencia;
/

CREATE OR REPLACE PACKAGE BODY pkg_asignacion_licencia AS

  FUNCTION fn_licencias_de_empleado (p_id_empleado IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total FROM asignacion_licencia WHERE id_empleado = p_id_empleado;
    RETURN v_total;
  END fn_licencias_de_empleado;

  FUNCTION fn_esta_asignada (p_id_licencia IN NUMBER, p_id_empleado IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total
      FROM asignacion_licencia
     WHERE id_licencia = p_id_licencia AND id_empleado = p_id_empleado;
    RETURN v_total;
  END fn_esta_asignada;

  PROCEDURE pr_asignar (p_id_licencia IN NUMBER, p_id_empleado IN NUMBER, p_id OUT NUMBER) IS
    v_disponibles NUMBER;
  BEGIN
    v_disponibles := pkg_licencia.fn_disponibles(p_id_licencia);
    IF v_disponibles IS NULL THEN
      pkg_utilidades.pr_error_no_existe('Licencia', p_id_licencia);
    ELSIF v_disponibles <= 0 THEN
      pkg_utilidades.pr_error_regla('La licencia no tiene puestos disponibles.');
    END IF;
    IF pkg_empleado.fn_empleado_activo(p_id_empleado) = 0 THEN
      pkg_utilidades.pr_error_regla('El empleado no existe o está inactivo.');
    END IF;
    IF fn_esta_asignada(p_id_licencia, p_id_empleado) > 0 THEN
      pkg_utilidades.pr_error_regla('El empleado ya tiene asignada esa licencia.');
    END IF;

    INSERT INTO asignacion_licencia (id_licencia, id_empleado)
    VALUES (p_id_licencia, p_id_empleado)
    RETURNING id_asig_licencia INTO p_id;
  END pr_asignar;

  PROCEDURE pr_reasignar (p_id IN NUMBER, p_id_empleado IN NUMBER) IS
  BEGIN
    IF pkg_empleado.fn_empleado_activo(p_id_empleado) = 0 THEN
      pkg_utilidades.pr_error_regla('El empleado no existe o está inactivo.');
    END IF;
    UPDATE asignacion_licencia
       SET id_empleado = p_id_empleado,
           fecha_asignacion = SYSDATE
     WHERE id_asig_licencia = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Asignación de licencia', p_id);
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_regla('Ese empleado ya tiene asignada la licencia.');
  END pr_reasignar;

  PROCEDURE pr_revocar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM asignacion_licencia WHERE id_asig_licencia = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Asignación de licencia', p_id);
    END IF;
  END pr_revocar;

  -- CURSOR 10: libera los puestos de licencias que ya vencieron
  PROCEDURE pr_revocar_vencidas (p_revocadas OUT NUMBER) IS
    CURSOR c_vencidas IS
      SELECT al.id_asig_licencia
        FROM asignacion_licencia al
        JOIN licencia l ON l.id_licencia = al.id_licencia
       WHERE l.fecha_vencimiento < TRUNC(SYSDATE);
  BEGIN
    p_revocadas := 0;
    FOR r IN c_vencidas LOOP
      DELETE FROM asignacion_licencia WHERE id_asig_licencia = r.id_asig_licencia;
      p_revocadas := p_revocadas + 1;
    END LOOP;
  END pr_revocar_vencidas;

  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT al.id_asig_licencia, al.id_licencia, l.software, al.id_empleado,
             e.nombre_completo AS empleado, al.fecha_asignacion, l.fecha_vencimiento
        FROM asignacion_licencia al
        JOIN licencia l ON l.id_licencia = al.id_licencia
        JOIN empleado e ON e.id_empleado = al.id_empleado
       WHERE al.id_asig_licencia = p_id;
  END pr_obtener;

  PROCEDURE pr_listar (p_id_licencia IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT al.id_asig_licencia, al.id_licencia, l.software, al.id_empleado,
             e.nombre_completo AS empleado, al.fecha_asignacion, l.fecha_vencimiento
        FROM asignacion_licencia al
        JOIN licencia l ON l.id_licencia = al.id_licencia
        JOIN empleado e ON e.id_empleado = al.id_empleado
       WHERE p_id_licencia IS NULL OR al.id_licencia = p_id_licencia
       ORDER BY l.software, e.nombre_completo;
  END pr_listar;

  PROCEDURE pr_licencias_empleado (p_id_empleado IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT al.id_asig_licencia, l.software, l.proveedor, al.fecha_asignacion, l.fecha_vencimiento
        FROM asignacion_licencia al
        JOIN licencia l ON l.id_licencia = al.id_licencia
       WHERE al.id_empleado = p_id_empleado
       ORDER BY l.software;
  END pr_licencias_empleado;

END pkg_asignacion_licencia;
/

-- ---------------------------------------------------------------------
-- PAQUETE 10: PKG_TICKET  (RF-04, RF-05, RF-06)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_ticket AS
  FUNCTION  fn_estado (p_id IN NUMBER) RETURN VARCHAR2;
  FUNCTION  fn_transicion_valida (p_actual IN VARCHAR2, p_nuevo IN VARCHAR2) RETURN NUMBER;
  FUNCTION  fn_horas_resolucion (p_id IN NUMBER) RETURN NUMBER;
  FUNCTION  fn_promedio_resolucion (p_id_tecnico IN NUMBER DEFAULT NULL) RETURN NUMBER;

  PROCEDURE pr_crear (p_id_empleado IN NUMBER, p_id_equipo IN NUMBER, p_titulo IN VARCHAR2,
                      p_descripcion IN VARCHAR2, p_categoria IN VARCHAR2, p_prioridad IN VARCHAR2,
                      p_id OUT NUMBER);
  PROCEDURE pr_actualizar (p_id IN NUMBER, p_titulo IN VARCHAR2, p_descripcion IN VARCHAR2,
                           p_categoria IN VARCHAR2, p_prioridad IN VARCHAR2);
  PROCEDURE pr_asignar_tecnico (p_id IN NUMBER, p_id_tecnico IN NUMBER);
  PROCEDURE pr_cambiar_estado  (p_id IN NUMBER, p_estado IN VARCHAR2);
  PROCEDURE pr_asignar_automatico (p_asignados OUT NUMBER);
  PROCEDURE pr_cerrar_resueltos (p_dias IN NUMBER, p_cerrados OUT NUMBER);
  PROCEDURE pr_eliminar (p_id IN NUMBER);
  PROCEDURE pr_obtener  (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_filtrar  (p_estado IN VARCHAR2, p_prioridad IN VARCHAR2, p_id_tecnico IN NUMBER,
                         p_id_empleado IN NUMBER, p_sin_asignar IN VARCHAR2,
                         p_cursor OUT SYS_REFCURSOR);
END pkg_ticket;
/

CREATE OR REPLACE PACKAGE BODY pkg_ticket AS

  PROCEDURE pr_validar_clasificacion (p_categoria IN VARCHAR2, p_prioridad IN VARCHAR2) IS
  BEGIN
    IF p_categoria IS NULL OR UPPER(p_categoria) NOT IN ('HARDWARE','SOFTWARE','RED','ACCESOS','OTRO') THEN
      pkg_utilidades.pr_error_validacion('Categoría inválida. Use HARDWARE, SOFTWARE, RED, ACCESOS u OTRO.');
    END IF;
    IF p_prioridad IS NULL OR UPPER(p_prioridad) NOT IN ('BAJA','MEDIA','ALTA','CRITICA') THEN
      pkg_utilidades.pr_error_validacion('Prioridad inválida. Use BAJA, MEDIA, ALTA o CRITICA.');
    END IF;
  END pr_validar_clasificacion;

  FUNCTION fn_estado (p_id IN NUMBER) RETURN VARCHAR2 IS
    v_estado ticket.estado%TYPE;
  BEGIN
    SELECT estado INTO v_estado FROM ticket WHERE id_ticket = p_id;
    RETURN v_estado;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END fn_estado;

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

  FUNCTION fn_horas_resolucion (p_id IN NUMBER) RETURN NUMBER IS
    v_horas NUMBER;
  BEGIN
    SELECT ROUND((fecha_cierre - fecha_creacion) * 24, 2) INTO v_horas
      FROM ticket WHERE id_ticket = p_id;
    RETURN v_horas;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END fn_horas_resolucion;

  -- CURSOR 11 (con parámetro): promedia horas de resolución
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

  PROCEDURE pr_crear (p_id_empleado IN NUMBER, p_id_equipo IN NUMBER, p_titulo IN VARCHAR2,
                      p_descripcion IN VARCHAR2, p_categoria IN VARCHAR2, p_prioridad IN VARCHAR2,
                      p_id OUT NUMBER) IS
    v_estado_equipo equipo.estado%TYPE;
    v_duplicado     NUMBER;
  BEGIN
    IF pkg_empleado.fn_empleado_activo(p_id_empleado) = 0 THEN
      pkg_utilidades.pr_error_regla('El empleado solicitante no existe o está inactivo.');
    END IF;
    pkg_utilidades.pr_validar_requerido(p_titulo, 'título');
    pkg_utilidades.pr_validar_requerido(p_descripcion, 'descripción');
    pr_validar_clasificacion(p_categoria, p_prioridad);

    IF p_id_equipo IS NOT NULL THEN
      v_estado_equipo := pkg_equipo.fn_estado(p_id_equipo);
      IF v_estado_equipo IS NULL THEN
        pkg_utilidades.pr_error_no_existe('Equipo', p_id_equipo);
      ELSIF v_estado_equipo = 'BAJA' THEN
        pkg_utilidades.pr_error_regla('El equipo indicado está dado de baja.');
      END IF;
    END IF;

    -- Evita tickets duplicados (problema detectado en la empresa)
    SELECT MIN(id_ticket) INTO v_duplicado
      FROM ticket
     WHERE id_empleado = p_id_empleado
       AND UPPER(titulo) = UPPER(TRIM(p_titulo))
       AND estado IN ('ABIERTO','EN_PROCESO');
    IF v_duplicado IS NOT NULL THEN
      pkg_utilidades.pr_error_regla('Ya tiene un ticket pendiente con ese título (#' || v_duplicado || ').');
    END IF;

    INSERT INTO ticket (id_empleado, id_equipo, titulo, descripcion, categoria, prioridad)
    VALUES (p_id_empleado, p_id_equipo, TRIM(p_titulo), TRIM(p_descripcion),
            UPPER(p_categoria), UPPER(p_prioridad))
    RETURNING id_ticket INTO p_id;
  END pr_crear;

  PROCEDURE pr_actualizar (p_id IN NUMBER, p_titulo IN VARCHAR2, p_descripcion IN VARCHAR2,
                           p_categoria IN VARCHAR2, p_prioridad IN VARCHAR2) IS
    v_estado ticket.estado%TYPE;
  BEGIN
    v_estado := fn_estado(p_id);
    IF v_estado IS NULL THEN
      pkg_utilidades.pr_error_no_existe('Ticket', p_id);
    ELSIF v_estado = 'CERRADO' THEN
      pkg_utilidades.pr_error_regla('El ticket está cerrado y no puede modificarse.');
    END IF;
    pkg_utilidades.pr_validar_requerido(p_titulo, 'título');
    pkg_utilidades.pr_validar_requerido(p_descripcion, 'descripción');
    pr_validar_clasificacion(p_categoria, p_prioridad);
    UPDATE ticket
       SET titulo = TRIM(p_titulo),
           descripcion = TRIM(p_descripcion),
           categoria = UPPER(p_categoria),
           prioridad = UPPER(p_prioridad)
     WHERE id_ticket = p_id;
  END pr_actualizar;

  PROCEDURE pr_asignar_tecnico (p_id IN NUMBER, p_id_tecnico IN NUMBER) IS
    v_estado ticket.estado%TYPE;
    v_activo NUMBER;
  BEGIN
    v_estado := fn_estado(p_id);
    IF v_estado IS NULL THEN
      pkg_utilidades.pr_error_no_existe('Ticket', p_id);
    ELSIF v_estado IN ('RESUELTO','CERRADO') THEN
      pkg_utilidades.pr_error_regla('El ticket está ' || v_estado || '; no se puede reasignar.');
    END IF;

    SELECT COUNT(*) INTO v_activo
      FROM tecnico t
      JOIN empleado e ON e.id_empleado = t.id_empleado
     WHERE t.id_tecnico = p_id_tecnico
       AND t.activo = 'S'
       AND e.activo = 'S';
    IF v_activo = 0 THEN
      pkg_utilidades.pr_error_regla('El técnico no existe o está inactivo.');
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
        pkg_utilidades.pr_error_no_existe('Ticket', p_id);
    END;
    IF v_nuevo IS NULL OR v_nuevo NOT IN ('ABIERTO','EN_PROCESO','RESUELTO','CERRADO') THEN
      pkg_utilidades.pr_error_validacion('Estado inválido. Use ABIERTO, EN_PROCESO, RESUELTO o CERRADO.');
    END IF;
    IF fn_transicion_valida(v_actual, v_nuevo) = 0 THEN
      pkg_utilidades.pr_error_regla('No se puede pasar de ' || v_actual || ' a ' || v_nuevo || '.');
    END IF;
    IF v_nuevo IN ('EN_PROCESO','RESUELTO') AND v_tecnico IS NULL THEN
      pkg_utilidades.pr_error_regla('Asigne un técnico antes de pasar el ticket a ' || v_nuevo || '.');
    END IF;

    UPDATE ticket
       SET estado = v_nuevo,
           id_tecnico = CASE WHEN v_nuevo = 'ABIERTO' THEN NULL ELSE id_tecnico END
     WHERE id_ticket = p_id;
  END pr_cambiar_estado;

  -- CURSOR 12: reparte los tickets sin técnico al técnico con menos carga
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
      v_tecnico := pkg_tecnico.fn_tecnico_menor_carga;
      EXIT WHEN v_tecnico IS NULL;
      pr_asignar_tecnico(r.id_ticket, v_tecnico);
      p_asignados := p_asignados + 1;
    END LOOP;
  END pr_asignar_automatico;

  -- CURSOR 13 (FOR UPDATE): cierra los tickets resueltos hace más de N días
  PROCEDURE pr_cerrar_resueltos (p_dias IN NUMBER, p_cerrados OUT NUMBER) IS
    CURSOR c_resueltos IS
      SELECT id_ticket
        FROM ticket
       WHERE estado = 'RESUELTO'
         AND fecha_cierre <= SYSDATE - NVL(p_dias, 3)
         FOR UPDATE OF estado;
  BEGIN
    p_cerrados := 0;
    FOR r IN c_resueltos LOOP
      UPDATE ticket SET estado = 'CERRADO' WHERE CURRENT OF c_resueltos;
      p_cerrados := p_cerrados + 1;
    END LOOP;
  END pr_cerrar_resueltos;

  -- Solo se elimina un ticket creado por error (abierto y sin técnico)
  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
    v_estado  ticket.estado%TYPE;
    v_tecnico ticket.id_tecnico%TYPE;
  BEGIN
    BEGIN
      SELECT estado, id_tecnico INTO v_estado, v_tecnico FROM ticket WHERE id_ticket = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error_no_existe('Ticket', p_id);
    END;
    IF v_estado <> 'ABIERTO' OR v_tecnico IS NOT NULL THEN
      pkg_utilidades.pr_error_regla('Solo se eliminan tickets ABIERTOS sin técnico. Para los demás, ciérrelos.');
    END IF;
    DELETE FROM ticket WHERE id_ticket = p_id;
  END pr_eliminar;

  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_tickets_detalle WHERE id_ticket = p_id;
  END pr_obtener;

  -- RF-06: todos los filtros son opcionales (NULL = sin filtro)
  PROCEDURE pr_filtrar (p_estado IN VARCHAR2, p_prioridad IN VARCHAR2, p_id_tecnico IN NUMBER,
                        p_id_empleado IN NUMBER, p_sin_asignar IN VARCHAR2,
                        p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT id_ticket, titulo, categoria, prioridad, estado, solicitante, tecnico,
             fecha_creacion, fecha_cierre, horas_resolucion
        FROM v_tickets_detalle
       WHERE (p_estado      IS NULL OR estado = UPPER(p_estado))
         AND (p_prioridad   IS NULL OR prioridad = UPPER(p_prioridad))
         AND (p_id_tecnico  IS NULL OR id_tecnico = p_id_tecnico)
         AND (p_id_empleado IS NULL OR id_empleado = p_id_empleado)
         AND (NVL(p_sin_asignar, 'N') = 'N' OR id_tecnico IS NULL)
       ORDER BY CASE WHEN estado IN ('ABIERTO','EN_PROCESO') THEN 0 ELSE 1 END,
                orden_prioridad, fecha_creacion;
  END pr_filtrar;

END pkg_ticket;
/

-- ---------------------------------------------------------------------
-- PAQUETE 11: PKG_COMENTARIO  (RF-07; la interfaz se completa en la semana 10)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_comentario AS
  FUNCTION  fn_total_comentarios (p_id_ticket IN NUMBER) RETURN NUMBER;
  FUNCTION  fn_historial_texto   (p_id_ticket IN NUMBER) RETURN VARCHAR2;

  PROCEDURE pr_insertar   (p_id_ticket IN NUMBER, p_id_tecnico IN NUMBER, p_texto IN VARCHAR2,
                           p_id OUT NUMBER);
  PROCEDURE pr_actualizar (p_id IN NUMBER, p_texto IN VARCHAR2);
  PROCEDURE pr_eliminar   (p_id IN NUMBER);
  PROCEDURE pr_obtener    (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_listar_por_ticket (p_id_ticket IN NUMBER, p_cursor OUT SYS_REFCURSOR);
END pkg_comentario;
/

CREATE OR REPLACE PACKAGE BODY pkg_comentario AS

  FUNCTION fn_total_comentarios (p_id_ticket IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total FROM comentario_ticket WHERE id_ticket = p_id_ticket;
    RETURN v_total;
  END fn_total_comentarios;

  -- CURSOR 14: arma la bitácora del ticket en un solo texto
  FUNCTION fn_historial_texto (p_id_ticket IN NUMBER) RETURN VARCHAR2 IS
    CURSOR c_comentarios IS
      SELECT fecha, tecnico, texto
        FROM v_comentarios_detalle
       WHERE id_ticket = p_id_ticket
       ORDER BY fecha;
    v_texto VARCHAR2(32767);
  BEGIN
    FOR r IN c_comentarios LOOP
      v_texto := v_texto || TO_CHAR(r.fecha, 'DD/MM/YYYY HH24:MI') || ' - ' ||
                 r.tecnico || ': ' || r.texto || CHR(10);
      EXIT WHEN LENGTH(v_texto) > 4000;
    END LOOP;
    RETURN SUBSTR(NVL(v_texto, 'Sin comentarios.'), 1, 4000);
  END fn_historial_texto;

  PROCEDURE pr_insertar (p_id_ticket IN NUMBER, p_id_tecnico IN NUMBER, p_texto IN VARCHAR2,
                         p_id OUT NUMBER) IS
    v_activo NUMBER;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_texto, 'texto');
    IF pkg_ticket.fn_estado(p_id_ticket) IS NULL THEN
      pkg_utilidades.pr_error_no_existe('Ticket', p_id_ticket);
    END IF;
    SELECT COUNT(*) INTO v_activo FROM tecnico WHERE id_tecnico = p_id_tecnico AND activo = 'S';
    IF v_activo = 0 THEN
      pkg_utilidades.pr_error_regla('El técnico no existe o está inactivo.');
    END IF;
    INSERT INTO comentario_ticket (id_ticket, id_tecnico, texto)
    VALUES (p_id_ticket, p_id_tecnico, p_texto)
    RETURNING id_comentario INTO p_id;
  END pr_insertar;

  PROCEDURE pr_actualizar (p_id IN NUMBER, p_texto IN VARCHAR2) IS
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_texto, 'texto');
    UPDATE comentario_ticket SET texto = TRIM(p_texto) WHERE id_comentario = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Comentario', p_id);
    END IF;
  END pr_actualizar;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM comentario_ticket WHERE id_comentario = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Comentario', p_id);
    END IF;
  END pr_eliminar;

  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_comentarios_detalle WHERE id_comentario = p_id;
  END pr_obtener;

  PROCEDURE pr_listar_por_ticket (p_id_ticket IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT id_comentario, fecha, tecnico, texto
        FROM v_comentarios_detalle
       WHERE id_ticket = p_id_ticket
       ORDER BY fecha;
  END pr_listar_por_ticket;

END pkg_comentario;
/
