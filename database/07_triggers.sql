-- =====================================================================
-- 07_triggers.sql  -  7 triggers de integridad y automatización
-- =====================================================================

-- T1. Normaliza datos del empleado y protege el usuario (sal del hash)
CREATE OR REPLACE TRIGGER trg_empleado_normalizar
BEFORE INSERT OR UPDATE ON empleado
FOR EACH ROW
BEGIN
  :NEW.nombre_completo := TRIM(:NEW.nombre_completo);
  :NEW.correo          := LOWER(TRIM(:NEW.correo));
  :NEW.usuario         := LOWER(TRIM(:NEW.usuario));
  :NEW.rol             := UPPER(:NEW.rol);
  IF INSERTING THEN
    :NEW.activo         := NVL(:NEW.activo, 'S');
    :NEW.fecha_registro := NVL(:NEW.fecha_registro, SYSDATE);
  ELSIF :NEW.usuario <> :OLD.usuario THEN
    RAISE_APPLICATION_ERROR(-20003, 'El nombre de usuario no puede modificarse.');
  END IF;
END;
/

-- T2. Un equipo dado de baja no se reactiva, y no se da de baja si está asignado
CREATE OR REPLACE TRIGGER trg_equipo_validar_estado
BEFORE UPDATE OF estado ON equipo
FOR EACH ROW
WHEN (NEW.estado = 'BAJA' OR OLD.estado = 'BAJA')
DECLARE
  v_vigentes NUMBER;
BEGIN
  IF :OLD.estado = 'BAJA' AND :NEW.estado <> 'BAJA' THEN
    RAISE_APPLICATION_ERROR(-20003, 'El equipo ' || :OLD.numero_serie || ' está dado de baja.');
  ELSIF :NEW.estado = 'BAJA' AND :OLD.estado <> 'BAJA' THEN
    SELECT COUNT(*) INTO v_vigentes
      FROM asignacion_equipo
     WHERE id_equipo = :NEW.id_equipo
       AND fecha_fin IS NULL;
    IF v_vigentes > 0 THEN
      RAISE_APPLICATION_ERROR(-20003, 'No se puede dar de baja un equipo asignado.');
    END IF;
  END IF;
END;
/

-- T3. Mantiene el estado del equipo sincronizado con sus asignaciones
CREATE OR REPLACE TRIGGER trg_asig_equipo_estado
AFTER INSERT OR UPDATE OF fecha_fin ON asignacion_equipo
FOR EACH ROW
BEGIN
  IF INSERTING AND :NEW.fecha_fin IS NULL THEN
    UPDATE equipo SET estado = 'ASIGNADO' WHERE id_equipo = :NEW.id_equipo;
  ELSIF UPDATING AND :OLD.fecha_fin IS NULL AND :NEW.fecha_fin IS NOT NULL THEN
    UPDATE equipo SET estado = 'DISPONIBLE'
     WHERE id_equipo = :NEW.id_equipo
       AND estado = 'ASIGNADO';
  END IF;
END;
/

-- T4. No se asignan puestos de licencias vencidas (ni a empleados ni a equipos)
CREATE OR REPLACE TRIGGER trg_asig_licencia_validar
BEFORE INSERT OR UPDATE OF id_licencia, id_empleado, id_equipo ON asignacion_licencia
FOR EACH ROW
DECLARE
  v_vencimiento licencia.fecha_vencimiento%TYPE;
BEGIN
  SELECT fecha_vencimiento INTO v_vencimiento
    FROM licencia
   WHERE id_licencia = :NEW.id_licencia;
  IF v_vencimiento < TRUNC(SYSDATE) THEN
    RAISE_APPLICATION_ERROR(-20003, 'La licencia venció el ' || TO_CHAR(v_vencimiento, 'DD/MM/YYYY') ||
                                    ' y no puede asignarse.');
  END IF;
  IF INSERTING THEN
    :NEW.fecha_asignacion := NVL(:NEW.fecha_asignacion, SYSDATE);
  END IF;
END;
/

-- T5. Valores iniciales de todo ticket nuevo
CREATE OR REPLACE TRIGGER trg_ticket_nuevo
BEFORE INSERT ON ticket
FOR EACH ROW
BEGIN
  :NEW.estado         := 'ABIERTO';
  :NEW.fecha_creacion := NVL(:NEW.fecha_creacion, SYSDATE);
  :NEW.fecha_cierre   := NULL;
  :NEW.categoria      := UPPER(:NEW.categoria);
  :NEW.prioridad      := UPPER(NVL(:NEW.prioridad, 'MEDIA'));
  :NEW.titulo         := TRIM(:NEW.titulo);
END;
/

-- T6. Valida el ciclo de vida del ticket y registra la fecha de cierre
CREATE OR REPLACE TRIGGER trg_ticket_estado
BEFORE UPDATE OF estado ON ticket
FOR EACH ROW
BEGIN
  IF pkg_ticket.fn_transicion_valida(:OLD.estado, :NEW.estado) = 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'Transición no permitida: ' || :OLD.estado || ' -> ' || :NEW.estado);
  END IF;

  IF :NEW.estado IN ('RESUELTO','CERRADO') AND :NEW.fecha_cierre IS NULL THEN
    :NEW.fecha_cierre := SYSDATE;
  ELSIF :NEW.estado IN ('ABIERTO','EN_PROCESO') THEN
    :NEW.fecha_cierre := NULL;
  END IF;
END;
/

-- T7. No se comentan tickets cerrados; fecha y texto se fijan aquí
CREATE OR REPLACE TRIGGER trg_comentario_validar
BEFORE INSERT ON comentario_ticket
FOR EACH ROW
DECLARE
  v_estado ticket.estado%TYPE;
BEGIN
  SELECT estado INTO v_estado FROM ticket WHERE id_ticket = :NEW.id_ticket;
  IF v_estado = 'CERRADO' THEN
    RAISE_APPLICATION_ERROR(-20003, 'El ticket #' || :NEW.id_ticket || ' está cerrado; no admite comentarios.');
  END IF;
  :NEW.fecha := SYSDATE;
  :NEW.texto := TRIM(:NEW.texto);
END;
/
