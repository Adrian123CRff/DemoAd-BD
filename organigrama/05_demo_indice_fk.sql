-- =====================================================================
--  05_demo_indice_fk.sql
--  El momento que demuestra por que hay que indexar las FOREIGN KEY.
--
--  EJECUTAR COMO:  org_app
--
--  ADVERTENCIA DE HONESTIDAD, y hay que decirla en voz alta:
--  el modelo del organigrama tiene 29 filas. A esa escala el optimizador
--  escoge un full scan y HACE BIEN: leer 29 filas de un tiron es mas
--  barato que abrir un indice. Sostener lo contrario seria falso.
--  Por eso el efecto del indice se mide sobre una tabla de carga de
--  200 000 filas con la misma forma (FK autorreferente), que es donde el
--  problema aparece de verdad.
-- =====================================================================

--  IMPORTANTE: correr este script COMPLETO en UNA SOLA sesion de SQL*Plus,
--  sin reconectar en medio. La PLAN_TABLE es una tabla temporal global de
--  sesion: si se reconecta, el PASO 4 devuelve "no rows selected" y el
--  momento clave del demo se cae en silencio.
-- =====================================================================

SET LINESIZE 200
SET PAGESIZE 200
SET FEEDBACK ON
SET SERVEROUTPUT ON
COLUMN plan_table_output FORMAT A180

-- Por si un ensayo anterior quedo a medias (Ctrl-C) y dejo filas viejas:
-- sin esto el PASO 4 mostraria arboles duplicados.
DELETE FROM plan_table WHERE statement_id IN ('sin_indice', 'con_indice');
COMMIT;

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 1 - TABLA DE CARGA: 200 000 FILAS, MISMA FORMA               #
PROMPT ######################################################################
PROMPT

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE empleado_carga CASCADE CONSTRAINTS PURGE';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE empleado_carga (
  id_empleado  NUMBER(8)      NOT NULL,
  nombre       VARCHAR2(60)   NOT NULL,
  id_jefe      NUMBER(8),
  CONSTRAINT pk_emp_carga PRIMARY KEY (id_empleado)
    USING INDEX TABLESPACE ts_org_indices
) TABLESPACE ts_org_datos;

PROMPT    Cargando 200 000 filas...

-- Arbol sintetico: cada persona reporta a TRUNC(id/3), asi que cada jefe
-- tiene unos 3 subordinados y el arbol queda con ~11 niveles.
--
-- El generador es un producto de dos generadores de 1000 x 200 en lugar de
-- un CONNECT BY LEVEL <= 200000 directo: el directo construye una pila de
-- 200 000 niveles y en un XE con PGA apretada puede dar ORA-30009.
INSERT INTO empleado_carga (id_empleado, nombre, id_jefe)
SELECT ROWNUM,
       'Empleado numero ' || ROWNUM,
       CASE WHEN ROWNUM = 1 THEN NULL
            ELSE GREATEST(TRUNC(ROWNUM / 3), 1)
       END
  FROM (SELECT 1 FROM dual CONNECT BY LEVEL <= 1000),
       (SELECT 1 FROM dual CONNECT BY LEVEL <=  200);

COMMIT;

-- La FK se agrega DESPUES de la carga: validar 200 000 filas de una vez es
-- mucho mas rapido que fila por fila durante el INSERT.
ALTER TABLE empleado_carga
  ADD CONSTRAINT fk_carga_jefe FOREIGN KEY (id_jefe)
      REFERENCES empleado_carga (id_empleado);

-- Sin estadisticas el optimizador trabaja con valores por defecto y el
-- resultado del demo deja de ser reproducible. Esto no es opcional.
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname          => USER,
    tabname          => 'EMPLEADO_CARGA',
    cascade          => TRUE,
    method_opt       => 'FOR ALL COLUMNS SIZE AUTO');
END;
/

COLUMN tabla FORMAT A18
COLUMN filas FORMAT 999,999,999
SELECT table_name AS tabla, num_rows AS filas, blocks AS bloques
  FROM user_tables WHERE table_name = 'EMPLEADO_CARGA';

PROMPT
PROMPT --> Fijense en BLOQUES: eso es la jerarquia de la clase. La tabla es
PROMPT     un segmento hecho de extents hechos de bloques, y un full scan
PROMPT     los lee TODOS.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 2 - SIN INDICE EN LA FK                                      #
PROMPT ######################################################################
PROMPT
-- La FK fk_carga_jefe existe, pero Oracle NO le creo indice. Nunca lo hace.

COLUMN nombre_indice FORMAT A24
SELECT COUNT(*) AS indices_sobre_id_jefe
  FROM user_ind_columns
 WHERE table_name = 'EMPLEADO_CARGA'
   AND column_name = 'ID_JEFE';

PROMPT
PROMPT --- Plan de ejecucion SIN indice ------------------------------------
EXPLAIN PLAN SET STATEMENT_ID = 'sin_indice' FOR
SELECT COUNT(*) FROM empleado_carga WHERE id_jefe = 41234;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'sin_indice', 'BASIC +COST +ROWS'));

PROMPT
PROMPT --- Y cuanto cuesta de verdad: 2000 busquedas seguidas -------------
SET TIMING ON
DECLARE
  v NUMBER;
BEGIN
  FOR i IN 1 .. 2000 LOOP
    SELECT COUNT(*) INTO v FROM empleado_carga WHERE id_jefe = 40000 + i;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('2000 busquedas completadas SIN indice.');
END;
/
SET TIMING OFF

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 3 - EL MISMO CODIGO, CON EL INDICE                           #
PROMPT ######################################################################
PROMPT

CREATE INDEX ix_carga_jefe ON empleado_carga (id_jefe)
  TABLESPACE ts_org_indices;

-- El MISMO method_opt que la primera vez. Si se omite, Oracle puede
-- construir ahora un histograma que antes no existia (las 2000 consultas
-- anteriores registraron uso de la columna) y ya no seria "el mismo codigo
-- con las mismas estadisticas, solo cambia el indice".
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname          => USER,
    tabname          => 'EMPLEADO_CARGA',
    cascade          => TRUE,
    method_opt       => 'FOR ALL COLUMNS SIZE AUTO');
END;
/

PROMPT --- Ahora si hay indice sobre la FK --------------------------------
SELECT COUNT(*) AS indices_sobre_id_jefe
  FROM user_ind_columns
 WHERE table_name = 'EMPLEADO_CARGA'
   AND column_name = 'ID_JEFE';

PROMPT
PROMPT --- Plan de ejecucion CON indice ------------------------------------
EXPLAIN PLAN SET STATEMENT_ID = 'con_indice' FOR
SELECT COUNT(*) FROM empleado_carga WHERE id_jefe = 41234;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'con_indice', 'BASIC +COST +ROWS'));

PROMPT
PROMPT --- Las mismas 2000 busquedas -------------------------------------
SET TIMING ON
DECLARE
  v NUMBER;
BEGIN
  FOR i IN 1 .. 2000 LOOP
    SELECT COUNT(*) INTO v FROM empleado_carga WHERE id_jefe = 40000 + i;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('2000 busquedas completadas CON indice.');
END;
/
SET TIMING OFF

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 4 - LOS DOS COSTOS, LADO A LADO                              #
PROMPT ######################################################################
PROMPT

COLUMN escenario FORMAT A14
COLUMN operacion FORMAT A34
COLUMN costo     FORMAT 999,999 HEADING 'COSTO'
COLUMN filas_est FORMAT 999,999 HEADING 'FILAS EST'

SELECT statement_id                AS escenario,
       LPAD(' ', 2 * (LEVEL - 1)) || operation ||
         CASE WHEN options IS NOT NULL THEN ' ' || options END AS operacion,
       cost                        AS costo,
       cardinality                 AS filas_est
  FROM plan_table
 START WITH id = 0
 CONNECT BY PRIOR id = parent_id AND PRIOR statement_id = statement_id
 ORDER BY statement_id, id;

PROMPT
PROMPT --> TABLE ACCESS FULL contra INDEX RANGE SCAN, y la diferencia de
PROMPT     costo entre los dos. Ese es el precio de olvidar el indice.
PROMPT --> Y el segundo motivo, que no depende del tamano: con la FK sin
PROMPT     indexar, borrar o modificar la PK del padre toma un bloqueo de
PROMPT     TABLA sobre el hijo, no de fila. En concurrencia eso se ve como
PROMPT     bloqueos que nadie sabe explicar.
PROMPT

-- La tabla de carga ya cumplio: se borra para no dejar 200 000 filas de
-- basura en el esquema del demo.
PROMPT --- Limpiando la tabla de carga -------------------------------------
DROP TABLE empleado_carga CASCADE CONSTRAINTS PURGE;
DELETE FROM plan_table WHERE statement_id IN ('sin_indice', 'con_indice');
COMMIT;

PROMPT
PROMPT === Fin del demo.
PROMPT === Para dejar la base como estaba:  99_limpiar.sql (como system)
PROMPT
