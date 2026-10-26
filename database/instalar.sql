-- =====================================================================
-- instalar.sql - Instala todo el esquema NEXORA en orden.
-- En SQL Developer: abrir este archivo conectado como NEXORA y pulsar F5.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

PROMPT == Tablas ==
@@01_tablas.sql
PROMPT == Vistas ==
@@02_vistas.sql
PROMPT == Paquetes base ==
@@03_paquetes_base.sql
PROMPT == Paquetes de catálogos ==
@@04_paquetes_catalogos.sql
PROMPT == Paquetes de operación ==
@@05_paquetes_operacion.sql
PROMPT == Paquete de reportes ==
@@06_paquete_reportes.sql
PROMPT == Triggers ==
@@07_triggers.sql
PROMPT == Recompilando ==
EXEC DBMS_UTILITY.COMPILE_SCHEMA(schema => USER, compile_all => FALSE)
PROMPT == Datos de prueba ==
@@08_datos_prueba.sql
PROMPT == Instalación terminada. Ejecute 09_pruebas_y_conteo.sql para verificar. ==
