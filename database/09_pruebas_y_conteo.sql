-- =====================================================================
-- 09_pruebas_y_conteo.sql
-- Pruebas rápidas desde SQL Developer (F5 - Ejecutar script) y conteo
-- de objetos programados para la rúbrica.
-- =====================================================================
SET SERVEROUTPUT ON

-- 1) Reportes impresos con cursores
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- Departamentos ---');
  pkg_departamento.pr_imprimir_resumen;
  DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Carga por técnico ---');
  pkg_reportes.pr_imprimir_tickets_por_tecnico;
  DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Equipos por departamento ---');
  pkg_reportes.pr_imprimir_equipos_departamento;
  DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Alertas de licencias (30 días) ---');
  pkg_licencia.pr_imprimir_alertas(30);
END;
/

-- 2) Funciones
DECLARE
  v_resumen VARCHAR2(400);
BEGIN
  pkg_equipo.pr_resumen_inventario(v_resumen);
  DBMS_OUTPUT.PUT_LINE('Inventario: ' || v_resumen);
  DBMS_OUTPUT.PUT_LINE('Promedio de resolución (h): ' || pkg_ticket.fn_promedio_resolucion);
  DBMS_OUTPUT.PUT_LINE('Departamento con más tickets: ' || pkg_reportes.fn_departamento_mas_tickets);
  DBMS_OUTPUT.PUT_LINE('Técnico con menor carga: ' || pkg_tecnico.fn_tecnico_menor_carga);
  DBMS_OUTPUT.PUT_LINE('Login admin válido (id): ' || pkg_seguridad.fn_validar_login('admin', 'Admin2026'));
  DBMS_OUTPUT.PUT_LINE('Login con clave errónea: ' || pkg_seguridad.fn_validar_login('admin', 'xxxx'));
END;
/

-- 3) Reglas de negocio: cada bloque DEBE fallar con un mensaje controlado
BEGIN
  pkg_equipo.pr_dar_baja(1);  -- equipo asignado
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
  pkg_empleado.pr_insertar(1, 'Prueba', 'correo-malo', 'prueba', 'abc', 'EMPLEADO', v_id);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK regla -> ' || SQLERRM);
END;
/
ROLLBACK;

-- 4) Cursor de referencia, como lo consume la aplicación
VARIABLE rc REFCURSOR
EXEC pkg_ticket.pr_filtrar('EN_PROCESO', NULL, NULL, NULL, 'N', :rc)
PRINT rc

-- 5) Conteo de objetos programados -----------------------------------
-- Objetos del esquema
SELECT object_type, COUNT(*) AS total
  FROM user_objects
 WHERE object_type IN ('TABLE','VIEW','PACKAGE','PACKAGE BODY','TRIGGER','PROCEDURE','FUNCTION')
 GROUP BY object_type
 ORDER BY object_type;

-- Procedimientos y funciones dentro de los paquetes (solo los declarados en la especificación)
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
