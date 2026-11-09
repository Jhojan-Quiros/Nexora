-- =====================================================================
-- 06_paquete_reportes.sql
--   PKG_REPORTES (RF-10). La exportación a CSV (RF-11) la hará la
--   aplicación a partir de estos mismos cursores en la semana 12.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PAQUETE 12: PKG_REPORTES
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_reportes AS
  FUNCTION  fn_total_tickets_periodo (p_desde IN DATE, p_hasta IN DATE) RETURN NUMBER;
  FUNCTION  fn_departamento_mas_tickets RETURN VARCHAR2;

  PROCEDURE pr_tickets_por_tecnico     (p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_tickets_por_estado      (p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_tiempo_resolucion       (p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_equipos_por_departamento (p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_licencias_por_vencer    (p_dias IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE pr_panel_resumen (p_abiertos OUT NUMBER, p_en_proceso OUT NUMBER,
                              p_sin_asignar OUT NUMBER, p_criticos OUT NUMBER,
                              p_equipos_disponibles OUT NUMBER, p_licencias_por_vencer OUT NUMBER,
                              p_promedio_horas OUT NUMBER);
  PROCEDURE pr_imprimir_tickets_por_tecnico;
  PROCEDURE pr_imprimir_equipos_departamento;
END pkg_reportes;
/

CREATE OR REPLACE PACKAGE BODY pkg_reportes AS

  FUNCTION fn_total_tickets_periodo (p_desde IN DATE, p_hasta IN DATE) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total
      FROM ticket
     WHERE fecha_creacion >= TRUNC(p_desde)
       AND fecha_creacion <  TRUNC(p_hasta) + 1;
    RETURN v_total;
  END fn_total_tickets_periodo;

  -- CURSOR 15: busca el departamento que más tickets ha generado
  FUNCTION fn_departamento_mas_tickets RETURN VARCHAR2 IS
    CURSOR c_ranking IS
      SELECT departamento, COUNT(*) AS total
        FROM v_tickets_detalle
       GROUP BY departamento
       ORDER BY total DESC, departamento;
    v_fila c_ranking%ROWTYPE;
  BEGIN
    OPEN c_ranking;
    FETCH c_ranking INTO v_fila;
    CLOSE c_ranking;
    IF v_fila.departamento IS NULL THEN
      RETURN 'Sin tickets registrados';
    END IF;
    RETURN v_fila.departamento || ' (' || v_fila.total || ' tickets)';
  END fn_departamento_mas_tickets;

  PROCEDURE pr_tickets_por_tecnico (p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_tickets_por_tecnico ORDER BY total DESC, tecnico;
  END pr_tickets_por_tecnico;

  PROCEDURE pr_tickets_por_estado (p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT estado, COUNT(*) AS total
        FROM ticket
       GROUP BY estado
       ORDER BY DECODE(estado, 'ABIERTO', 1, 'EN_PROCESO', 2, 'RESUELTO', 3, 4);
  END pr_tickets_por_estado;

  PROCEDURE pr_tiempo_resolucion (p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_tiempo_resolucion ORDER BY categoria, prioridad;
  END pr_tiempo_resolucion;

  PROCEDURE pr_equipos_por_departamento (p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT * FROM v_equipos_por_departamento ORDER BY equipos_asignados DESC, departamento;
  END pr_equipos_por_departamento;

  PROCEDURE pr_licencias_por_vencer (p_dias IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    pkg_licencia.pr_por_vencer(p_dias, p_cursor);
  END pr_licencias_por_vencer;

  PROCEDURE pr_panel_resumen (p_abiertos OUT NUMBER, p_en_proceso OUT NUMBER,
                              p_sin_asignar OUT NUMBER, p_criticos OUT NUMBER,
                              p_equipos_disponibles OUT NUMBER, p_licencias_por_vencer OUT NUMBER,
                              p_promedio_horas OUT NUMBER) IS
  BEGIN
    SELECT SUM(CASE WHEN estado = 'ABIERTO' THEN 1 ELSE 0 END),
           SUM(CASE WHEN estado = 'EN_PROCESO' THEN 1 ELSE 0 END),
           SUM(CASE WHEN estado = 'ABIERTO' AND id_tecnico IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN estado IN ('ABIERTO','EN_PROCESO') AND prioridad = 'CRITICA' THEN 1 ELSE 0 END)
      INTO p_abiertos, p_en_proceso, p_sin_asignar, p_criticos
      FROM ticket;

    SELECT COUNT(*) INTO p_equipos_disponibles FROM equipo WHERE estado = 'DISPONIBLE';
    SELECT COUNT(*) INTO p_licencias_por_vencer FROM v_licencias_por_vencer;
    p_promedio_horas := pkg_ticket.fn_promedio_resolucion(NULL);

    p_abiertos    := NVL(p_abiertos, 0);
    p_en_proceso  := NVL(p_en_proceso, 0);
    p_sin_asignar := NVL(p_sin_asignar, 0);
    p_criticos    := NVL(p_criticos, 0);
  END pr_panel_resumen;

  -- CURSOR 16: reporte impreso de carga por técnico
  PROCEDURE pr_imprimir_tickets_por_tecnico IS
    CURSOR c_tecnicos IS
      SELECT tecnico, total, abiertos, en_proceso, resueltos, cerrados, promedio_horas
        FROM v_tickets_por_tecnico
       ORDER BY total DESC;
  BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD('TÉCNICO', 30) || LPAD('TOTAL', 7) || LPAD('ABIER', 7) ||
                         LPAD('PROCE', 7) || LPAD('RESUE', 7) || LPAD('CERRA', 7) || LPAD('HORAS', 9));
    FOR r IN c_tecnicos LOOP
      DBMS_OUTPUT.PUT_LINE(RPAD(r.tecnico, 30) || LPAD(r.total, 7) || LPAD(r.abiertos, 7) ||
                           LPAD(r.en_proceso, 7) || LPAD(r.resueltos, 7) || LPAD(r.cerrados, 7) ||
                           LPAD(NVL(TO_CHAR(r.promedio_horas, 'FM9990.00'), '-'), 9));
    END LOOP;
  END pr_imprimir_tickets_por_tecnico;

  -- CURSOR 17 (anidado con parámetro): equipos vigentes agrupados por departamento
  PROCEDURE pr_imprimir_equipos_departamento IS
    CURSOR c_departamentos IS
      SELECT id_departamento, departamento, equipos_asignados
        FROM v_equipos_por_departamento
       ORDER BY departamento;
    CURSOR c_equipos (cp_depto NUMBER) IS
      SELECT a.tipo, a.equipo, a.numero_serie, a.empleado
        FROM v_asignaciones_activas a
        JOIN empleado e ON e.id_empleado = a.id_empleado
       WHERE e.id_departamento = cp_depto
       ORDER BY a.tipo, a.empleado;
  BEGIN
    FOR d IN c_departamentos LOOP
      DBMS_OUTPUT.PUT_LINE('== ' || d.departamento || ' (' || d.equipos_asignados || ' equipos)');
      FOR q IN c_equipos(d.id_departamento) LOOP
        DBMS_OUTPUT.PUT_LINE('   ' || RPAD(q.tipo, 12) || RPAD(q.equipo, 30) ||
                             RPAD(q.numero_serie, 16) || q.empleado);
      END LOOP;
    END LOOP;
  END pr_imprimir_equipos_departamento;

END pkg_reportes;
/
