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

  FUNCTION  fn_hash_contrasena   (p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2) RETURN VARCHAR2;
  FUNCTION  fn_correo_valido     (p_correo IN VARCHAR2) RETURN NUMBER;
  FUNCTION  fn_contrasena_segura (p_contrasena IN VARCHAR2) RETURN NUMBER;

  PROCEDURE pr_validar_requerido (p_valor IN VARCHAR2, p_campo IN VARCHAR2);
  PROCEDURE pr_error             (p_codigo IN PLS_INTEGER, p_mensaje IN VARCHAR2);
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
      pr_error(c_err_validacion, 'El campo "' || p_campo || '" es obligatorio.');
    END IF;
  END pr_validar_requerido;

  -- Punto único para lanzar errores de negocio con su código
  PROCEDURE pr_error (p_codigo IN PLS_INTEGER, p_mensaje IN VARCHAR2) IS
  BEGIN
    RAISE_APPLICATION_ERROR(p_codigo, p_mensaje);
  END pr_error;

END pkg_utilidades;
/

-- ---------------------------------------------------------------------
-- PAQUETE 2: PKG_SEGURIDAD  (RF-12)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_seguridad AS
  FUNCTION  fn_iniciar_sesion (p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2) RETURN SYS_REFCURSOR;
  PROCEDURE pr_cambiar_contrasena (p_id_empleado IN NUMBER, p_actual IN VARCHAR2,
                                   p_nueva IN VARCHAR2);
END pkg_seguridad;
/

CREATE OR REPLACE PACKAGE BODY pkg_seguridad AS

  -- CURSOR 1: valida las credenciales y devuelve los datos de la sesión
  FUNCTION fn_iniciar_sesion (p_usuario IN VARCHAR2, p_contrasena IN VARCHAR2) RETURN SYS_REFCURSOR IS
    CURSOR c_credenciales (cp_usuario VARCHAR2, cp_hash VARCHAR2) IS
      SELECT id_empleado
        FROM empleado
       WHERE usuario = cp_usuario
         AND contrasena_hash = cp_hash
         AND activo = 'S';
    v_id     empleado.id_empleado%TYPE;
    v_cursor SYS_REFCURSOR;
  BEGIN
    pkg_utilidades.pr_validar_requerido(p_usuario, 'usuario');
    pkg_utilidades.pr_validar_requerido(p_contrasena, 'contraseña');

    OPEN c_credenciales(LOWER(TRIM(p_usuario)),
                        pkg_utilidades.fn_hash_contrasena(p_usuario, p_contrasena));
    FETCH c_credenciales INTO v_id;
    IF c_credenciales%NOTFOUND THEN
      CLOSE c_credenciales;
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'Usuario o contraseña incorrectos, o el usuario está inactivo.');
    END IF;
    CLOSE c_credenciales;

    OPEN v_cursor FOR
      SELECT e.id_empleado, e.nombre_completo, e.usuario, e.rol,
             e.id_departamento, d.nombre AS departamento, t.id_tecnico
        FROM empleado e
        JOIN departamento d ON d.id_departamento = e.id_departamento
        LEFT JOIN tecnico t ON t.id_empleado = e.id_empleado AND t.activo = 'S'
       WHERE e.id_empleado = v_id;
    RETURN v_cursor;
  END fn_iniciar_sesion;

  -- Con p_actual = NULL el administrador restablece la contraseña sin conocer la anterior
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
        pkg_utilidades.pr_error(pkg_utilidades.c_err_no_existe,
          'El empleado con id ' || p_id_empleado || ' no existe.');
    END;

    IF p_actual IS NOT NULL AND v_hash <> pkg_utilidades.fn_hash_contrasena(v_usuario, p_actual) THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion, 'La contraseña actual no es correcta.');
    END IF;
    IF pkg_utilidades.fn_contrasena_segura(p_nueva) = 0 THEN
      pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
        'La nueva contraseña debe tener al menos 8 caracteres, letras y números.');
    END IF;

    UPDATE empleado
       SET contrasena_hash = pkg_utilidades.fn_hash_contrasena(v_usuario, p_nueva)
     WHERE id_empleado = p_id_empleado;
  END pr_cambiar_contrasena;

END pkg_seguridad;
/
