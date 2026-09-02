-- =====================================================================
--  01_crear_tablespaces.sql
--  Diseno fisico: tablespaces separados para datos e indices, y el
--  usuario dueno del esquema con sus cuotas.
--
--  EJECUTAR COMO:  system  (o cualquier usuario con DBA)
--  CONECTADO A:    la PDB, NO a CDB$ROOT
--                  sqlplus system/<clave>@localhost:1521/FREEPDB1
--
--  OJO CON EL NOMBRE DEL SERVICIO: en Oracle AI Database Free (26ai/23ai)
--  y en el contenedor gvenzl/oracle-free la PDB se llama FREEPDB1. Solo en
--  instalaciones antiguas de Express Edition se llama XEPDB1. Si sale
--  ORA-12514 es eso. Para saberlo:  lsnrctl status
--
--  Es idempotente: se puede volver a correr sin borrar nada.
-- =====================================================================

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET LINESIZE 140
SET PAGESIZE 60

-- Si algo falla, PARAR. Sin esto, SQL*Plus imprime el error y sigue
-- ejecutando: un fallo en el paso 0 encadenaria cuatro errores mas en los
-- pasos siguientes, que es justo lo que no se quiere en vivo.
-- (EXIT cierra la ventana de SQL*Plus; es intencional.)
WHENEVER SQLERROR EXIT FAILURE

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 0 - GUARDA DE CONTENEDOR                                     #
PROMPT ######################################################################
PROMPT
-- Desde 21c toda base Oracle es un CDB. Crear un tablespace o un usuario
-- normal en CDB$ROOT es el error mas comun del multitenant: el objeto queda
-- en el contenedor raiz y no lo ve ninguna PDB. Este bloque lo impide.

DECLARE
  v_con VARCHAR2(128);
BEGIN
  SELECT SYS_CONTEXT('USERENV', 'CON_NAME') INTO v_con FROM dual;
  DBMS_OUTPUT.PUT_LINE('Contenedor actual .... ' || v_con);
  DBMS_OUTPUT.PUT_LINE('Usuario conectado .... ' || USER);

  IF v_con = 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20001,
      'Estas en CDB$ROOT y aqui no se crea nada. Reconectate a la PDB: ' ||
      'sqlplus system/<clave>@localhost:1521/FREEPDB1');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: estamos dentro de una PDB.');
END;
/

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 1 - TABLESPACES                                              #
PROMPT ######################################################################
PROMPT
-- El directorio de los datafiles no se escribe a mano: se deduce de donde
-- ya vive el datafile de SYSTEM. Asi el script corre igual en Windows y en
-- Linux, y en cualquier instalacion, sin editar rutas.

DECLARE
  v_file VARCHAR2(513);
  v_sep  VARCHAR2(1);
  v_dir  VARCHAR2(513);

  PROCEDURE crear_ts(p_nombre VARCHAR2,
                     p_size   VARCHAR2,
                     p_next   VARCHAR2,
                     p_max    VARCHAR2) IS
    v_c   PLS_INTEGER;
    v_ddl VARCHAR2(2000);
  BEGIN
    SELECT COUNT(*) INTO v_c
      FROM dba_tablespaces
     WHERE tablespace_name = UPPER(p_nombre);

    IF v_c > 0 THEN
      DBMS_OUTPUT.PUT_LINE('   ya existia ... ' || UPPER(p_nombre));
      RETURN;
    END IF;

    v_ddl := 'CREATE TABLESPACE ' || p_nombre
          || ' DATAFILE ''' || v_dir || LOWER(p_nombre) || '_01.dbf'''
          || ' SIZE ' || p_size
          || ' AUTOEXTEND ON NEXT ' || p_next || ' MAXSIZE ' || p_max
          || ' EXTENT MANAGEMENT LOCAL AUTOALLOCATE'
          || ' SEGMENT SPACE MANAGEMENT AUTO';

    EXECUTE IMMEDIATE v_ddl;
    DBMS_OUTPUT.PUT_LINE('   creado ...... ' || UPPER(p_nombre)
                         || '  (' || p_size || ', crece ' || p_next
                         || ' hasta ' || p_max || ')');
  END crear_ts;

BEGIN
  SELECT file_name INTO v_file
    FROM dba_data_files
   WHERE tablespace_name = 'SYSTEM'
     AND ROWNUM = 1;

  v_sep := CASE WHEN INSTR(v_file, '\') > 0 THEN '\' ELSE '/' END;
  v_dir := SUBSTR(v_file, 1, INSTR(v_file, v_sep, -1));

  DBMS_OUTPUT.PUT_LINE('Directorio de datafiles: ' || v_dir);
  DBMS_OUTPUT.PUT_LINE('');

  -- Datos e indices por separado. El tamano inicial no es un numero al azar:
  -- es la estimacion del esquema completo con holgura, para no depender del
  -- autoextend en la operacion normal.
  crear_ts('ts_org_datos',   '100M', '20M', '2G');
  crear_ts('ts_org_indices',  '50M', '10M', '1G');
END;
/

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 2 - USUARIO DUENO DEL ESQUEMA                                #
PROMPT ######################################################################
PROMPT

DECLARE
  v_n PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM dba_users WHERE username = 'ORG_APP';

  IF v_n = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER org_app IDENTIFIED BY "Demo#2026" '
                   || 'DEFAULT TABLESPACE ts_org_datos';
    DBMS_OUTPUT.PUT_LINE('   usuario ORG_APP creado.');
  ELSE
    -- Si quedo de un ensayo anterior con otra clave, el demo se caeria
    -- manana con ORA-01017 al conectarse. Se reasienta siempre.
    EXECUTE IMMEDIATE 'ALTER USER org_app IDENTIFIED BY "Demo#2026"';
    DBMS_OUTPUT.PUT_LINE('   usuario ORG_APP ya existia; clave reasentada.');
  END IF;
END;
/

-- Las cuotas se reaplican siempre: son idempotentes por naturaleza.
-- SIN la cuota sobre ts_org_indices, todos los CREATE INDEX fallan con
-- ORA-01950 aunque el tablespace exista. Es un error clasico.
ALTER USER org_app QUOTA UNLIMITED ON ts_org_datos;
ALTER USER org_app QUOTA UNLIMITED ON ts_org_indices;

-- Privilegios minimos: solo lo que el esquema necesita para existir.
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW TO org_app;

PROMPT    cuotas y privilegios aplicados.

-- SEGURO OPCIONAL: si la instancia estuviera endurecida y le hubieran quitado
-- el EXECUTE a PUBLIC de estos paquetes, el script 05 moriria con PLS-00201.
-- En una instalacion recien hecha NO hace falta: PUBLIC ya los tiene.
-- Descomentar solo si 05 falla por privilegios.
-- GRANT EXECUTE ON SYS.DBMS_XPLAN TO org_app;
-- GRANT EXECUTE ON SYS.DBMS_STATS TO org_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON SYS.PLAN_TABLE$ TO org_app;

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 3 - VERIFICACION                                             #
PROMPT ######################################################################
PROMPT

-- Ya paso todo el DDL: de aqui en adelante un error solo afecta a una
-- consulta de verificacion, asi que no hace falta abortar.
WHENEVER SQLERROR CONTINUE NONE
SET FEEDBACK ON
COLUMN tablespace_name FORMAT A16      HEADING 'TABLESPACE'
COLUMN file_name       FORMAT A56      HEADING 'DATAFILE'
COLUMN mb              FORMAT 9990     HEADING 'MB'
COLUMN autoext         FORMAT A7       HEADING 'AUTOEXT'
COLUMN max_gb          FORMAT 990.0    HEADING 'MAX GB'

PROMPT --- Los dos tablespaces y sus archivos ------------------------------
SELECT d.tablespace_name,
       d.file_name,
       d.bytes / 1024 / 1024              AS mb,
       d.autoextensible                   AS autoext,
       d.maxbytes / 1024 / 1024 / 1024    AS max_gb
  FROM dba_data_files d
 WHERE d.tablespace_name LIKE 'TS_ORG%'
 ORDER BY d.tablespace_name;

COLUMN nombre FORMAT A16 HEADING 'TABLESPACE'
COLUMN gestion FORMAT A12 HEADING 'EXTENTS'
COLUMN espacio FORMAT A6  HEADING 'SEGMEN'

PROMPT --- Como gestionan el espacio ---------------------------------------
SELECT tablespace_name        AS nombre,
       extent_management      AS gestion,
       allocation_type        AS asignacion,
       segment_space_management AS espacio,
       status
  FROM dba_tablespaces
 WHERE tablespace_name LIKE 'TS_ORG%'
 ORDER BY tablespace_name;

COLUMN username FORMAT A12
COLUMN tablespace_name FORMAT A18
PROMPT --- Cuotas del usuario ---------------------------------------------
SELECT username, tablespace_name,
       CASE WHEN max_bytes < 0 THEN 'UNLIMITED'
            ELSE TO_CHAR(max_bytes / 1024 / 1024) || ' MB' END AS cuota
  FROM dba_ts_quotas
 WHERE username = 'ORG_APP';

PROMPT
PROMPT === Listo. Siguiente:  conectarse como org_app y correr 02_crear_modelo.sql
PROMPT ===   sqlplus org_app/"Demo#2026"@localhost:1521/FREEPDB1
PROMPT
