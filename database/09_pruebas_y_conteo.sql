-- =====================================================================
-- 09_pruebas_y_conteo.sql
-- Pruebas rápidas desde SQL Developer (F5 - Ejecutar script) y conteo
-- de objetos programados para la rúbrica.
-- =====================================================================
SET SERVEROUTPUT ON

-- 1) Funciones escalares
BEGIN
  DBMS_OUTPUT.PUT_LINE('Inventario: ' || pkg_equipo.fn_resumen_inventario);
  DBMS_OUTPUT.PUT_LINE('Promedio de resolución (h): ' || pkg_ticket.fn_promedio_resolucion);
  DBMS_OUTPUT.PUT_LINE('Técnico con menor carga: ' || pkg_tecnico.fn_menor_carga);
  DBMS_OUTPUT.PUT_LINE('Puestos libres de la licencia 1: ' || pkg_licencia.fn_disponibles(1));
  DBMS_OUTPUT.PUT_LINE('Hash de prueba: ' || pkg_utilidades.fn_hash_contrasena('admin', 'Admin2026'));
END;
/

-- 2) Reglas de negocio: cada bloque DEBE fallar con un mensaje controlado
BEGIN
  pkg_equipo.pr_cambiar_estado(1, 'BAJA');  -- equipo asignado
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK regla -> ' || SQLERRM);
END;
/
BEGIN
  pkg_ticket.pr_cambiar_estado(3, 'ABIERTO');  -- CERRADO -> ABIERTO no permitido
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK regla -> ' || SQLERRM);
END;
/
DECLARE v_id NUMBER;
BEGIN
  pkg_empleado.pr_guardar(v_id, 1, 'Prueba', 'correo-malo', 'prueba', 'abc', 'EMPLEADO');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK regla -> ' || SQLERRM);
END;
/
DECLARE v_id NUMBER;
BEGIN
  pkg_asignacion_licencia.pr_asignar(1, 5, 1, v_id);  -- empleado y equipo a la vez
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK regla -> ' || SQLERRM);
END;
/
ROLLBACK;

-- 3) Cursores de referencia, como los consume la aplicación
VARIABLE rc REFCURSOR
EXEC :rc := pkg_ticket.fn_listar(NULL, 'EN_PROCESO', NULL, NULL, NULL, 'N')
PRINT rc
EXEC :rc := pkg_asignacion_licencia.fn_listar(NULL, NULL, NULL)
PRINT rc
EXEC :rc := pkg_reportes.fn_reporte('TECNICOS')
PRINT rc
EXEC :rc := pkg_reportes.fn_reporte('LICENCIAS_VENCER', 30)
PRINT rc

-- 4) Conteo de objetos programados -----------------------------------
-- Objetos del esquema
SELECT object_type, COUNT(*) AS total
  FROM user_objects
 WHERE object_type IN ('TABLE','VIEW','PACKAGE','PACKAGE BODY','TRIGGER','PROCEDURE','FUNCTION')
 GROUP BY object_type
 ORDER BY object_type;

-- Procedimientos y funciones dentro de los paquetes (esperado: 27 y 20)
SELECT CASE WHEN EXISTS (SELECT 1 FROM user_arguments a
                          WHERE a.package_name = p.object_name
                            AND a.object_name  = p.procedure_name
                            AND a.subprogram_id = p.subprogram_id
                            AND a.position = 0)
            THEN 'FUNCION' ELSE 'PROCEDIMIENTO' END AS tipo,
       COUNT(*) AS total
  FROM user_procedures p
 WHERE p.object_type = 'PACKAGE'
   AND p.procedure_name IS NOT NULL
 GROUP BY CASE WHEN EXISTS (SELECT 1 FROM user_arguments a
                             WHERE a.package_name = p.object_name
                               AND a.object_name  = p.procedure_name
                               AND a.subprogram_id = p.subprogram_id
                               AND a.position = 0)
               THEN 'FUNCION' ELSE 'PROCEDIMIENTO' END;

-- Cursores explícitos declarados en los cuerpos de los paquetes
SELECT name AS paquete, COUNT(*) AS cursores
  FROM user_source
 WHERE type = 'PACKAGE BODY'
   AND REGEXP_LIKE(text, '^\s*CURSOR\s+c_', 'i')
 GROUP BY ROLLUP(name)
 ORDER BY name;

-- Objetos inválidos (debe devolver 0 filas)
SELECT object_name, object_type FROM user_objects WHERE status = 'INVALID';
