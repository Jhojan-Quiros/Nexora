-- =====================================================================
-- 04_paquetes_catalogos.sql
--   PKG_DEPARTAMENTO, PKG_TECNICO, PKG_EMPLEADO, PKG_EQUIPO, PKG_LICENCIA
-- Los procedimientos NO hacen COMMIT: la aplicación confirma o revierte.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PAQUETE 3: PKG_DEPARTAMENTO  (RF-01)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_departamento AS
  FUNCTION  fn_existe (p_id IN NUMBER) RETURN NUMBER;
  FUNCTION  fn_cantidad_empleados (p_id IN NUMBER) RETURN NUMBER;

  PROCEDURE pr_insertar   (p_nombre IN VARCHAR2, p_ubicacion IN VARCHAR2, p_id OUT NUMBER);
  PROCEDURE pr_actualizar (p_id IN NUMBER, p_nombre IN VARCHAR2, p_ubicacion IN VARCHAR2);
  PROCEDURE pr_desactivar (p_id IN NUMBER);
  PROCEDURE pr_activar    (p_id IN NUMBER);
  PROCEDURE pr_eliminar   (p_id IN NUMBER);
  PROCEDURE pr_obtener    (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_listar     (p_solo_activos IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_imprimir_resumen;
END pkg_departamento;
/

CREATE OR REPLACE PACKAGE BODY pkg_departamento AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  FUNCTION fn_existe (p_id IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total FROM departamento WHERE id_departamento = p_id;
    RETURN v_total;
  END fn_existe;

  FUNCTION fn_cantidad_empleados (p_id IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_total
      FROM empleado
     WHERE id_departamento = p_id
       AND activo = 'S';
    RETURN v_total;
  END fn_cantidad_empleados;

  PROCEDURE pr_insertar (p_nombre IN VARCHAR2, p_ubicacion IN VARCHAR2, p_id OUT NUMBER) IS
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_nombre, 'nombre');
    pkg_utilidades.pr_validar_requerido(p_ubicacion, 'ubicación');
    INSERT INTO departamento (nombre, ubicacion)
    VALUES (TRIM(p_nombre), TRIM(p_ubicacion))
    RETURNING id_departamento INTO p_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_validacion('Ya existe un departamento llamado "' || TRIM(p_nombre) || '".');
  END pr_insertar;

  PROCEDURE pr_actualizar (p_id IN NUMBER, p_nombre IN VARCHAR2, p_ubicacion IN VARCHAR2) IS
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_nombre, 'nombre');
    pkg_utilidades.pr_validar_requerido(p_ubicacion, 'ubicación');
    UPDATE departamento
       SET nombre = TRIM(p_nombre),
           ubicacion = TRIM(p_ubicacion)
     WHERE id_departamento = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Departamento', p_id);
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_validacion('Ya existe un departamento llamado "' || TRIM(p_nombre) || '".');
  END pr_actualizar;

  PROCEDURE pr_desactivar (p_id IN NUMBER) IS
    v_empleados NUMBER;
  BEGIN
    IF fn_existe(p_id) = 0 THEN
      pkg_utilidades.pr_error_no_existe('Departamento', p_id);
    END IF;
    v_empleados := fn_cantidad_empleados(p_id);
    IF v_empleados > 0 THEN
      pkg_utilidades.pr_error_regla('El departamento tiene ' || v_empleados ||
        ' empleado(s) activo(s). Reasígnelos o desactívelos primero.');
    END IF;
    UPDATE departamento SET activo = 'N' WHERE id_departamento = p_id;
  END pr_desactivar;

  PROCEDURE pr_activar (p_id IN NUMBER) IS
  BEGIN
    UPDATE departamento SET activo = 'S' WHERE id_departamento = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Departamento', p_id);
    END IF;
  END pr_activar;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM departamento WHERE id_departamento = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Departamento', p_id);
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error_regla('No se puede eliminar: el departamento tiene empleados registrados. Use desactivar.');
  END pr_eliminar;

  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT * FROM v_departamentos_resumen WHERE id_departamento = p_id;
  END pr_obtener;

  PROCEDURE pr_listar (p_solo_activos IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT *
        FROM v_departamentos_resumen
       WHERE NVL(p_solo_activos, 'N') = 'N' OR activo = 'S'
       ORDER BY nombre;
  END pr_listar;

  -- CURSOR 1: recorre el resumen de departamentos y lo imprime
  PROCEDURE pr_imprimir_resumen IS
    CURSOR c_departamentos IS
      SELECT nombre, ubicacion, activo, empleados_activos
        FROM v_departamentos_resumen
       ORDER BY nombre;
  BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD('DEPARTAMENTO', 32) || RPAD('UBICACIÓN', 32) || 'EMPLEADOS');
    FOR r IN c_departamentos LOOP
      DBMS_OUTPUT.PUT_LINE(RPAD(r.nombre || CASE WHEN r.activo = 'N' THEN ' (inactivo)' END, 32) ||
                           RPAD(r.ubicacion, 32) || r.empleados_activos);
    END LOOP;
  END pr_imprimir_resumen;

END pkg_departamento;
/

-- ---------------------------------------------------------------------
-- PAQUETE 4: PKG_TECNICO
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_tecnico AS
  FUNCTION  fn_tickets_activos (p_id_tecnico IN NUMBER) RETURN NUMBER;
  FUNCTION  fn_tecnico_menor_carga RETURN NUMBER;
  FUNCTION  fn_id_por_empleado (p_id_empleado IN NUMBER) RETURN NUMBER;

  PROCEDURE pr_insertar   (p_id_empleado IN NUMBER, p_especialidad IN VARCHAR2,
                           p_nivel IN VARCHAR2, p_id OUT NUMBER);
  PROCEDURE pr_actualizar (p_id IN NUMBER, p_especialidad IN VARCHAR2, p_nivel IN VARCHAR2);
  PROCEDURE pr_desactivar (p_id IN NUMBER, p_reasignados OUT NUMBER);
  PROCEDURE pr_desactivar_por_empleado (p_id_empleado IN NUMBER);
  PROCEDURE pr_activar    (p_id IN NUMBER);
  PROCEDURE pr_eliminar   (p_id IN NUMBER);
  PROCEDURE pr_obtener    (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_listar     (p_solo_activos IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);
END pkg_tecnico;
/

CREATE OR REPLACE PACKAGE BODY pkg_tecnico AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  PROCEDURE pr_validar_nivel (p_nivel IN VARCHAR2) IS
  BEGIN
    IF UPPER(p_nivel) NOT IN ('JUNIOR','INTERMEDIO','SENIOR') OR p_nivel IS NULL THEN
      pkg_utilidades.pr_error_validacion('Nivel inválido. Use JUNIOR, INTERMEDIO o SENIOR.');
    END IF;
  END pr_validar_nivel;

  FUNCTION fn_tickets_activos (p_id_tecnico IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_total
      FROM ticket
     WHERE id_tecnico = p_id_tecnico
       AND estado IN ('ABIERTO','EN_PROCESO');
    RETURN v_total;
  END fn_tickets_activos;

  -- CURSOR 2: técnicos activos ordenados por carga; devuelve el primero
  FUNCTION fn_tecnico_menor_carga RETURN NUMBER IS
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
  END fn_tecnico_menor_carga;

  FUNCTION fn_id_por_empleado (p_id_empleado IN NUMBER) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT id_tecnico INTO v_id FROM tecnico WHERE id_empleado = p_id_empleado;
    RETURN v_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END fn_id_por_empleado;

  PROCEDURE pr_insertar (p_id_empleado IN NUMBER, p_especialidad IN VARCHAR2,
                         p_nivel IN VARCHAR2, p_id OUT NUMBER) IS
    v_activo empleado.activo%TYPE;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_especialidad, 'especialidad');
    pr_validar_nivel(p_nivel);
    BEGIN
      SELECT activo INTO v_activo FROM empleado WHERE id_empleado = p_id_empleado;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error_no_existe('Empleado', p_id_empleado);
    END;
    IF v_activo = 'N' THEN
      pkg_utilidades.pr_error_regla('El empleado está inactivo y no puede ser técnico.');
    END IF;

    INSERT INTO tecnico (id_empleado, especialidad, nivel)
    VALUES (p_id_empleado, TRIM(p_especialidad), UPPER(p_nivel))
    RETURNING id_tecnico INTO p_id;

    -- Un empleado común que pasa a ser técnico cambia de rol
    UPDATE empleado SET rol = 'TECNICO'
     WHERE id_empleado = p_id_empleado AND rol = 'EMPLEADO';
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_validacion('Ese empleado ya está registrado como técnico.');
  END pr_insertar;

  PROCEDURE pr_actualizar (p_id IN NUMBER, p_especialidad IN VARCHAR2, p_nivel IN VARCHAR2) IS
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_especialidad, 'especialidad');
    pr_validar_nivel(p_nivel);
    UPDATE tecnico
       SET especialidad = TRIM(p_especialidad),
           nivel = UPPER(p_nivel)
     WHERE id_tecnico = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Técnico', p_id);
    END IF;
  END pr_actualizar;

  -- CURSOR 3: devuelve a la cola los tickets pendientes del técnico
  PROCEDURE pr_desactivar (p_id IN NUMBER, p_reasignados OUT NUMBER) IS
    CURSOR c_pendientes IS
      SELECT id_ticket
        FROM ticket
       WHERE id_tecnico = p_id
         AND estado IN ('ABIERTO','EN_PROCESO')
         FOR UPDATE OF id_tecnico, estado;
  BEGIN
    p_reasignados := 0;
    UPDATE tecnico SET activo = 'N' WHERE id_tecnico = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Técnico', p_id);
    END IF;
    FOR r IN c_pendientes LOOP
      UPDATE ticket
         SET id_tecnico = NULL,
             estado = 'ABIERTO'
       WHERE CURRENT OF c_pendientes;
      p_reasignados := p_reasignados + 1;
    END LOOP;
  END pr_desactivar;

  PROCEDURE pr_desactivar_por_empleado (p_id_empleado IN NUMBER) IS
    v_id_tecnico NUMBER;
    v_reasignados NUMBER;
  BEGIN
    v_id_tecnico := fn_id_por_empleado(p_id_empleado);
    IF v_id_tecnico IS NOT NULL THEN
      pr_desactivar(v_id_tecnico, v_reasignados);
    END IF;
  END pr_desactivar_por_empleado;

  PROCEDURE pr_activar (p_id IN NUMBER) IS
    v_activo_emp empleado.activo%TYPE;
  BEGIN
    BEGIN
      SELECT e.activo INTO v_activo_emp
        FROM tecnico t JOIN empleado e ON e.id_empleado = t.id_empleado
       WHERE t.id_tecnico = p_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error_no_existe('Técnico', p_id);
    END;
    IF v_activo_emp = 'N' THEN
      pkg_utilidades.pr_error_regla('Active primero al empleado asociado.');
    END IF;
    UPDATE tecnico SET activo = 'S' WHERE id_tecnico = p_id;
  END pr_activar;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM tecnico WHERE id_tecnico = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Técnico', p_id);
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error_regla('No se puede eliminar: el técnico tiene tickets o comentarios. Use desactivar.');
  END pr_eliminar;

  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_tecnicos_detalle WHERE id_tecnico = p_id;
  END pr_obtener;

  PROCEDURE pr_listar (p_solo_activos IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT *
        FROM v_tecnicos_detalle
       WHERE NVL(p_solo_activos, 'N') = 'N' OR activo = 'S'
       ORDER BY nombre_completo;
  END pr_listar;

END pkg_tecnico;
/

-- ---------------------------------------------------------------------
-- PAQUETE 5: PKG_EMPLEADO  (RF-01)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_empleado AS
  FUNCTION  fn_empleado_activo (p_id IN NUMBER) RETURN NUMBER;
  FUNCTION  fn_nombre (p_id IN NUMBER) RETURN VARCHAR2;

  PROCEDURE pr_insertar (p_id_departamento IN NUMBER, p_nombre IN VARCHAR2, p_correo IN VARCHAR2,
                         p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2, p_rol IN VARCHAR2,
                         p_id OUT NUMBER);
  PROCEDURE pr_actualizar (p_id IN NUMBER, p_id_departamento IN NUMBER, p_nombre IN VARCHAR2,
                           p_correo IN VARCHAR2, p_rol IN VARCHAR2);
  PROCEDURE pr_desactivar (p_id IN NUMBER);
  PROCEDURE pr_activar    (p_id IN NUMBER);
  PROCEDURE pr_eliminar   (p_id IN NUMBER);
  PROCEDURE pr_restablecer_contrasena (p_id IN NUMBER, p_nueva IN VARCHAR2);
  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_listar  (p_id_departamento IN NUMBER, p_solo_activos IN VARCHAR2,
                        p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_buscar  (p_texto IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);
END pkg_empleado;
/

CREATE OR REPLACE PACKAGE BODY pkg_empleado AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  PROCEDURE pr_validar_datos (p_id_departamento IN NUMBER, p_nombre IN VARCHAR2,
                              p_correo IN VARCHAR2, p_rol IN VARCHAR2) IS
    v_activo departamento.activo%TYPE;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_nombre, 'nombre completo');
    IF pkg_utilidades.fn_correo_valido(p_correo) = 0 THEN
      pkg_utilidades.pr_error_validacion('El correo "' || p_correo || '" no tiene un formato válido.');
    END IF;
    IF p_rol IS NULL OR UPPER(p_rol) NOT IN ('ADMIN','TECNICO','EMPLEADO') THEN
      pkg_utilidades.pr_error_validacion('Rol inválido. Use ADMIN, TECNICO o EMPLEADO.');
    END IF;
    BEGIN
      SELECT activo INTO v_activo FROM departamento WHERE id_departamento = p_id_departamento;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error_no_existe('Departamento', p_id_departamento);
    END;
    IF v_activo = 'N' THEN
      pkg_utilidades.pr_error_regla('El departamento está inactivo.');
    END IF;
  END pr_validar_datos;

  FUNCTION fn_empleado_activo (p_id IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total FROM empleado WHERE id_empleado = p_id AND activo = 'S';
    RETURN v_total;
  END fn_empleado_activo;

  FUNCTION fn_nombre (p_id IN NUMBER) RETURN VARCHAR2 IS
    v_nombre empleado.nombre_completo%TYPE;
  BEGIN
    SELECT nombre_completo INTO v_nombre FROM empleado WHERE id_empleado = p_id;
    RETURN v_nombre;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END fn_nombre;

  PROCEDURE pr_insertar (p_id_departamento IN NUMBER, p_nombre IN VARCHAR2, p_correo IN VARCHAR2,
                         p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2, p_rol IN VARCHAR2,
                         p_id OUT NUMBER) IS
  BEGIN
    pr_validar_datos(p_id_departamento, p_nombre, p_correo, p_rol);
    pkg_utilidades.pr_validar_requerido(p_usuario, 'usuario');
    IF pkg_utilidades.fn_contrasena_segura(p_contrasena) = 0 THEN
      pkg_utilidades.pr_error_validacion('La contraseña debe tener al menos 8 caracteres, letras y números.');
    END IF;

    INSERT INTO empleado (id_departamento, nombre_completo, correo, usuario, contrasena_hash, rol)
    VALUES (p_id_departamento, p_nombre, p_correo, p_usuario,
            pkg_utilidades.fn_hash_contrasena(p_usuario, p_contrasena), UPPER(p_rol))
    RETURNING id_empleado INTO p_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_validacion('El correo o el usuario ya están registrados.');
  END pr_insertar;

  PROCEDURE pr_actualizar (p_id IN NUMBER, p_id_departamento IN NUMBER, p_nombre IN VARCHAR2,
                           p_correo IN VARCHAR2, p_rol IN VARCHAR2) IS
  BEGIN
    pr_validar_datos(p_id_departamento, p_nombre, p_correo, p_rol);
    UPDATE empleado
       SET id_departamento = p_id_departamento,
           nombre_completo = p_nombre,
           correo = p_correo,
           rol = UPPER(p_rol)
     WHERE id_empleado = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Empleado', p_id);
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_validacion('El correo ya pertenece a otro empleado.');
  END pr_actualizar;

  -- CURSOR 4: cierra las asignaciones de equipo vigentes del empleado
  -- CURSOR 5: libera los puestos de licencia del empleado
  PROCEDURE pr_desactivar (p_id IN NUMBER) IS
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
  BEGIN
    IF fn_empleado_activo(p_id) = 0 THEN
      pkg_utilidades.pr_error_regla('El empleado no existe o ya está inactivo.');
    END IF;

    FOR r IN c_equipos LOOP
      UPDATE asignacion_equipo SET fecha_fin = SYSDATE WHERE CURRENT OF c_equipos;
    END LOOP;

    FOR r IN c_licencias LOOP
      DELETE FROM asignacion_licencia WHERE id_asig_licencia = r.id_asig_licencia;
    END LOOP;

    pkg_tecnico.pr_desactivar_por_empleado(p_id);

    UPDATE empleado SET activo = 'N' WHERE id_empleado = p_id;
  END pr_desactivar;

  PROCEDURE pr_activar (p_id IN NUMBER) IS
  BEGIN
    UPDATE empleado SET activo = 'S' WHERE id_empleado = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Empleado', p_id);
    END IF;
  END pr_activar;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM empleado WHERE id_empleado = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Empleado', p_id);
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error_regla('No se puede eliminar: el empleado tiene historial (tickets, equipos o licencias). Use desactivar.');
  END pr_eliminar;

  PROCEDURE pr_restablecer_contrasena (p_id IN NUMBER, p_nueva IN VARCHAR2) IS
  BEGIN
    IF pkg_utilidades.fn_contrasena_segura(p_nueva) = 0 THEN
      pkg_utilidades.pr_error_validacion('La contraseña debe tener al menos 8 caracteres, letras y números.');
    END IF;
    UPDATE empleado
       SET contrasena_hash = pkg_utilidades.fn_hash_contrasena(usuario, p_nueva)
     WHERE id_empleado = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Empleado', p_id);
    END IF;
  END pr_restablecer_contrasena;

  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_empleados_detalle WHERE id_empleado = p_id;
  END pr_obtener;

  PROCEDURE pr_listar (p_id_departamento IN NUMBER, p_solo_activos IN VARCHAR2,
                       p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT id_empleado, nombre_completo, correo, usuario, rol, departamento, activo
        FROM v_empleados_detalle
       WHERE (p_id_departamento IS NULL OR id_departamento = p_id_departamento)
         AND (NVL(p_solo_activos, 'N') = 'N' OR activo = 'S')
       ORDER BY nombre_completo;
  END pr_listar;

  PROCEDURE pr_buscar (p_texto IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
    v_patron VARCHAR2(130) := '%' || UPPER(TRIM(p_texto)) || '%';
  BEGIN
    OPEN p_cursor FOR
      SELECT id_empleado, nombre_completo, correo, usuario, rol, departamento, activo
        FROM v_empleados_detalle
       WHERE UPPER(nombre_completo) LIKE v_patron
          OR UPPER(correo) LIKE v_patron
          OR UPPER(usuario) LIKE v_patron
       ORDER BY nombre_completo;
  END pr_buscar;

END pkg_empleado;
/

-- ---------------------------------------------------------------------
-- PAQUETE 6: PKG_EQUIPO  (RF-02)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_equipo AS
  FUNCTION  fn_estado (p_id IN NUMBER) RETURN VARCHAR2;
  FUNCTION  fn_esta_asignado (p_id IN NUMBER) RETURN NUMBER;

  PROCEDURE pr_insertar (p_tipo IN VARCHAR2, p_marca IN VARCHAR2, p_modelo IN VARCHAR2,
                         p_numero_serie IN VARCHAR2, p_fecha_compra IN DATE, p_id OUT NUMBER);
  PROCEDURE pr_actualizar (p_id IN NUMBER, p_tipo IN VARCHAR2, p_marca IN VARCHAR2,
                           p_modelo IN VARCHAR2, p_numero_serie IN VARCHAR2, p_fecha_compra IN DATE);
  PROCEDURE pr_cambiar_estado (p_id IN NUMBER, p_estado IN VARCHAR2);
  PROCEDURE pr_dar_baja (p_id IN NUMBER);
  PROCEDURE pr_eliminar (p_id IN NUMBER);
  PROCEDURE pr_obtener  (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_listar   (p_estado IN VARCHAR2, p_tipo IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_resumen_inventario (p_resumen OUT VARCHAR2);
END pkg_equipo;
/

CREATE OR REPLACE PACKAGE BODY pkg_equipo AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  PROCEDURE pr_validar_datos (p_tipo IN VARCHAR2, p_marca IN VARCHAR2, p_modelo IN VARCHAR2,
                              p_numero_serie IN VARCHAR2, p_fecha_compra IN DATE) IS
  BEGIN
    IF p_tipo IS NULL OR UPPER(p_tipo) NOT IN ('LAPTOP','ESCRITORIO','SERVIDOR','MONITOR',
                                               'IMPRESORA','RED','OTRO') THEN
      pkg_utilidades.pr_error_validacion('Tipo inválido. Use LAPTOP, ESCRITORIO, SERVIDOR, MONITOR, IMPRESORA, RED u OTRO.');
    END IF;
    pkg_utilidades.pr_validar_requerido(p_marca, 'marca');
    pkg_utilidades.pr_validar_requerido(p_modelo, 'modelo');
    pkg_utilidades.pr_validar_requerido(p_numero_serie, 'número de serie');
    IF p_fecha_compra IS NULL OR p_fecha_compra > SYSDATE THEN
      pkg_utilidades.pr_error_validacion('La fecha de compra es obligatoria y no puede ser futura.');
    END IF;
  END pr_validar_datos;

  FUNCTION fn_estado (p_id IN NUMBER) RETURN VARCHAR2 IS
    v_estado equipo.estado%TYPE;
  BEGIN
    SELECT estado INTO v_estado FROM equipo WHERE id_equipo = p_id;
    RETURN v_estado;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END fn_estado;

  FUNCTION fn_esta_asignado (p_id IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total
      FROM asignacion_equipo
     WHERE id_equipo = p_id AND fecha_fin IS NULL;
    RETURN v_total;
  END fn_esta_asignado;

  PROCEDURE pr_insertar (p_tipo IN VARCHAR2, p_marca IN VARCHAR2, p_modelo IN VARCHAR2,
                         p_numero_serie IN VARCHAR2, p_fecha_compra IN DATE, p_id OUT NUMBER) IS
  BEGIN
    pr_validar_datos(p_tipo, p_marca, p_modelo, p_numero_serie, p_fecha_compra);
    INSERT INTO equipo (tipo, marca, modelo, numero_serie, fecha_compra)
    VALUES (UPPER(p_tipo), TRIM(p_marca), TRIM(p_modelo), UPPER(TRIM(p_numero_serie)), TRUNC(p_fecha_compra))
    RETURNING id_equipo INTO p_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_validacion('Ya existe un equipo con el número de serie ' || UPPER(p_numero_serie) || '.');
  END pr_insertar;

  PROCEDURE pr_actualizar (p_id IN NUMBER, p_tipo IN VARCHAR2, p_marca IN VARCHAR2,
                           p_modelo IN VARCHAR2, p_numero_serie IN VARCHAR2, p_fecha_compra IN DATE) IS
  BEGIN
    pr_validar_datos(p_tipo, p_marca, p_modelo, p_numero_serie, p_fecha_compra);
    UPDATE equipo
       SET tipo = UPPER(p_tipo),
           marca = TRIM(p_marca),
           modelo = TRIM(p_modelo),
           numero_serie = UPPER(TRIM(p_numero_serie)),
           fecha_compra = TRUNC(p_fecha_compra)
     WHERE id_equipo = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Equipo', p_id);
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_validacion('Ya existe otro equipo con el número de serie ' || UPPER(p_numero_serie) || '.');
  END pr_actualizar;

  -- Solo DISPONIBLE <-> REPARACION. ASIGNADO lo maneja la asignación y BAJA pr_dar_baja.
  PROCEDURE pr_cambiar_estado (p_id IN NUMBER, p_estado IN VARCHAR2) IS
    v_actual equipo.estado%TYPE;
  BEGIN
    v_actual := fn_estado(p_id);
    IF v_actual IS NULL THEN
      pkg_utilidades.pr_error_no_existe('Equipo', p_id);
    END IF;
    IF UPPER(p_estado) NOT IN ('DISPONIBLE','REPARACION') OR p_estado IS NULL THEN
      pkg_utilidades.pr_error_validacion('Solo puede cambiar a DISPONIBLE o REPARACION. Use asignar/devolver o dar de baja.');
    END IF;
    IF v_actual = 'ASIGNADO' THEN
      pkg_utilidades.pr_error_regla('El equipo está asignado. Regístrelo como devuelto antes de cambiar su estado.');
    ELSIF v_actual = 'BAJA' THEN
      pkg_utilidades.pr_error_regla('El equipo está dado de baja y no puede reactivarse.');
    END IF;
    UPDATE equipo SET estado = UPPER(p_estado) WHERE id_equipo = p_id;
  END pr_cambiar_estado;

  PROCEDURE pr_dar_baja (p_id IN NUMBER) IS
  BEGIN
    IF fn_estado(p_id) IS NULL THEN
      pkg_utilidades.pr_error_no_existe('Equipo', p_id);
    END IF;
    IF fn_esta_asignado(p_id) > 0 THEN
      pkg_utilidades.pr_error_regla('El equipo está asignado. Regístrelo como devuelto antes de darlo de baja.');
    END IF;
    UPDATE equipo SET estado = 'BAJA' WHERE id_equipo = p_id;
  END pr_dar_baja;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM equipo WHERE id_equipo = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Equipo', p_id);
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error_regla('No se puede eliminar: el equipo tiene historial de asignaciones o tickets. Use dar de baja.');
  END pr_eliminar;

  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_equipos_detalle WHERE id_equipo = p_id;
  END pr_obtener;

  PROCEDURE pr_listar (p_estado IN VARCHAR2, p_tipo IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT id_equipo, tipo, marca, modelo, numero_serie, estado, fecha_compra, asignado_a
        FROM v_equipos_detalle
       WHERE (p_estado IS NULL OR estado = UPPER(p_estado))
         AND (p_tipo IS NULL OR tipo = UPPER(p_tipo))
       ORDER BY tipo, marca, modelo;
  END pr_listar;

  -- CURSOR 6: cuenta equipos por estado y arma un texto resumen
  PROCEDURE pr_resumen_inventario (p_resumen OUT VARCHAR2) IS
    CURSOR c_estados IS
      SELECT estado, COUNT(*) AS total
        FROM equipo
       GROUP BY estado
       ORDER BY estado;
    v_registro c_estados%ROWTYPE;
  BEGIN
    p_resumen := NULL;
    OPEN c_estados;
    LOOP
      FETCH c_estados INTO v_registro;
      EXIT WHEN c_estados%NOTFOUND;
      p_resumen := p_resumen || CASE WHEN p_resumen IS NOT NULL THEN ' | ' END ||
                   v_registro.estado || ': ' || v_registro.total;
    END LOOP;
    CLOSE c_estados;
    p_resumen := NVL(p_resumen, 'Sin equipos registrados');
  END pr_resumen_inventario;

END pkg_equipo;
/

-- ---------------------------------------------------------------------
-- PAQUETE 7: PKG_LICENCIA  (RF-08 y RF-09; la interfaz se completa en la semana 11)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_licencia AS
  FUNCTION  fn_disponibles (p_id IN NUMBER) RETURN NUMBER;
  FUNCTION  fn_dias_para_vencer (p_id IN NUMBER) RETURN NUMBER;
  FUNCTION  fn_vencidas_en_uso RETURN NUMBER;

  PROCEDURE pr_insertar (p_software IN VARCHAR2, p_proveedor IN VARCHAR2, p_clave IN VARCHAR2,
                         p_fecha_vencimiento IN DATE, p_cantidad IN NUMBER, p_id OUT NUMBER);
  PROCEDURE pr_actualizar (p_id IN NUMBER, p_software IN VARCHAR2, p_proveedor IN VARCHAR2,
                           p_clave IN VARCHAR2, p_fecha_vencimiento IN DATE, p_cantidad IN NUMBER);
  PROCEDURE pr_eliminar (p_id IN NUMBER);
  PROCEDURE pr_obtener  (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_listar   (p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_por_vencer (p_dias IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_imprimir_alertas (p_dias IN NUMBER DEFAULT 30);
END pkg_licencia;
/

CREATE OR REPLACE PACKAGE BODY pkg_licencia AS

  e_tiene_hijos EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_hijos, -2292);

  PROCEDURE pr_validar_datos (p_software IN VARCHAR2, p_proveedor IN VARCHAR2, p_clave IN VARCHAR2,
                              p_fecha_vencimiento IN DATE, p_cantidad IN NUMBER) IS
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_software, 'software');
    pkg_utilidades.pr_validar_requerido(p_proveedor, 'proveedor');
    pkg_utilidades.pr_validar_requerido(p_clave, 'clave');
    IF p_fecha_vencimiento IS NULL THEN
      pkg_utilidades.pr_error_validacion('La fecha de vencimiento es obligatoria.');
    END IF;
    IF p_cantidad IS NULL OR p_cantidad <= 0 OR p_cantidad <> TRUNC(p_cantidad) THEN
      pkg_utilidades.pr_error_validacion('La cantidad de puestos debe ser un entero mayor que cero.');
    END IF;
  END pr_validar_datos;

  FUNCTION fn_disponibles (p_id IN NUMBER) RETURN NUMBER IS
    v_disponibles NUMBER;
  BEGIN
    SELECT disponibles INTO v_disponibles FROM v_licencias_uso WHERE id_licencia = p_id;
    RETURN v_disponibles;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END fn_disponibles;

  FUNCTION fn_dias_para_vencer (p_id IN NUMBER) RETURN NUMBER IS
    v_dias NUMBER;
  BEGIN
    SELECT TRUNC(fecha_vencimiento) - TRUNC(SYSDATE) INTO v_dias
      FROM licencia WHERE id_licencia = p_id;
    RETURN v_dias;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END fn_dias_para_vencer;

  -- CURSOR 7: suma los puestos que siguen asignados en licencias vencidas
  FUNCTION fn_vencidas_en_uso RETURN NUMBER IS
    CURSOR c_vencidas IS
      SELECT id_licencia, asignadas
        FROM v_licencias_uso
       WHERE estado_licencia = 'VENCIDA'
         AND asignadas > 0;
    v_total NUMBER := 0;
  BEGIN
    FOR r IN c_vencidas LOOP
      v_total := v_total + r.asignadas;
    END LOOP;
    RETURN v_total;
  END fn_vencidas_en_uso;

  PROCEDURE pr_insertar (p_software IN VARCHAR2, p_proveedor IN VARCHAR2, p_clave IN VARCHAR2,
                         p_fecha_vencimiento IN DATE, p_cantidad IN NUMBER, p_id OUT NUMBER) IS
  BEGIN
    pr_validar_datos(p_software, p_proveedor, p_clave, p_fecha_vencimiento, p_cantidad);
    INSERT INTO licencia (software, proveedor, clave, fecha_vencimiento, cantidad)
    VALUES (TRIM(p_software), TRIM(p_proveedor), TRIM(p_clave), TRUNC(p_fecha_vencimiento), p_cantidad)
    RETURNING id_licencia INTO p_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_validacion('Ya existe una licencia con esa clave.');
  END pr_insertar;

  PROCEDURE pr_actualizar (p_id IN NUMBER, p_software IN VARCHAR2, p_proveedor IN VARCHAR2,
                           p_clave IN VARCHAR2, p_fecha_vencimiento IN DATE, p_cantidad IN NUMBER) IS
    v_asignadas NUMBER;
  BEGIN
    pr_validar_datos(p_software, p_proveedor, p_clave, p_fecha_vencimiento, p_cantidad);
    SELECT COUNT(*) INTO v_asignadas FROM asignacion_licencia WHERE id_licencia = p_id;
    IF p_cantidad < v_asignadas THEN
      pkg_utilidades.pr_error_regla('Hay ' || v_asignadas || ' puestos asignados; la cantidad no puede ser menor.');
    END IF;
    UPDATE licencia
       SET software = TRIM(p_software),
           proveedor = TRIM(p_proveedor),
           clave = TRIM(p_clave),
           fecha_vencimiento = TRUNC(p_fecha_vencimiento),
           cantidad = p_cantidad
     WHERE id_licencia = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Licencia', p_id);
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      pkg_utilidades.pr_error_validacion('Ya existe otra licencia con esa clave.');
  END pr_actualizar;

  PROCEDURE pr_eliminar (p_id IN NUMBER) IS
  BEGIN
    DELETE FROM licencia WHERE id_licencia = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      pkg_utilidades.pr_error_no_existe('Licencia', p_id);
    END IF;
  EXCEPTION
    WHEN e_tiene_hijos THEN
      pkg_utilidades.pr_error_regla('No se puede eliminar: la licencia tiene puestos asignados. Revóquelos primero.');
  END pr_eliminar;

  PROCEDURE pr_obtener (p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT u.*, l.clave
        FROM v_licencias_uso u
        JOIN licencia l ON l.id_licencia = u.id_licencia
       WHERE u.id_licencia = p_id;
  END pr_obtener;

  PROCEDURE pr_listar (p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_licencias_uso ORDER BY fecha_vencimiento;
  END pr_listar;

  PROCEDURE pr_por_vencer (p_dias IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT *
        FROM v_licencias_uso
       WHERE dias_restantes BETWEEN 0 AND NVL(p_dias, 30)
       ORDER BY dias_restantes;
  END pr_por_vencer;

  -- CURSOR 8 (con parámetro): imprime las alertas de vencimiento
  PROCEDURE pr_imprimir_alertas (p_dias IN NUMBER DEFAULT 30) IS
    CURSOR c_alertas (cp_dias NUMBER) IS
      SELECT software, proveedor, fecha_vencimiento, dias_restantes, asignadas, estado_licencia
        FROM v_licencias_uso
       WHERE dias_restantes <= cp_dias
       ORDER BY dias_restantes;
    v_hay BOOLEAN := FALSE;
  BEGIN
    FOR r IN c_alertas(NVL(p_dias, 30)) LOOP
      v_hay := TRUE;
      DBMS_OUTPUT.PUT_LINE('[' || r.estado_licencia || '] ' || r.software || ' (' || r.proveedor ||
                           ') vence el ' || TO_CHAR(r.fecha_vencimiento, 'DD/MM/YYYY') ||
                           ' - días: ' || r.dias_restantes || ' - puestos en uso: ' || r.asignadas);
    END LOOP;
    IF NOT v_hay THEN
      DBMS_OUTPUT.PUT_LINE('No hay licencias que venzan en los próximos ' || p_dias || ' días.');
    END IF;
  END pr_imprimir_alertas;

END pkg_licencia;
/
