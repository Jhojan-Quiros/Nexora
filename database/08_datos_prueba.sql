-- =====================================================================
-- 08_datos_prueba.sql  -  Datos de prueba cargados con los procedimientos
-- Usuarios de prueba:
--   admin      / Admin2026      (ADMIN)
--   lmora      / Tecnico2026    (TECNICO)   también: crojas, avargas
--   jperez     / Empleado2026   (EMPLEADO)  y el resto de empleados
-- =====================================================================
SET SERVEROUTPUT ON

DECLARE
  -- departamentos
  d_ing NUMBER; d_dat NUMBER; d_pro NUMBER; d_sop NUMBER; d_rh NUMBER; d_fin NUMBER; d_ti NUMBER;
  -- empleados
  e_admin NUMBER; e_lmora NUMBER; e_crojas NUMBER; e_avargas NUMBER;
  e_jperez NUMBER; e_msolis NUMBER; e_kcastro NUMBER; e_dherrera NUMBER;
  e_fnunez NUMBER; e_gchaves NUMBER; e_pjimenez NUMBER; e_rbrenes NUMBER;
  -- técnicos
  t_lmora NUMBER; t_crojas NUMBER; t_avargas NUMBER;
  -- equipos
  q1 NUMBER; q2 NUMBER; q3 NUMBER; q4 NUMBER; q5 NUMBER; q6 NUMBER;
  q7 NUMBER; q8 NUMBER; q9 NUMBER; q10 NUMBER;
  -- licencias
  l1 NUMBER; l2 NUMBER; l3 NUMBER; l4 NUMBER; l5 NUMBER;
  -- tickets / auxiliares
  k1 NUMBER; k2 NUMBER; k3 NUMBER; k4 NUMBER; k5 NUMBER; k6 NUMBER;
  k7 NUMBER; k8 NUMBER; k9 NUMBER; k10 NUMBER;
  v_id NUMBER;
BEGIN
  -- ---------------- Departamentos ----------------
  pkg_departamento.pr_guardar(d_ing, 'Ingeniería', 'Heredia - Edificio A');
  pkg_departamento.pr_guardar(d_dat, 'Datos e IA', 'Heredia - Edificio B');
  pkg_departamento.pr_guardar(d_pro, 'Producto', 'Escazú - Piso 3');
  pkg_departamento.pr_guardar(d_sop, 'Soporte al Cliente', 'Escazú - Piso 1');
  pkg_departamento.pr_guardar(d_rh, 'Recursos Humanos', 'Escazú - Piso 2');
  pkg_departamento.pr_guardar(d_fin, 'Finanzas', 'Escazú - Piso 2');
  pkg_departamento.pr_guardar(d_ti, 'Tecnologías de Información', 'Escazú - Piso 1');

  -- ---------------- Empleados ----------------
  pkg_empleado.pr_guardar(e_admin, d_ti,  'Jhojan Quiros Cascante',   'jquiros@nexora.cr', 'admin',   'Admin2026',    'ADMIN');
  pkg_empleado.pr_guardar(e_lmora, d_ti,  'Luis Mora Salazar',     'lmora@nexora.cr',    'lmora',   'Tecnico2026',  'EMPLEADO');
  pkg_empleado.pr_guardar(e_crojas, d_ti,  'Carolina Rojas Arias',  'crojas@nexora.cr',   'crojas',  'Tecnico2026',  'EMPLEADO');
  pkg_empleado.pr_guardar(e_avargas, d_ti,  'Andrés Vargas Solano',  'avargas@nexora.cr',  'avargas', 'Tecnico2026',  'EMPLEADO');
  pkg_empleado.pr_guardar(e_jperez, d_ing, 'José Pérez Calderón',   'jperez@nexora.cr',   'jperez',  'Empleado2026', 'EMPLEADO');
  pkg_empleado.pr_guardar(e_msolis, d_ing, 'María Solís Brenes',    'msolis@nexora.cr',   'msolis',  'Empleado2026', 'EMPLEADO');
  pkg_empleado.pr_guardar(e_kcastro, d_dat, 'Kevin Castro Ulate',    'kcastro@nexora.cr',  'kcastro', 'Empleado2026', 'EMPLEADO');
  pkg_empleado.pr_guardar(e_dherrera, d_dat, 'Daniela Herrera Vega',  'dherrera@nexora.cr', 'dherrera','Empleado2026', 'EMPLEADO');
  pkg_empleado.pr_guardar(e_fnunez, d_pro, 'Fabián Núñez Rojas',    'fnunez@nexora.cr',   'fnunez',  'Empleado2026', 'EMPLEADO');
  pkg_empleado.pr_guardar(e_gchaves, d_sop, 'Gabriela Chaves Mora',  'gchaves@nexora.cr',  'gchaves', 'Empleado2026', 'EMPLEADO');
  pkg_empleado.pr_guardar(e_pjimenez, d_rh,  'Paola Jiménez Araya',   'pjimenez@nexora.cr', 'pjimenez','Empleado2026', 'EMPLEADO');
  pkg_empleado.pr_guardar(e_rbrenes, d_fin, 'Ricardo Brenes Ortiz',  'rbrenes@nexora.cr',  'rbrenes', 'Empleado2026', 'EMPLEADO');

  -- ---------------- Técnicos (cambian su rol a TECNICO) ----------------
  pkg_tecnico.pr_guardar(t_lmora, e_lmora,   'Hardware y redes',      'SENIOR');
  pkg_tecnico.pr_guardar(t_crojas, e_crojas,  'Software y accesos',    'INTERMEDIO');
  pkg_tecnico.pr_guardar(t_avargas, e_avargas, 'Soporte general',       'JUNIOR');

  -- ---------------- Equipos ----------------
  pkg_equipo.pr_guardar(q1, 'LAPTOP',     'Dell',    'Latitude 5440',   'DL5440-0001', DATE '2024-02-10');
  pkg_equipo.pr_guardar(q2, 'LAPTOP',     'Dell',    'Latitude 5440',   'DL5440-0002', DATE '2024-02-10');
  pkg_equipo.pr_guardar(q3, 'LAPTOP',     'Lenovo',  'ThinkPad T14',    'LNT14-1001',  DATE '2023-08-21');
  pkg_equipo.pr_guardar(q4, 'LAPTOP',     'Apple',   'MacBook Pro 14',  'APMBP-2201',  DATE '2025-01-15');
  pkg_equipo.pr_guardar(q5, 'ESCRITORIO', 'HP',      'ProDesk 400 G9',  'HPPD-3301',   DATE '2023-05-03');
  pkg_equipo.pr_guardar(q6, 'MONITOR',    'LG',      'UltraWide 29"',   'LGUW-4401',   DATE '2024-06-12');
  pkg_equipo.pr_guardar(q7, 'MONITOR',    'Samsung', 'S24 FHD',         'SMS24-4402',  DATE '2022-11-30');
  pkg_equipo.pr_guardar(q8, 'SERVIDOR',   'Dell',    'PowerEdge R650',  'DPER-5501',   DATE '2022-03-18');
  pkg_equipo.pr_guardar(q9, 'IMPRESORA',  'Epson',   'WorkForce Pro',   'EPWF-6601',   DATE '2021-09-07');
  pkg_equipo.pr_guardar(q10, 'LAPTOP',     'HP',      'EliteBook 840',   'HPEB-7701',   DATE '2020-04-22');

  -- ---------------- Asignaciones de equipo ----------------
  pkg_asignacion_equipo.pr_asignar(q1, e_jperez,   v_id);
  pkg_asignacion_equipo.pr_asignar(q2, e_msolis,   v_id);
  pkg_asignacion_equipo.pr_asignar(q3, e_kcastro,  v_id);
  pkg_asignacion_equipo.pr_asignar(q4, e_fnunez,   v_id);
  pkg_asignacion_equipo.pr_asignar(q5, e_rbrenes,  v_id);
  pkg_asignacion_equipo.pr_asignar(q6, e_jperez,   v_id);
  pkg_asignacion_equipo.pr_asignar(q7, e_dherrera, v_id);
  -- Historial: la laptop q10 la tuvo Gabriela, la devolvió y luego pasó a reparación
  pkg_asignacion_equipo.pr_asignar(q10, e_gchaves, v_id);
  pkg_asignacion_equipo.pr_devolver(q10);
  pkg_equipo.pr_cambiar_estado(q10, 'REPARACION');

  -- ---------------- Licencias ----------------
  pkg_licencia.pr_guardar(l1, 'Microsoft 365 Business', 'Microsoft', 'M365-NEX-2026-A1', ADD_MONTHS(TRUNC(SYSDATE), 8), 50);
  pkg_licencia.pr_guardar(l2, 'JetBrains All Products', 'JetBrains', 'JB-NEX-8842-ZZ',   TRUNC(SYSDATE) + 12, 10);
  pkg_licencia.pr_guardar(l3, 'Tableau Creator',        'Salesforce','TAB-NEX-5521-QW',  TRUNC(SYSDATE) + 25, 5);
  pkg_licencia.pr_guardar(l4, 'Adobe Acrobat Pro',      'Adobe',     'ADB-NEX-1190-PL',  ADD_MONTHS(TRUNC(SYSDATE), 14), 8);
  pkg_licencia.pr_guardar(l5, 'Postman Enterprise',     'Postman',   'PST-NEX-7710-MN',  TRUNC(SYSDATE) + 5, 3);

  pkg_asignacion_licencia.pr_asignar(l1, e_jperez,   NULL, v_id);
  pkg_asignacion_licencia.pr_asignar(l1, e_msolis,   NULL, v_id);
  pkg_asignacion_licencia.pr_asignar(l1, e_kcastro,  NULL, v_id);
  pkg_asignacion_licencia.pr_asignar(l1, e_rbrenes,  NULL, v_id);
  pkg_asignacion_licencia.pr_asignar(l2, e_jperez,   NULL, v_id);
  pkg_asignacion_licencia.pr_asignar(l2, e_msolis,   NULL, v_id);
  pkg_asignacion_licencia.pr_asignar(l3, e_kcastro,  NULL, v_id);
  pkg_asignacion_licencia.pr_asignar(l3, e_dherrera, NULL, v_id);
  pkg_asignacion_licencia.pr_asignar(l4, e_pjimenez, NULL, v_id);
  pkg_asignacion_licencia.pr_asignar(l5, e_fnunez,   NULL, v_id);
  -- Licencias instaladas en equipos (RF-08)
  pkg_asignacion_licencia.pr_asignar(l4, NULL, q5, v_id);
  pkg_asignacion_licencia.pr_asignar(l1, NULL, q8, v_id);
  pkg_asignacion_licencia.pr_asignar(l2, NULL, q4, v_id);

  -- ---------------- Tickets ----------------
  pkg_ticket.pr_guardar(k1, e_jperez,   q1,   'Laptop no enciende',           'Después de una actualización la laptop no arranca.', 'HARDWARE', 'ALTA');
  pkg_ticket.pr_guardar(k2, e_msolis,   NULL, 'Sin acceso a la VPN',          'El cliente VPN rechaza las credenciales.',            'ACCESOS',  'CRITICA');
  pkg_ticket.pr_guardar(k3, e_kcastro,  q3,   'Instalar Python 3.12',         'Necesito Python 3.12 y permisos para pip.',           'SOFTWARE', 'MEDIA');
  pkg_ticket.pr_guardar(k4, e_fnunez,   q4,   'Pantalla con parpadeo',        'La pantalla parpadea al conectar el monitor externo.','HARDWARE', 'MEDIA');
  pkg_ticket.pr_guardar(k5, e_gchaves,  NULL, 'Internet lento en piso 1',     'La red inalámbrica del piso 1 está muy lenta.',      'RED',      'ALTA');
  pkg_ticket.pr_guardar(k6, e_pjimenez, NULL, 'Crear usuario a nuevo ingreso','Alta de cuenta para colaboradora que ingresa el lunes.','ACCESOS','MEDIA');
  pkg_ticket.pr_guardar(k7, e_rbrenes,  q5,   'Excel se cierra solo',         'Excel se cierra al abrir archivos grandes.',          'SOFTWARE', 'BAJA');
  pkg_ticket.pr_guardar(k8, e_dherrera, q7,   'Monitor sin señal',            'El monitor no detecta la computadora.',               'HARDWARE', 'BAJA');
  pkg_ticket.pr_guardar(k9, e_jperez,   NULL, 'Solicitud de mouse',           'Necesito un mouse ergonómico.',                       'OTRO',     'BAJA');
  pkg_ticket.pr_guardar(k10, e_msolis,   q2,   'Error al clonar repositorio',  'Git devuelve error de certificado SSL.',              'SOFTWARE', 'ALTA');

  -- Asignación y avance de estados
  pkg_ticket.pr_asignar_tecnico(k1, t_lmora);
  pkg_ticket.pr_asignar_tecnico(k2, t_crojas);
  pkg_ticket.pr_asignar_tecnico(k3, t_crojas);
  pkg_ticket.pr_asignar_tecnico(k4, t_lmora);
  pkg_ticket.pr_asignar_tecnico(k5, t_lmora);
  pkg_ticket.pr_asignar_tecnico(k7, t_avargas);
  pkg_ticket.pr_asignar_tecnico(k8, t_avargas);
  pkg_ticket.pr_asignar_tecnico(k10, t_crojas);

  pkg_ticket.pr_cambiar_estado(k3, 'RESUELTO');
  pkg_ticket.pr_cambiar_estado(k3, 'CERRADO');
  pkg_ticket.pr_cambiar_estado(k4, 'RESUELTO');
  pkg_ticket.pr_cambiar_estado(k7, 'RESUELTO');
  pkg_ticket.pr_cambiar_estado(k7, 'CERRADO');
  pkg_ticket.pr_cambiar_estado(k8, 'RESUELTO');
  pkg_ticket.pr_cambiar_estado(k10, 'RESUELTO');
  pkg_ticket.pr_cambiar_estado(k10, 'CERRADO');

  -- Comentarios de seguimiento
  v_id := NULL; pkg_comentario.pr_guardar(v_id, k1, t_lmora,  'Se revisó la batería; se solicita cargador de reemplazo.');
  v_id := NULL; pkg_comentario.pr_guardar(v_id, k2, t_crojas, 'Se restableció la contraseña del directorio; pendiente probar.');
  v_id := NULL; pkg_comentario.pr_guardar(v_id, k4, t_lmora,  'Se actualizó el driver de video. Problema resuelto.');
  v_id := NULL; pkg_comentario.pr_guardar(v_id, k5, t_lmora,  'Se detectó un access point saturado; se programa cambio.');
  v_id := NULL; pkg_comentario.pr_guardar(v_id, k8, t_avargas,'Cable HDMI dañado; se reemplazó.');

  -- Fechas históricas para que los reportes de tiempos tengan datos reales
  -- (ajuste directo solo para la carga de prueba, no forma parte del sistema)
  UPDATE ticket SET fecha_creacion = SYSDATE - 9,  fecha_cierre = SYSDATE - 9 + 5/24  WHERE id_ticket = k3;
  UPDATE ticket SET fecha_creacion = SYSDATE - 6,  fecha_cierre = SYSDATE - 5         WHERE id_ticket = k4;
  UPDATE ticket SET fecha_creacion = SYSDATE - 12, fecha_cierre = SYSDATE - 11 + 2/24 WHERE id_ticket = k7;
  UPDATE ticket SET fecha_creacion = SYSDATE - 3,  fecha_cierre = SYSDATE - 3 + 3/24  WHERE id_ticket = k8;
  UPDATE ticket SET fecha_creacion = SYSDATE - 4,  fecha_cierre = SYSDATE - 4 + 8/24  WHERE id_ticket = k10;
  UPDATE ticket SET fecha_creacion = SYSDATE - 2 WHERE id_ticket IN (k1, k2, k5);
  UPDATE ticket SET fecha_creacion = SYSDATE - 1 WHERE id_ticket IN (k6, k9);
  UPDATE comentario_ticket SET fecha = SYSDATE - 1 WHERE fecha > SYSDATE - 1/24;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Datos de prueba cargados correctamente.');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Error cargando datos: ' || SQLERRM);
    RAISE;
END;
/
