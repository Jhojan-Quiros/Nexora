-- =====================================================================
-- 04_paquetes_catalogos.sql
--   PKG_DEPARTAMENTO, PKG_TECNICO, PKG_EMPLEADO, PKG_EQUIPO, PKG_LICENCIA
-- Cada paquete ofrece el CRUD de su tabla:
--   fn_listar   -> consulta (un registro con p_id o la lista completa con filtros)
--   pr_guardar  -> inserta si p_id es NULL y modifica si trae valor (devuelve el id)
--   pr_eliminar -> borrado físico; el borrado lógico usa pr_cambiar_activo / pr_cambiar_estado
-- Los procedimientos NO hacen COMMIT: la aplicación confirma o revierte.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PAQUETE 3: PKG_DEPARTAMENTO  (RF-01)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_departamento AS
  FUNCTION  fn_listar (p_id IN NUMBER, p_solo_activos IN VARCHAR2) RETURN SYS_REFCURSOR;
  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_nombre IN VARCHAR2, p_ubicacion IN VARCHAR2);
  PROCEDURE pr_cambiar_activo (p_id IN NUMBER, p_activo IN VARCHAR2);
  PROCEDURE pr_eliminar (p_id IN NUMBER);
END pkg_departamento;
/

CREATE OR REPLACE PACKAGE BODY pkg_departamento AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  FUNCTION fn_listar (p_id IN NUMBER, p_solo_activos IN VARCHAR2) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT *
        FROM v_departamentos_resumen
       WHERE (p_id IS NULL OR id_departamento = p_id)
         AND (NVL(p_solo_activos, 'N') = 'N' OR activo = 'S')
       ORDER BY nombre;
    RETURN v_cursor;
  END fn_listar;

  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_nombre IN VARCHAR2, p_ubicacion IN VARCHAR2) IS
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_nombre, 'nombre');
    pkg_utilidades.pr_validar_requerido(p_ubicacion, 'ubicación');
    IF p_id IS NULL THEN
      INSERT INTO departamento (nombre, ubicacion)
      VALUES (TRIM(p_nombre), TRIM(p_ubicacion))
      RETURNING id_departamento INTO p_id;
    ELSE
      UPDATE departamento
         SET nombre = TRIM(p_nombre),
             ubicacion = TRIM(p_ubicacion)
       WHERE id_departamento = p_id;
      IF SQL%ROWCOUNT = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
          'El departamento con id ' || p_id || ' no existe.');
      END IF;
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Ya existe un departamento llamado "' || TRIM(p_nombre) || '".');
  END pr_guardar;

  -- CURSOR 2: cuenta los empleados activos antes de desactivar el departamento
  PROCEDURE pr_cambiar_activo (p_id IN NUMBER, p_activo IN VARCHAR2) IS
    CURSOR c_empleados_activos IS
      SELECT id_empleado
        FROM empleado
       WHERE id_departamento = p_id
         AND activo = 'S';
    v_empleados NUMBER := 0;
  BEGIN
    IF p_activo IS NULL OR UPPER(p_activo) NOT IN ('S','N') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion, 'El indicador de activo debe ser S o N.');
    END IF;
    IF UPPER(p_activo) = 'N' THEN
      FOR r IN c_empleados_activos LOOP
        v_empleados := v_empleados + 1;
      END LOOP;
      IF v_empleados > 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El departamento tiene ' || v_empleados ||
          ' empleado(s) activo(s). Reasígnelos o desactívelos primero.');
      END IF;
    END IF;
    UPDATE departamento SET activo = UPPER(p_activo) WHERE id_departamento = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
        'El departamento con id ' || p_id || ' no existe.');
    END IF;
  END pr_cambiar_activo;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM departamento WHERE id_departamento = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
        'El departamento con id ' || p_id || ' no existe.');
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'No se puede eliminar: el departamento tiene empleados registrados. Use desactivar.');
  END pr_eliminar;

END pkg_departamento;
/

-- ---------------------------------------------------------------------
-- PAQUETE 4: PKG_TECNICO
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_tecnico AS
  FUNCTION  fn_listar (p_id IN NUMBER, p_solo_activos IN VARCHAR2) RETURN SYS_REFCURSOR;
  FUNCTION  fn_menor_carga RETURN NUMBER;
  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_id_empleado IN NUMBER, p_especialidad IN VARCHAR2,
                        p_nivel IN VARCHAR2);
  PROCEDURE pr_cambiar_activo (p_id IN NUMBER, p_activo IN VARCHAR2, p_reasignados OUT NUMBER);
  PROCEDURE pr_eliminar (p_id IN NUMBER);
END pkg_tecnico;
/

CREATE OR REPLACE PACKAGE BODY pkg_tecnico AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  FUNCTION fn_listar (p_id IN NUMBER, p_solo_activos IN VARCHAR2) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT *
        FROM v_tecnicos_detalle
       WHERE (p_id IS NULL OR id_tecnico = p_id)
         AND (NVL(p_solo_activos, 'N') = 'N' OR activo = 'S')
       ORDER BY nombre_completo;
    RETURN v_cursor;
  END fn_listar;

  -- CURSOR 3: técnicos activos ordenados por carga; devuelve el primero
  FUNCTION fn_menor_carga RETURN NUMBER IS
    CURSOR c_carga IS
      SELECT t.id_tecnico, COUNT(k.id_ticket) AS carga
        FROM tecnico t
        JOIN empleado e ON e.id_empleado = t.id_empleado
        LEFT JOIN ticket k
               ON k.id_tecnico = t.id_tecnico
              AND k.estado IN ('ABIERTO','EN_PROCESO')
       WHERE t.activo = 'S'
         AND e.activo = 'S'
       GROUP BY t.id_tecnico
       ORDER BY carga, t.id_tecnico;
    v_id    NUMBER;
    v_carga NUMBER;
  BEGIN
    OPEN c_carga;
    FETCH c_carga INTO v_id, v_carga;
    IF c_carga%NOTFOUND THEN
      v_id := NULL;
    END IF;
    CLOSE c_carga;
    RETURN v_id;
  END fn_menor_carga;

  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_id_empleado IN NUMBER, p_especialidad IN VARCHAR2,
                        p_nivel IN VARCHAR2) IS
    v_activo empleado.activo%TYPE;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_especialidad, 'especialidad');
    IF p_nivel IS NULL OR UPPER(p_nivel) NOT IN ('JUNIOR','INTERMEDIO','SENIOR') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Nivel inválido. Use JUNIOR, INTERMEDIO o SENIOR.');
    END IF;

    IF p_id IS NULL THEN
      BEGIN
        SELECT activo INTO v_activo FROM empleado WHERE id_empleado = p_id_empleado;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
            'El empleado con id ' || p_id_empleado || ' no existe.');
      END;
      IF v_activo = 'N' THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El empleado está inactivo y no puede ser técnico.');
      END IF;

      INSERT INTO tecnico (id_empleado, especialidad, nivel)
      VALUES (p_id_empleado, TRIM(p_especialidad), UPPER(p_nivel))
      RETURNING id_tecnico INTO p_id;

      -- Un empleado común que pasa a ser técnico cambia de rol
      UPDATE empleado SET rol = 'TECNICO'
       WHERE id_empleado = p_id_empleado AND rol = 'EMPLEADO';
    ELSE
      UPDATE tecnico
         SET especialidad = TRIM(p_especialidad),
             nivel = UPPER(p_nivel)
       WHERE id_tecnico = p_id;
      IF SQL%ROWCOUNT = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El técnico con id ' || p_id || ' no existe.');
      END IF;
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion, 'Ese empleado ya está registrado como técnico.');
  END pr_guardar;

  -- CURSOR 4: al desactivar, devuelve a la cola los tickets pendientes del técnico
  PROCEDURE pr_cambiar_activo (p_id IN NUMBER, p_activo IN VARCHAR2, p_reasignados OUT NUMBER) IS
    CURSOR c_pendientes IS
      SELECT id_ticket
        FROM ticket
       WHERE id_tecnico = p_id
         AND estado IN ('ABIERTO','EN_PROCESO')
         FOR UPDATE OF id_tecnico, estado;
    v_activo_emp empleado.activo%TYPE;
  BEGIN
    p_reasignados := 0;
    IF p_activo IS NULL OR UPPER(p_activo) NOT IN ('S','N') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion, 'El indicador de activo debe ser S o N.');
    END IF;
    BEGIN
      SELECT e.activo INTO v_activo_emp
        FROM tecnico t JOIN empleado e ON e.id_empleado = t.id_empleado
       WHERE t.id_tecnico = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El técnico con id ' || p_id || ' no existe.');
    END;

    IF UPPER(p_activo) = 'S' THEN
      IF v_activo_emp = 'N' THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'Active primero al empleado asociado.');
      END IF;
      UPDATE tecnico SET activo = 'S' WHERE id_tecnico = p_id;
    ELSE
      UPDATE tecnico SET activo = 'N' WHERE id_tecnico = p_id;
      FOR r IN c_pendientes LOOP
        UPDATE ticket
           SET id_tecnico = NULL,
               estado = 'ABIERTO'
         WHERE CURRENT OF c_pendientes;
        p_reasignados := p_reasignados + 1;
      END LOOP;
    END IF;
  END pr_cambiar_activo;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM tecnico WHERE id_tecnico = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El técnico con id ' || p_id || ' no existe.');
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'No se puede eliminar: el técnico tiene tickets o comentarios. Use desactivar.');
  END pr_eliminar;

END pkg_tecnico;
/

-- ---------------------------------------------------------------------
-- PAQUETE 5: PKG_EMPLEADO  (RF-01)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_empleado AS
  -- p_texto busca por nombre, correo o usuario; todos los filtros son opcionales
  FUNCTION  fn_listar (p_id IN NUMBER, p_id_departamento IN NUMBER, p_solo_activos IN VARCHAR2,
                       p_texto IN VARCHAR2) RETURN SYS_REFCURSOR;
  -- Al modificar se ignoran p_usuario y p_contrasena (la contraseña se cambia en PKG_SEGURIDAD)
  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_id_departamento IN NUMBER, p_nombre IN VARCHAR2,
                        p_correo IN VARCHAR2, p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2,
                        p_rol IN VARCHAR2);
  PROCEDURE pr_cambiar_activo (p_id IN NUMBER, p_activo IN VARCHAR2);
  PROCEDURE pr_eliminar (p_id IN NUMBER);
END pkg_empleado;
/

CREATE OR REPLACE PACKAGE BODY pkg_empleado AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  FUNCTION fn_listar (p_id IN NUMBER, p_id_departamento IN NUMBER, p_solo_activos IN VARCHAR2,
                      p_texto IN VARCHAR2) RETURN SYS_REFCURSOR IS
    v_patron VARCHAR2(130) := '%' || UPPER(TRIM(p_texto)) || '%';
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT *
        FROM v_empleados_detalle
       WHERE (p_id IS NULL OR id_empleado = p_id)
         AND (p_id_departamento IS NULL OR id_departamento = p_id_departamento)
         AND (NVL(p_solo_activos, 'N') = 'N' OR activo = 'S')
         AND (TRIM(p_texto) IS NULL
              OR UPPER(nombre_completo) LIKE v_patron
              OR UPPER(correo) LIKE v_patron
              OR UPPER(usuario) LIKE v_patron)
       ORDER BY nombre_completo;
    RETURN v_cursor;
  END fn_listar;

  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_id_departamento IN NUMBER, p_nombre IN VARCHAR2,
                        p_correo IN VARCHAR2, p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2,
                        p_rol IN VARCHAR2) IS
    v_activo departamento.activo%TYPE;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_nombre, 'nombre completo');
    IF pkg_utilidades.fn_correo_valido(p_correo) = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'El correo "' || p_correo || '" no tiene un formato válido.');
    END IF;
    IF p_rol IS NULL OR UPPER(p_rol) NOT IN ('ADMIN','TECNICO','EMPLEADO') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion, 'Rol inválido. Use ADMIN, TECNICO o EMPLEADO.');
    END IF;
    BEGIN
      SELECT activo INTO v_activo FROM departamento WHERE id_departamento = p_id_departamento;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
          'El departamento con id ' || p_id_departamento || ' no existe.');
    END;
    IF v_activo = 'N' THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El departamento está inactivo.');
    END IF;

    IF p_id IS NULL THEN
      pkg_utilidades.pr_validar_requerido(p_usuario, 'usuario');
      IF pkg_utilidades.fn_contrasena_segura(p_contrasena) = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
          'La contraseña debe tener al menos 8 caracteres, letras y números.');
      END IF;
      INSERT INTO empleado (id_departamento, nombre_completo, correo, usuario, contrasena_hash, rol)
      VALUES (p_id_departamento, p_nombre, p_correo, p_usuario,
              pkg_utilidades.fn_hash_contrasena(p_usuario, p_contrasena), UPPER(p_rol))
      RETURNING id_empleado INTO p_id;
    ELSE
      UPDATE empleado
         SET id_departamento = p_id_departamento,
             nombre_completo = p_nombre,
             correo = p_correo,
             rol = UPPER(p_rol)
       WHERE id_empleado = p_id;
      IF SQL%ROWCOUNT = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El empleado con id ' || p_id || ' no existe.');
      END IF;
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion, 'El correo o el usuario ya están registrados.');
  END pr_guardar;

  -- CURSOR 5: al desactivar, cierra las asignaciones de equipo vigentes del empleado
  -- CURSOR 6: libera los puestos de licencia asignados al empleado
  PROCEDURE pr_cambiar_activo (p_id IN NUMBER, p_activo IN VARCHAR2) IS
    CURSOR c_equipos IS
      SELECT id_asig_equipo
        FROM asignacion_equipo
       WHERE id_empleado = p_id
         AND fecha_fin IS NULL
         FOR UPDATE OF fecha_fin;
    CURSOR c_licencias IS
      SELECT id_asig_licencia
        FROM asignacion_licencia
       WHERE id_empleado = p_id;
    v_actual      empleado.activo%TYPE;
    v_id_tecnico  tecnico.id_tecnico%TYPE;
    v_reasignados NUMBER;
  BEGIN
    IF p_activo IS NULL OR UPPER(p_activo) NOT IN ('S','N') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion, 'El indicador de activo debe ser S o N.');
    END IF;
    BEGIN
      SELECT activo INTO v_actual FROM empleado WHERE id_empleado = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El empleado con id ' || p_id || ' no existe.');
    END;

    IF UPPER(p_activo) = 'N' AND v_actual = 'S' THEN
      FOR r IN c_equipos LOOP
        UPDATE asignacion_equipo SET fecha_fin = SYSDATE WHERE CURRENT OF c_equipos;
      END LOOP;
      FOR r IN c_licencias LOOP
        DELETE FROM asignacion_licencia WHERE id_asig_licencia = r.id_asig_licencia;
      END LOOP;
      -- Si además es técnico, se desactiva y sus tickets vuelven a la cola
      BEGIN
        SELECT id_tecnico INTO v_id_tecnico FROM tecnico WHERE id_empleado = p_id AND activo = 'S';
        pkg_tecnico.pr_cambiar_activo(v_id_tecnico, 'N', v_reasignados);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
      END;
    END IF;

    UPDATE empleado SET activo = UPPER(p_activo) WHERE id_empleado = p_id;
  END pr_cambiar_activo;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM empleado WHERE id_empleado = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El empleado con id ' || p_id || ' no existe.');
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'No se puede eliminar: el empleado tiene historial (tickets, equipos o licencias). Use desactivar.');
  END pr_eliminar;

END pkg_empleado;
/

-- ---------------------------------------------------------------------
-- PAQUETE 6: PKG_EQUIPO  (RF-02)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_equipo AS
  FUNCTION  fn_listar (p_id IN NUMBER, p_estado IN VARCHAR2, p_tipo IN VARCHAR2) RETURN SYS_REFCURSOR;
  FUNCTION  fn_resumen_inventario RETURN VARCHAR2;
  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_tipo IN VARCHAR2, p_marca IN VARCHAR2,
                        p_modelo IN VARCHAR2, p_numero_serie IN VARCHAR2, p_fecha_compra IN DATE);
  -- DISPONIBLE <-> REPARACION, o BAJA (definitiva). ASIGNADO lo maneja PKG_ASIGNACION_EQUIPO.
  PROCEDURE pr_cambiar_estado (p_id IN NUMBER, p_estado IN VARCHAR2);
  PROCEDURE pr_eliminar (p_id IN NUMBER);
END pkg_equipo;
/

CREATE OR REPLACE PACKAGE BODY pkg_equipo AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  FUNCTION fn_listar (p_id IN NUMBER, p_estado IN VARCHAR2, p_tipo IN VARCHAR2) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT *
        FROM v_equipos_detalle
       WHERE (p_id IS NULL OR id_equipo = p_id)
         AND (p_estado IS NULL OR estado = UPPER(p_estado))
         AND (p_tipo IS NULL OR tipo = UPPER(p_tipo))
       ORDER BY tipo, marca, modelo;
    RETURN v_cursor;
  END fn_listar;

  -- CURSOR 7: cuenta equipos por estado y arma un texto resumen
  FUNCTION fn_resumen_inventario RETURN VARCHAR2 IS
    CURSOR c_estados IS
      SELECT estado, COUNT(*) AS total
        FROM equipo
       GROUP BY estado
       ORDER BY estado;
    v_registro c_estados%ROWTYPE;
    v_resumen  VARCHAR2(400);
  BEGIN
    OPEN c_estados;
    LOOP
      FETCH c_estados INTO v_registro;
      EXIT WHEN c_estados%NOTFOUND;
      v_resumen := v_resumen || CASE WHEN v_resumen IS NOT NULL THEN ' | ' END ||
                   v_registro.estado || ': ' || v_registro.total;
    END LOOP;
    CLOSE c_estados;
    RETURN NVL(v_resumen, 'Sin equipos registrados');
  END fn_resumen_inventario;

  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_tipo IN VARCHAR2, p_marca IN VARCHAR2,
                        p_modelo IN VARCHAR2, p_numero_serie IN VARCHAR2, p_fecha_compra IN DATE) IS
  BEGIN
    IF p_tipo IS NULL OR UPPER(p_tipo) NOT IN ('LAPTOP','ESCRITORIO','SERVIDOR','MONITOR',
                                               'IMPRESORA','RED','OTRO') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Tipo inválido. Use LAPTOP, ESCRITORIO, SERVIDOR, MONITOR, IMPRESORA, RED u OTRO.');
    END IF;
    pkg_utilidades.pr_validar_requerido(p_marca, 'marca');
    pkg_utilidades.pr_validar_requerido(p_modelo, 'modelo');
    pkg_utilidades.pr_validar_requerido(p_numero_serie, 'número de serie');
    IF p_fecha_compra IS NULL OR p_fecha_compra > SYSDATE THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'La fecha de compra es obligatoria y no puede ser futura.');
    END IF;

    IF p_id IS NULL THEN
      INSERT INTO equipo (tipo, marca, modelo, numero_serie, fecha_compra)
      VALUES (UPPER(p_tipo), TRIM(p_marca), TRIM(p_modelo), UPPER(TRIM(p_numero_serie)), TRUNC(p_fecha_compra))
      RETURNING id_equipo INTO p_id;
    ELSE
      UPDATE equipo
         SET tipo = UPPER(p_tipo),
             marca = TRIM(p_marca),
             modelo = TRIM(p_modelo),
             numero_serie = UPPER(TRIM(p_numero_serie)),
             fecha_compra = TRUNC(p_fecha_compra)
       WHERE id_equipo = p_id;
      IF SQL%ROWCOUNT = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El equipo con id ' || p_id || ' no existe.');
      END IF;
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Ya existe un equipo con el número de serie ' || UPPER(TRIM(p_numero_serie)) || '.');
  END pr_guardar;

  -- CURSOR 8: al dar de baja, libera los puestos de licencia instalados en el equipo
  PROCEDURE pr_cambiar_estado (p_id IN NUMBER, p_estado IN VARCHAR2) IS
    CURSOR c_licencias_equipo IS
      SELECT id_asig_licencia
        FROM asignacion_licencia
       WHERE id_equipo = p_id;
    v_actual   equipo.estado%TYPE;
    v_vigentes NUMBER;
    v_nuevo    equipo.estado%TYPE := UPPER(TRIM(p_estado));
  BEGIN
    BEGIN
      SELECT estado INTO v_actual FROM equipo WHERE id_equipo = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El equipo con id ' || p_id || ' no existe.');
    END;
    IF v_nuevo IS NULL OR v_nuevo NOT IN ('DISPONIBLE','REPARACION','BAJA') THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Solo puede cambiar a DISPONIBLE, REPARACION o BAJA. Use asignar/devolver para ASIGNADO.');
    END IF;
    IF v_actual = 'BAJA' THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla, 'El equipo está dado de baja y no puede reactivarse.');
    END IF;

    SELECT COUNT(*) INTO v_vigentes
      FROM asignacion_equipo
     WHERE id_equipo = p_id AND fecha_fin IS NULL;
    IF v_vigentes > 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'El equipo está asignado. Regístrelo como devuelto antes de cambiar su estado.');
    END IF;

    IF v_nuevo = 'BAJA' THEN
      FOR r IN c_licencias_equipo LOOP
        DELETE FROM asignacion_licencia WHERE id_asig_licencia = r.id_asig_licencia;
      END LOOP;
    END IF;
    UPDATE equipo SET estado = v_nuevo WHERE id_equipo = p_id;
  END pr_cambiar_estado;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM equipo WHERE id_equipo = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'El equipo con id ' || p_id || ' no existe.');
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'No se puede eliminar: el equipo tiene historial de asignaciones, licencias o tickets. Use dar de baja.');
  END pr_eliminar;

END pkg_equipo;
/

-- ---------------------------------------------------------------------
-- PAQUETE 7: PKG_LICENCIA  (RF-08 y RF-09)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_licencia AS
  -- Con p_id devuelve una licencia (incluye la clave). Con p_dias devuelve solo las que
  -- vencen en los próximos p_dias días (RF-09). Sin filtros devuelve todas.
  FUNCTION  fn_listar (p_id IN NUMBER, p_dias IN NUMBER) RETURN SYS_REFCURSOR;
  FUNCTION  fn_disponibles (p_id IN NUMBER) RETURN NUMBER;
  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_software IN VARCHAR2, p_proveedor IN VARCHAR2,
                        p_clave IN VARCHAR2, p_fecha_vencimiento IN DATE, p_cantidad IN NUMBER);
  PROCEDURE pr_eliminar (p_id IN NUMBER);
END pkg_licencia;
/

CREATE OR REPLACE PACKAGE BODY pkg_licencia AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  FUNCTION fn_listar (p_id IN NUMBER, p_dias IN NUMBER) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    IF p_id IS NOT NULL THEN
      OPEN v_cursor FOR
        SELECT u.*, l.clave
          FROM v_licencias_uso u
          JOIN licencia l ON l.id_licencia = u.id_licencia
         WHERE u.id_licencia = p_id;
    ELSE
      OPEN v_cursor FOR
        SELECT *
          FROM v_licencias_uso
         WHERE p_dias IS NULL OR dias_restantes BETWEEN 0 AND p_dias
         ORDER BY fecha_vencimiento;
    END IF;
    RETURN v_cursor;
  END fn_listar;

  -- CURSOR 9 (con parámetro): puestos libres de una licencia
  FUNCTION fn_disponibles (p_id IN NUMBER) RETURN NUMBER IS
    CURSOR c_uso (cp_id NUMBER) IS
      SELECT disponibles FROM v_licencias_uso WHERE id_licencia = cp_id;
    v_disponibles NUMBER;
  BEGIN
    OPEN c_uso(p_id);
    FETCH c_uso INTO v_disponibles;
    CLOSE c_uso;
    RETURN v_disponibles;
  END fn_disponibles;

  PROCEDURE pr_guardar (p_id IN OUT NUMBER, p_software IN VARCHAR2, p_proveedor IN VARCHAR2,
                        p_clave IN VARCHAR2, p_fecha_vencimiento IN DATE, p_cantidad IN NUMBER) IS
    v_asignadas NUMBER;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_software, 'software');
    pkg_utilidades.pr_validar_requerido(p_proveedor, 'proveedor');
    pkg_utilidades.pr_validar_requerido(p_clave, 'clave');
    IF p_fecha_vencimiento IS NULL THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion, 'La fecha de vencimiento es obligatoria.');
    END IF;
    IF p_cantidad IS NULL OR p_cantidad <= 0 OR p_cantidad <> TRUNC(p_cantidad) THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'La cantidad de puestos debe ser un entero mayor que cero.');
    END IF;

    IF p_id IS NULL THEN
      INSERT INTO licencia (software, proveedor, clave, fecha_vencimiento, cantidad)
      VALUES (TRIM(p_software), TRIM(p_proveedor), TRIM(p_clave), TRUNC(p_fecha_vencimiento), p_cantidad)
      RETURNING id_licencia INTO p_id;
    ELSE
      SELECT COUNT(*) INTO v_asignadas FROM asignacion_licencia WHERE id_licencia = p_id;
      IF p_cantidad < v_asignadas THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
          'Hay ' || v_asignadas || ' puestos asignados; la cantidad no puede ser menor.');
      END IF;
      UPDATE licencia
         SET software = TRIM(p_software),
             proveedor = TRIM(p_proveedor),
             clave = TRIM(p_clave),
             fecha_vencimiento = TRUNC(p_fecha_vencimiento),
             cantidad = p_cantidad
       WHERE id_licencia = p_id;
      IF SQL%ROWCOUNT = 0 THEN
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'La licencia con id ' || p_id || ' no existe.');
      END IF;
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion, 'Ya existe una licencia con esa clave.');
  END pr_guardar;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM licencia WHERE id_licencia = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe, 'La licencia con id ' || p_id || ' no existe.');
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_regla,
        'No se puede eliminar: la licencia tiene puestos asignados. Revóquelos primero.');
  END pr_eliminar;

END pkg_licencia;
/
