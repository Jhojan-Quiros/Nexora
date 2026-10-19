-- =====================================================================
-- 02_vistas.sql  -  14 vistas
-- Los procedimientos de consulta abren sus cursores sobre estas vistas.
-- =====================================================================

-- V01. Empleados con su departamento
CREATE OR REPLACE VIEW v_empleados_detalle AS
SELECT e.id_empleado,
       e.nombre_completo,
       e.correo,
       e.usuario,
       e.rol,
       e.activo,
       e.fecha_registro,
       d.id_departamento,
       d.nombre    AS departamento,
       d.ubicacion
  FROM empleado e
  JOIN departamento d ON d.id_departamento = e.id_departamento;

-- V02. Departamentos con cantidad de empleados activos
CREATE OR REPLACE VIEW v_departamentos_resumen AS
SELECT d.id_departamento,
       d.nombre,
       d.ubicacion,
       d.activo,
       COUNT(e.id_empleado) AS empleados_activos
  FROM departamento d
  LEFT JOIN empleado e
         ON e.id_departamento = d.id_departamento
        AND e.activo = 'S'
 GROUP BY d.id_departamento, d.nombre, d.ubicacion, d.activo;

-- V03. Técnicos con su carga actual de tickets
CREATE OR REPLACE VIEW v_tecnicos_detalle AS
SELECT t.id_tecnico,
       t.id_empleado,
       e.nombre_completo,
       e.correo,
       t.especialidad,
       t.nivel,
       t.activo,
       (SELECT COUNT(*)
          FROM ticket k
         WHERE k.id_tecnico = t.id_tecnico
           AND k.estado IN ('ABIERTO','EN_PROCESO')) AS tickets_activos
  FROM tecnico t
  JOIN empleado e ON e.id_empleado = t.id_empleado;

-- V04. Equipos con el empleado que lo tiene actualmente
CREATE OR REPLACE VIEW v_equipos_detalle AS
SELECT q.id_equipo,
       q.tipo,
       q.marca,
       q.modelo,
       q.numero_serie,
       q.estado,
       q.fecha_compra,
       ae.id_empleado,
       e.nombre_completo AS asignado_a,
       ae.fecha_inicio   AS asignado_desde
  FROM equipo q
  LEFT JOIN asignacion_equipo ae
         ON ae.id_equipo = q.id_equipo
        AND ae.fecha_fin IS NULL
  LEFT JOIN empleado e ON e.id_empleado = ae.id_empleado;

-- V05. Asignaciones de equipo vigentes
CREATE OR REPLACE VIEW v_asignaciones_activas AS
SELECT ae.id_asig_equipo,
       ae.id_equipo,
       q.tipo,
       q.marca || ' ' || q.modelo AS equipo,
       q.numero_serie,
       ae.id_empleado,
       e.nombre_completo AS empleado,
       d.nombre          AS departamento,
       ae.fecha_inicio,
       TRUNC(SYSDATE) - TRUNC(ae.fecha_inicio) AS dias_asignado
  FROM asignacion_equipo ae
  JOIN equipo q       ON q.id_equipo = ae.id_equipo
  JOIN empleado e     ON e.id_empleado = ae.id_empleado
  JOIN departamento d ON d.id_departamento = e.id_departamento
 WHERE ae.fecha_fin IS NULL;

-- V06. Historial completo de asignaciones de equipo
CREATE OR REPLACE VIEW v_historial_asignaciones AS
SELECT ae.id_asig_equipo,
       ae.id_equipo,
       q.numero_serie,
       q.marca || ' ' || q.modelo AS equipo,
       ae.id_empleado,
       e.nombre_completo AS empleado,
       ae.fecha_inicio,
       ae.fecha_fin,
       CASE WHEN ae.fecha_fin IS NULL THEN 'VIGENTE' ELSE 'FINALIZADA' END AS situacion,
       TRUNC(NVL(ae.fecha_fin, SYSDATE)) - TRUNC(ae.fecha_inicio) AS dias
  FROM asignacion_equipo ae
  JOIN equipo q   ON q.id_equipo = ae.id_equipo
  JOIN empleado e ON e.id_empleado = ae.id_empleado;

-- V07. Uso y vigencia de licencias (sin exponer la clave)
CREATE OR REPLACE VIEW v_licencias_uso AS
SELECT l.id_licencia,
       l.software,
       l.proveedor,
       l.fecha_vencimiento,
       l.cantidad,
       COUNT(al.id_asig_licencia)              AS asignadas,
       l.cantidad - COUNT(al.id_asig_licencia) AS disponibles,
       TRUNC(l.fecha_vencimiento) - TRUNC(SYSDATE) AS dias_restantes,
       CASE
         WHEN l.fecha_vencimiento < TRUNC(SYSDATE)       THEN 'VENCIDA'
         WHEN l.fecha_vencimiento <= TRUNC(SYSDATE) + 30 THEN 'POR VENCER'
         ELSE 'VIGENTE'
       END AS estado_licencia
  FROM licencia l
  LEFT JOIN asignacion_licencia al ON al.id_licencia = l.id_licencia
 GROUP BY l.id_licencia, l.software, l.proveedor, l.fecha_vencimiento, l.cantidad;

-- V08. Licencias que vencen en los próximos 30 días (RF-09)
CREATE OR REPLACE VIEW v_licencias_por_vencer AS
SELECT *
  FROM v_licencias_uso
 WHERE dias_restantes BETWEEN 0 AND 30;

-- V09. Tickets con todos sus datos descriptivos
CREATE OR REPLACE VIEW v_tickets_detalle AS
SELECT t.id_ticket,
       t.titulo,
       t.descripcion,
       t.categoria,
       t.prioridad,
       CASE t.prioridad WHEN 'CRITICA' THEN 1 WHEN 'ALTA' THEN 2
                        WHEN 'MEDIA'   THEN 3 ELSE 4 END AS orden_prioridad,
       t.estado,
       t.fecha_creacion,
       t.fecha_cierre,
       ROUND((t.fecha_cierre - t.fecha_creacion) * 24, 2) AS horas_resolucion,
       t.id_empleado,
       es.nombre_completo AS solicitante,
       d.nombre           AS departamento,
       t.id_tecnico,
       et.nombre_completo AS tecnico,
       t.id_equipo,
       q.numero_serie,
       q.tipo             AS tipo_equipo
  FROM ticket t
  JOIN empleado es    ON es.id_empleado = t.id_empleado
  JOIN departamento d ON d.id_departamento = es.id_departamento
  LEFT JOIN tecnico tc  ON tc.id_tecnico = t.id_tecnico
  LEFT JOIN empleado et ON et.id_empleado = tc.id_empleado
  LEFT JOIN equipo q    ON q.id_equipo = t.id_equipo;

-- V10. Tickets pendientes de atención
CREATE OR REPLACE VIEW v_tickets_abiertos AS
SELECT *
  FROM v_tickets_detalle
 WHERE estado IN ('ABIERTO','EN_PROCESO');

-- V11. Carga y desempeño por técnico (RF-10)
CREATE OR REPLACE VIEW v_tickets_por_tecnico AS
SELECT tc.id_tecnico,
       e.nombre_completo AS tecnico,
       tc.especialidad,
       tc.nivel,
       COUNT(t.id_ticket) AS total,
       SUM(CASE WHEN t.estado = 'ABIERTO'    THEN 1 ELSE 0 END) AS abiertos,
       SUM(CASE WHEN t.estado = 'EN_PROCESO' THEN 1 ELSE 0 END) AS en_proceso,
       SUM(CASE WHEN t.estado = 'RESUELTO'   THEN 1 ELSE 0 END) AS resueltos,
       SUM(CASE WHEN t.estado = 'CERRADO'    THEN 1 ELSE 0 END) AS cerrados,
       ROUND(AVG((t.fecha_cierre - t.fecha_creacion) * 24), 2) AS promedio_horas
  FROM tecnico tc
  JOIN empleado e    ON e.id_empleado = tc.id_empleado
  LEFT JOIN ticket t ON t.id_tecnico = tc.id_tecnico
 GROUP BY tc.id_tecnico, e.nombre_completo, tc.especialidad, tc.nivel;

-- V12. Tiempo de resolución por categoría y prioridad (RF-10)
CREATE OR REPLACE VIEW v_tiempo_resolucion AS
SELECT categoria,
       prioridad,
       COUNT(*) AS tickets_resueltos,
       ROUND(AVG((fecha_cierre - fecha_creacion) * 24), 2) AS promedio_horas,
       ROUND(MIN((fecha_cierre - fecha_creacion) * 24), 2) AS minimo_horas,
       ROUND(MAX((fecha_cierre - fecha_creacion) * 24), 2) AS maximo_horas
  FROM ticket
 WHERE fecha_cierre IS NOT NULL
   AND id_tecnico IS NOT NULL
 GROUP BY categoria, prioridad;

-- V13. Equipos asignados por departamento (RF-10)
CREATE OR REPLACE VIEW v_equipos_por_departamento AS
SELECT d.id_departamento,
       d.nombre AS departamento,
       COUNT(q.id_equipo) AS equipos_asignados,
       SUM(CASE WHEN q.tipo = 'LAPTOP'     THEN 1 ELSE 0 END) AS laptops,
       SUM(CASE WHEN q.tipo = 'ESCRITORIO' THEN 1 ELSE 0 END) AS escritorios,
       SUM(CASE WHEN q.tipo = 'MONITOR'    THEN 1 ELSE 0 END) AS monitores,
       SUM(CASE WHEN q.tipo NOT IN ('LAPTOP','ESCRITORIO','MONITOR') THEN 1 ELSE 0 END) AS otros
  FROM departamento d
  LEFT JOIN empleado e ON e.id_departamento = d.id_departamento
  LEFT JOIN asignacion_equipo ae
         ON ae.id_empleado = e.id_empleado
        AND ae.fecha_fin IS NULL
  LEFT JOIN equipo q ON q.id_equipo = ae.id_equipo
 GROUP BY d.id_departamento, d.nombre;

-- V14. Comentarios de seguimiento con el nombre del técnico
CREATE OR REPLACE VIEW v_comentarios_detalle AS
SELECT c.id_comentario,
       c.id_ticket,
       t.titulo AS ticket,
       c.id_tecnico,
       e.nombre_completo AS tecnico,
       c.texto,
       c.fecha
  FROM comentario_ticket c
  JOIN ticket t   ON t.id_ticket = c.id_ticket
  JOIN tecnico tc ON tc.id_tecnico = c.id_tecnico
  JOIN empleado e ON e.id_empleado = tc.id_empleado;

-- V15. Diccionario de datos del esquema (complemento a SQL Developer)
CREATE OR REPLACE VIEW v_diccionario_datos AS
SELECT c.table_name  AS tabla,
       tc.comments   AS descripcion_tabla,
       c.column_id   AS orden,
       c.column_name AS columna,
       CASE
         WHEN c.data_type IN ('VARCHAR2','CHAR') THEN c.data_type || '(' || c.char_length || ')'
         WHEN c.data_type = 'NUMBER' AND c.data_precision IS NOT NULL
              THEN c.data_type || '(' || c.data_precision || ',' || c.data_scale || ')'
         ELSE c.data_type
       END AS tipo_dato,
       DECODE(c.nullable, 'N', 'NO', 'SI') AS permite_nulos,
       (SELECT LISTAGG(DECODE(uc.constraint_type, 'P','PK', 'R','FK', 'U','UQ'), ',')
                 WITHIN GROUP (ORDER BY uc.constraint_type)
          FROM user_cons_columns ucc
          JOIN user_constraints  uc ON uc.constraint_name = ucc.constraint_name
         WHERE ucc.table_name  = c.table_name
           AND ucc.column_name = c.column_name
           AND uc.constraint_type IN ('P','R','U')) AS llaves,
       cc.comments AS descripcion
  FROM user_tab_columns c
  JOIN user_tables t ON t.table_name = c.table_name
  LEFT JOIN user_tab_comments tc ON tc.table_name = c.table_name
  LEFT JOIN user_col_comments cc
         ON cc.table_name  = c.table_name
        AND cc.column_name = c.column_name;
