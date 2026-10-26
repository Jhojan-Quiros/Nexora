-- =====================================================================
-- 03_paquetes_base.sql
--   PKG_UTILIDADES : validaciones, hash y manejo de errores
--   PKG_SEGURIDAD  : inicio de sesión y contraseñas (RF-12)
-- Códigos de error de negocio:
--   -20001 validación | -20002 no existe | -20003 regla de negocio
-- =====================================================================

-- ---------------------------------------------------------------------
-- PAQUETE 1: PKG_UTILIDADES
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_utilidades AS
  c_err_validacion CONSTANT PLS_INTEGER := -20001;
  c_err_no_existe  CONSTANT PLS_INTEGER := -20002;
  c_err_regla      CONSTANT PLS_INTEGER := -20003;

  FUNCTION fn_hash_contrasena (p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2) RETURN VARCHAR2;
  FUNCTION fn_correo_valido   (p_correo IN VARCHAR2) RETURN NUMBER;
  FUNCTION fn_contrasena_segura (p_contrasena IN VARCHAR2) RETURN NUMBER;

  PROCEDURE pr_validar_requerido (p_valor IN VARCHAR2, p_campo IN VARCHAR2);
  PROCEDURE pr_error_validacion  (p_mensaje IN VARCHAR2);
  PROCEDURE pr_error_no_existe   (p_entidad IN VARCHAR2, p_id IN NUMBER);
  PROCEDURE pr_error_regla       (p_mensaje IN VARCHAR2);
END pkg_utilidades;
/

CREATE OR REPLACE PACKAGE BODY pkg_utilidades AS

  -- SHA-256 de "usuario:contraseña". El usuario actúa como sal.
  FUNCTION fn_hash_contrasena (p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2) RETURN VARCHAR2 IS
    v_hash VARCHAR2(64);
  BEGIN
    SELECT LOWER(RAWTOHEX(STANDARD_HASH(LOWER(TRIM(p_usuario)) || ':' || p_contrasena, 'SHA256')))
      INTO v_hash
      FROM dual;
    RETURN v_hash;
  END fn_hash_contrasena;

  FUNCTION fn_correo_valido (p_correo IN VARCHAR2) RETURN NUMBER IS
  BEGIN
    IF p_correo IS NOT NULL
       AND REGEXP_LIKE(TRIM(p_correo), '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
      RETURN 1;
    END IF;
    RETURN 0;
  END fn_correo_valido;

  -- Mínimo 8 caracteres, al menos una letra y un número
  FUNCTION fn_contrasena_segura (p_contrasena IN VARCHAR2) RETURN NUMBER IS
  BEGIN
    IF LENGTH(p_contrasena) >= 8
       AND REGEXP_LIKE(p_contrasena, '[0-9]')
       AND REGEXP_LIKE(p_contrasena, '[A-Za-z]') THEN
      RETURN 1;
    END IF;
    RETURN 0;
  END fn_contrasena_segura;

  PROCEDURE pr_validar_requerido (p_valor IN VARCHAR2, p_campo IN VARCHAR2) IS
  BEGIN
    IF TRIM(p_valor) IS NULL THEN
      pr_error_validacion('El campo "' || p_campo || '" es obligatorio.');
    END IF;
  END pr_validar_requerido;

  PROCEDURE pr_error_validacion (p_mensaje IN VARCHAR2) IS
  BEGIN
    RAISE_APPLICATION_ERROR(c_err_validacion, p_mensaje);
  END pr_error_validacion;

  PROCEDURE pr_error_no_existe (p_entidad IN VARCHAR2, p_id IN NUMBER) IS
  BEGIN
    RAISE_APPLICATION_ERROR(c_err_no_existe, p_entidad || ' con id ' || NVL(TO_CHAR(p_id), '(nulo)') || ' no existe.');
  END pr_error_no_existe;

  PROCEDURE pr_error_regla (p_mensaje IN VARCHAR2) IS
  BEGIN
    RAISE_APPLICATION_ERROR(c_err_regla, p_mensaje);
  END pr_error_regla;

END pkg_utilidades;
/

-- ---------------------------------------------------------------------
-- PAQUETE 2: PKG_SEGURIDAD
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_seguridad AS
  FUNCTION  fn_validar_login (p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2) RETURN NUMBER;
  FUNCTION  fn_tiene_rol     (p_id_empleado IN NUMBER, p_rol IN VARCHAR2) RETURN NUMBER;
  PROCEDURE pr_iniciar_sesion (p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2,
                               p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_cambiar_contrasena (p_id_empleado IN NUMBER, p_actual IN VARCHAR2,
                                   p_nueva IN VARCHAR2);
END pkg_seguridad;
/

CREATE OR REPLACE PACKAGE BODY pkg_seguridad AS

  -- Devuelve el id del empleado si las credenciales son válidas, o 0
  FUNCTION fn_validar_login (p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2) RETURN NUMBER IS
    v_id   empleado.id_empleado%TYPE;
    v_hash empleado.contrasena_hash%TYPE;
  BEGIN
    v_hash := pkg_utilidades.fn_hash_contrasena(p_usuario, p_contrasena);
    SELECT id_empleado
      INTO v_id
      FROM empleado
     WHERE usuario = LOWER(TRIM(p_usuario))
       AND contrasena_hash = v_hash
       AND activo = 'S';
    RETURN v_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END fn_validar_login;

  FUNCTION fn_tiene_rol (p_id_empleado IN NUMBER, p_rol IN VARCHAR2) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_total
      FROM empleado
     WHERE id_empleado = p_id_empleado
       AND rol = UPPER(p_rol)
       AND activo = 'S';
    RETURN v_total;
  END fn_tiene_rol;

  PROCEDURE pr_iniciar_sesion (p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2,
                               p_cursor OUT SYS_REFCURSOR) IS
    v_id NUMBER;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_usuario, 'usuario');
    pkg_utilidades.pr_validar_requerido(p_contrasena, 'contraseña');
    v_id := fn_validar_login(p_usuario, p_contrasena);
    IF v_id = 0 THEN
      pkg_utilidades.pr_error_validacion('Usuario o contraseña incorrectos, o el usuario está inactivo.');
    END IF;

    OPEN p_cursor FOR
      SELECT e.id_empleado, e.nombre_completo, e.usuario, e.rol,
             e.id_departamento, d.nombre AS departamento, t.id_tecnico
        FROM empleado e
        JOIN departamento d ON d.id_departamento = e.id_departamento
        LEFT JOIN tecnico t ON t.id_empleado = e.id_empleado AND t.activo = 'S'
       WHERE e.id_empleado = v_id;
  END pr_iniciar_sesion;

  PROCEDURE pr_cambiar_contrasena (p_id_empleado IN NUMBER, p_actual IN VARCHAR2,
                                   p_nueva IN VARCHAR2) IS
    v_usuario empleado.usuario%TYPE;
    v_hash    empleado.contrasena_hash%TYPE;
  BEGIN
    BEGIN
      SELECT usuario, contrasena_hash
        INTO v_usuario, v_hash
        FROM empleado
       WHERE id_empleado = p_id_empleado;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pkg_utilidades.pr_error_no_existe('Empleado', p_id_empleado);
    END;

    IF v_hash <> pkg_utilidades.fn_hash_contrasena(v_usuario, p_actual) THEN
      pkg_utilidades.pr_error_validacion('La contraseña actual no es correcta.');
    END IF;
    IF pkg_utilidades.fn_contrasena_segura(p_nueva) = 0 THEN
      pkg_utilidades.pr_error_validacion('La nueva contraseña debe tener al menos 8 caracteres, letras y números.');
    END IF;

    UPDATE empleado
       SET contrasena_hash = pkg_utilidades.fn_hash_contrasena(v_usuario, p_nueva)
     WHERE id_empleado = p_id_empleado;
  END pr_cambiar_contrasena;

END pkg_seguridad;
/
