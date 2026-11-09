-- =====================================================================
-- 06_paquete_reportes.sql
--   PKG_REPORTES (RF-10). Cada reporte se devuelve como cursor, de modo que la
--   aplicación lo puede mostrar en pantalla o exportar a CSV (RF-11).
-- =====================================================================

-- ---------------------------------------------------------------------
-- PAQUETE 12: PKG_REPORTES
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_reportes AS
  -- p_tipo: TECNICOS | ESTADOS | RESOLUCION | EQUIPOS_DEPARTAMENTO | LICENCIAS_VENCER
  FUNCTION fn_reporte (p_tipo IN VARCHAR2, p_dias IN NUMBER DEFAULT 30) RETURN SYS_REFCURSOR;
  -- Una sola fila con los indicadores del panel principal
  FUNCTION fn_panel_resumen RETURN SYS_REFCURSOR;
END pkg_reportes;
/

CREATE OR REPLACE PACKAGE BODY pkg_reportes AS

  FUNCTION fn_reporte (p_tipo IN VARCHAR2, p_dias IN NUMBER DEFAULT 30) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    CASE UPPER(TRIM(p_tipo))
      WHEN 'TECNICOS' THEN
        OPEN v_cursor FOR
          SELECT * FROM v_tickets_por_tecnico ORDER BY total DESC, tecnico;
      WHEN 'ESTADOS' THEN
        OPEN v_cursor FOR
          SELECT estado, COUNT(*) AS total
            FROM ticket
           GROUP BY estado
           ORDER BY DECODE(estado, 'ABIERTO', 1, 'EN_PROCESO', 2, 'RESUELTO', 3, 4);
      WHEN 'RESOLUCION' THEN
        OPEN v_cursor FOR
          SELECT * FROM v_tiempo_resolucion ORDER BY categoria, prioridad;
      WHEN 'EQUIPOS_DEPARTAMENTO' THEN
        OPEN v_cursor FOR
          SELECT * FROM v_equipos_por_departamento ORDER BY equipos_asignados DESC, departamento;
      WHEN 'LICENCIAS_VENCER' THEN
        v_cursor := pkg_licencia.fn_listar(NULL, NVL(p_dias, 30));
      ELSE
        pkg_utilidades.pr_error(pkg_utilidades.c_err_validacion,
          'Reporte desconocido. Use TECNICOS, ESTADOS, RESOLUCION, EQUIPOS_DEPARTAMENTO o LICENCIAS_VENCER.');
    END CASE;
    RETURN v_cursor;
  END fn_reporte;

  -- CURSOR 18: recorre los tickets pendientes para calcular los indicadores del panel
  FUNCTION fn_panel_resumen RETURN SYS_REFCURSOR IS
    CURSOR c_pendientes IS
      SELECT estado, prioridad, id_tecnico
        FROM ticket
       WHERE estado IN ('ABIERTO','EN_PROCESO');
    v_abiertos    NUMBER := 0;
    v_en_proceso  NUMBER := 0;
    v_sin_asignar NUMBER := 0;
    v_criticos    NUMBER := 0;
    v_cursor      SYS_REFCURSOR;
  BEGIN
    FOR r IN c_pendientes LOOP
      IF r.estado = 'ABIERTO' THEN
        v_abiertos := v_abiertos + 1;
        IF r.id_tecnico IS NULL THEN
          v_sin_asignar := v_sin_asignar + 1;
        END IF;
      ELSE
        v_en_proceso := v_en_proceso + 1;
      END IF;
      IF r.prioridad = 'CRITICA' THEN
        v_criticos := v_criticos + 1;
      END IF;
    END LOOP;

    OPEN v_cursor FOR
      SELECT v_abiertos    AS abiertos,
             v_en_proceso  AS en_proceso,
             v_sin_asignar AS sin_asignar,
             v_criticos    AS criticos,
             (SELECT COUNT(*) FROM equipo WHERE estado = 'DISPONIBLE') AS equipos_disponibles,
             (SELECT COUNT(*) FROM v_licencias_uso WHERE dias_restantes BETWEEN 0 AND 30) AS licencias_por_vencer,
             pkg_ticket.fn_promedio_resolucion(NULL) AS promedio_horas
        FROM dual;
    RETURN v_cursor;
  END fn_panel_resumen;

END pkg_reportes;
/
