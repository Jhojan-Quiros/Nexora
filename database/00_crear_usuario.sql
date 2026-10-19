-- =====================================================================
-- Nexora Technologies S.A. - Sistema de Gestión de Soporte TI y Activos
-- 00_crear_usuario.sql
-- Ejecutar UNA sola vez conectado como SYSTEM (o SYS) con F5.
--
-- Busca automáticamente la base conectable (PDB) de esta instalación,
-- la abre si está cerrada y crea ahí el usuario NEXORA. Al final indica
-- el NOMBRE DE SERVICIO que debe usar en SQL Developer y en el .env.
-- =====================================================================
SET SERVEROUTPUT ON

-- PDBs disponibles (informativo)
SELECT con_id, name, open_mode FROM v$pdbs ORDER BY con_id;

DECLARE
  v_pdb        VARCHAR2(128);
  v_modo       VARCHAR2(20);
  v_servicio   VARCHAR2(128);
  v_tablespace VARCHAR2(128);
  v_existe     NUMBER;
BEGIN
  -- 1) Primera PDB de usuario (se excluye la plantilla PDB$SEED)
  BEGIN
    SELECT name, open_mode INTO v_pdb, v_modo
      FROM (SELECT name, open_mode FROM v$pdbs
             WHERE name <> 'PDB$SEED'
             ORDER BY con_id)
     WHERE ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20000,
        'Esta instalación no tiene ninguna PDB de usuario. Vea las instrucciones para crear una.');
  END;
  DBMS_OUTPUT.PUT_LINE('PDB encontrada: ' || v_pdb || ' (' || v_modo || ')');

  -- 2) Abrirla si está cerrada y dejarla abierta al reiniciar Oracle
  IF v_modo <> 'READ WRITE' THEN
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE "' || v_pdb || '" OPEN';
    DBMS_OUTPUT.PUT_LINE('PDB abierta.');
  END IF;
  BEGIN
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE "' || v_pdb || '" SAVE STATE';
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- 3) Entrar a la PDB (todo lo siguiente ocurre dentro de ella)
  EXECUTE IMMEDIATE 'ALTER SESSION SET CONTAINER = "' || v_pdb || '"';

  -- 4) Tablespace: USERS si existe; si no, el predeterminado de la PDB
  EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM dba_tablespaces WHERE tablespace_name = ''USERS'''
    INTO v_tablespace;
  IF v_tablespace = '1' THEN
    v_tablespace := 'USERS';
  ELSE
    EXECUTE IMMEDIATE 'SELECT property_value FROM database_properties
                        WHERE property_name = ''DEFAULT_PERMANENT_TABLESPACE'''
      INTO v_tablespace;
  END IF;

  -- 5) Crear el usuario si no existe
  EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM dba_users WHERE username = ''NEXORA''' INTO v_existe;
  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER nexora IDENTIFIED BY "Nexora2026" ' ||
                      'DEFAULT TABLESPACE ' || v_tablespace ||
                      ' QUOTA UNLIMITED ON ' || v_tablespace;
    DBMS_OUTPUT.PUT_LINE('Usuario NEXORA creado (tablespace ' || v_tablespace || ').');
  ELSE
    DBMS_OUTPUT.PUT_LINE('El usuario NEXORA ya existía; solo se reaplican los permisos.');
  END IF;

  EXECUTE IMMEDIATE 'GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, ' ||
                    'CREATE TRIGGER, CREATE SEQUENCE TO nexora';

  -- 6) Cada PDB publica un servicio con su mismo nombre
  v_servicio := v_pdb;

  DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('LISTO. Conéctese como nexora / Nexora2026 usando');
  DBMS_OUTPUT.PUT_LINE('  Tipo de conexión: Nombre del servicio = ' || NVL(v_servicio, v_pdb));
  DBMS_OUTPUT.PUT_LINE('  En el .env: NEXORA_DB_DSN=localhost:1521/' || NVL(v_servicio, v_pdb));
  DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
END;
/
