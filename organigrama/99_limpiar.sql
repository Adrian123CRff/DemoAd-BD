-- =====================================================================
--  99_limpiar.sql
--  Deja la base exactamente como estaba antes del demo.
--
--  EJECUTAR COMO:  system, conectado a la PDB
--                  sqlplus system/<clave>@localhost:1521/FREEPDB1
--
--  Util para ensayar el demo varias veces desde cero, y para no dejar
--  objetos sueltos en la instancia despues de presentar.
-- =====================================================================

SET SERVEROUTPUT ON
SET FEEDBACK OFF

DECLARE
  v_con VARCHAR2(128);
  v_n   PLS_INTEGER;

  PROCEDURE borrar_ts(p_nombre VARCHAR2) IS
    v_c PLS_INTEGER;
  BEGIN
    SELECT COUNT(*) INTO v_c
      FROM dba_tablespaces WHERE tablespace_name = UPPER(p_nombre);
    IF v_c = 0 THEN
      DBMS_OUTPUT.PUT_LINE('   no existia . ' || UPPER(p_nombre));
      RETURN;
    END IF;
    -- INCLUDING CONTENTS AND DATAFILES borra tambien el archivo del disco.
    EXECUTE IMMEDIATE 'DROP TABLESPACE ' || p_nombre
                   || ' INCLUDING CONTENTS AND DATAFILES';
    DBMS_OUTPUT.PUT_LINE('   borrado .... ' || UPPER(p_nombre));
  END borrar_ts;

BEGIN
  SELECT SYS_CONTEXT('USERENV', 'CON_NAME') INTO v_con FROM dual;
  IF v_con = 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20001,
      'Estas en CDB$ROOT. Conectate a la PDB antes de limpiar.');
  END IF;
  DBMS_OUTPUT.PUT_LINE('Limpiando en el contenedor: ' || v_con);

  -- 1) el usuario y todos sus objetos.
  --    Antes hay que cerrar sus sesiones: si quedo una ventana de SQL*Plus
  --    abierta con org_app, el DROP USER falla con ORA-01940 y entonces
  --    tampoco se borran los tablespaces. Es el tropiezo mas probable al
  --    ensayar el demo varias veces.
  FOR s IN (SELECT sid, serial# AS sn FROM v$session WHERE username = 'ORG_APP') LOOP
    BEGIN
      EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION '''
                     || s.sid || ',' || s.sn || ''' IMMEDIATE';
      DBMS_OUTPUT.PUT_LINE('   sesion cerrada: ' || s.sid || ',' || s.sn);
    EXCEPTION
      WHEN OTHERS THEN NULL;   -- si ya murio sola, da igual
    END;
  END LOOP;

  SELECT COUNT(*) INTO v_n FROM dba_users WHERE username = 'ORG_APP';
  IF v_n > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER org_app CASCADE';
    DBMS_OUTPUT.PUT_LINE('   usuario ORG_APP borrado (con sus objetos).');
  ELSE
    DBMS_OUTPUT.PUT_LINE('   usuario ORG_APP no existia.');
  END IF;

  -- 2) los tablespaces, ahora que ya no tienen segmentos
  borrar_ts('ts_org_indices');
  borrar_ts('ts_org_datos');
END;
/

SET FEEDBACK ON
PROMPT
PROMPT --- Verificacion: no deberia quedar nada -----------------------------
SELECT tablespace_name FROM dba_tablespaces WHERE tablespace_name LIKE 'TS_ORG%';
SELECT username        FROM dba_users       WHERE username = 'ORG_APP';

PROMPT
PROMPT === Base limpia. Se puede volver a correr 01_crear_tablespaces.sql
PROMPT
