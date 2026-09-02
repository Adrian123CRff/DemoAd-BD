-- =====================================================================
--  02_crear_modelo.sql
--  El modelo del organigrama funcional.
--
--  EJECUTAR COMO:  org_app
--                  sqlplus org_app/"Demo#2026"@localhost:1521/FREEPDB1
--
--  Los tres patrones del modelo relacional, uno por tabla:
--    * cadena 1:N ........ PUESTO <- EMPLEADO, UNIDAD_ORG <- PROYECTO
--    * autorreferencia .... UNIDAD_ORG.id_unidad_padre, EMPLEADO.id_jefe
--    * tabla puente M:N ... ASIGNACION (empleado <-> proyecto)
--
--  Es idempotente: borra y recrea.
-- =====================================================================

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET LINESIZE 140
SET PAGESIZE 60

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 0 - LIMPIAR LO ANTERIOR                                      #
PROMPT ######################################################################
PROMPT
-- Oracle no tiene CREATE OR REPLACE TABLE. El patron idempotente es
-- intentar el DROP y tragarse el ORA-00942 (tabla no existe).
-- El orden importa: primero los hijos, despues los padres.

DECLARE
  TYPE t_lista IS TABLE OF VARCHAR2(30);
  v_tablas t_lista := t_lista('asignacion', 'proyecto', 'empleado',
                              'puesto', 'unidad_org', 'empleado_carga');
BEGIN
  FOR i IN 1 .. v_tablas.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE ' || v_tablas(i)
                     || ' CASCADE CONSTRAINTS PURGE';
      DBMS_OUTPUT.PUT_LINE('   borrada .... ' || UPPER(v_tablas(i)));
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -942 THEN
          DBMS_OUTPUT.PUT_LINE('   no existia . ' || UPPER(v_tablas(i)));
        ELSE
          RAISE;
        END IF;
    END;
  END LOOP;
END;
/

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 1 - UNIDAD_ORG   (autorreferente: jerarquia de unidades)     #
PROMPT ######################################################################
PROMPT

CREATE TABLE unidad_org (
  id_unidad        NUMBER(6)     NOT NULL,
  nombre           VARCHAR2(80)  NOT NULL,
  tipo             VARCHAR2(20)  NOT NULL,
  id_unidad_padre  NUMBER(6),
  --                             ^ NULL solo en la raiz del organigrama
  CONSTRAINT pk_unidad PRIMARY KEY (id_unidad)
    USING INDEX TABLESPACE ts_org_indices,
  CONSTRAINT uk_unidad_nombre UNIQUE (nombre)
    USING INDEX TABLESPACE ts_org_indices,
  CONSTRAINT fk_unidad_padre FOREIGN KEY (id_unidad_padre)
    REFERENCES unidad_org (id_unidad),
  -- Impide el caso trivial de que una unidad sea su propia madre.
  -- OJO: no impide un ciclo A->B->A. Eso no es expresable con un CHECK.
  CONSTRAINT ck_unidad_no_self CHECK (id_unidad <> id_unidad_padre),
  CONSTRAINT ck_unidad_tipo CHECK
    (tipo IN ('DIRECCION', 'VICEPRESIDENCIA', 'AREA', 'SQUAD'))
) TABLESPACE ts_org_datos;

PROMPT    UNIDAD_ORG creada.

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 2 - PUESTO   (catalogo, cadena 1:N pura)                     #
PROMPT ######################################################################
PROMPT

CREATE TABLE puesto (
  id_puesto         NUMBER(6)     NOT NULL,
  nombre            VARCHAR2(80)  NOT NULL,
  nivel_jerarquico  NUMBER(2)     NOT NULL,
  familia           VARCHAR2(30)  NOT NULL,
  CONSTRAINT pk_puesto PRIMARY KEY (id_puesto)
    USING INDEX TABLESPACE ts_org_indices,
  CONSTRAINT uk_puesto_nombre UNIQUE (nombre)
    USING INDEX TABLESPACE ts_org_indices,
  CONSTRAINT ck_puesto_nivel CHECK (nivel_jerarquico BETWEEN 1 AND 10)
) TABLESPACE ts_org_datos;

PROMPT    PUESTO creada.

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 3 - EMPLEADO   (la SEGUNDA autorreferencia: linea de reporte) #
PROMPT ######################################################################
PROMPT
-- Aqui esta la decision de diseno del trabajo: la linea de reporte
-- (id_jefe) es INDEPENDIENTE de la jerarquia de unidades (id_unidad).
-- Suelen coincidir, pero no siempre, y esa diferencia es lo que hace
-- "funcional" al organigrama. Deducir una de la otra seria un error.

CREATE TABLE empleado (
  id_empleado    NUMBER(8)      NOT NULL,
  nombre         VARCHAR2(120)  NOT NULL,
  email          VARCHAR2(120)  NOT NULL,
  fecha_ingreso  DATE           NOT NULL,
  id_unidad      NUMBER(6)      NOT NULL,
  id_puesto      NUMBER(6)      NOT NULL,
  id_jefe        NUMBER(8),
  --                            ^ NULL solo en la raiz
  CONSTRAINT pk_empleado PRIMARY KEY (id_empleado)
    USING INDEX TABLESPACE ts_org_indices,
  CONSTRAINT uk_empleado_email UNIQUE (email)
    USING INDEX TABLESPACE ts_org_indices,
  CONSTRAINT fk_emp_unidad FOREIGN KEY (id_unidad)
    REFERENCES unidad_org (id_unidad),
  CONSTRAINT fk_emp_puesto FOREIGN KEY (id_puesto)
    REFERENCES puesto (id_puesto),
  CONSTRAINT fk_emp_jefe FOREIGN KEY (id_jefe)
    REFERENCES empleado (id_empleado),
  CONSTRAINT ck_emp_no_self CHECK (id_empleado <> id_jefe)
) TABLESPACE ts_org_datos;

PROMPT    EMPLEADO creada.

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 4 - PROYECTO                                                 #
PROMPT ######################################################################
PROMPT

CREATE TABLE proyecto (
  id_proyecto  NUMBER(8)      NOT NULL,
  nombre       VARCHAR2(120)  NOT NULL,
  id_unidad    NUMBER(6)      NOT NULL,
  estado       VARCHAR2(20)   NOT NULL,
  CONSTRAINT pk_proyecto PRIMARY KEY (id_proyecto)
    USING INDEX TABLESPACE ts_org_indices,
  CONSTRAINT fk_proy_unidad FOREIGN KEY (id_unidad)
    REFERENCES unidad_org (id_unidad),
  CONSTRAINT ck_proy_estado CHECK
    (estado IN ('PLANIFICADO', 'EN_CURSO', 'CERRADO'))
) TABLESPACE ts_org_datos;

PROMPT    PROYECTO creada.

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 5 - ASIGNACION   (tabla puente: resuelve el M:N)             #
PROMPT ######################################################################
PROMPT
-- Una persona esta en varios proyectos y un proyecto tiene varias personas.
-- El modelo relacional no puede implementar eso directamente: solo sabe
-- hacer 1:N. La solucion es esta tabla, con PK compuesta por las dos FK.

CREATE TABLE asignacion (
  id_empleado     NUMBER(8)     NOT NULL,
  id_proyecto     NUMBER(8)     NOT NULL,
  rol             VARCHAR2(40)  NOT NULL,
  pct_dedicacion  NUMBER(3)     NOT NULL,
  CONSTRAINT pk_asignacion PRIMARY KEY (id_empleado, id_proyecto)
    USING INDEX TABLESPACE ts_org_indices,
  CONSTRAINT fk_asig_emp FOREIGN KEY (id_empleado)
    REFERENCES empleado (id_empleado),
  CONSTRAINT fk_asig_proy FOREIGN KEY (id_proyecto)
    REFERENCES proyecto (id_proyecto),
  CONSTRAINT ck_asig_pct CHECK (pct_dedicacion BETWEEN 1 AND 100)
) TABLESPACE ts_org_datos;

PROMPT    ASIGNACION creada.

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 6 - INDICES SOBRE LAS FOREIGN KEY                            #
PROMPT ######################################################################
PROMPT
-- Oracle crea el indice de las PRIMARY KEY y de las UNIQUE por su cuenta.
-- NUNCA crea el de una FOREIGN KEY. Hay que ponerlos a mano, y hacen falta
-- por dos razones distintas:
--   1) recorrer el arbol busca por id_jefe: sin indice, full scan por nivel
--   2) modificar la PK del padre con la FK del hijo sin indexar bloquea la
--      TABLA hija completa, no la fila
-- Todos van al tablespace de indices, que es el punto del diseno fisico.

CREATE INDEX ix_unidad_padre ON unidad_org (id_unidad_padre) TABLESPACE ts_org_indices;
CREATE INDEX ix_emp_jefe     ON empleado   (id_jefe)         TABLESPACE ts_org_indices;
CREATE INDEX ix_emp_unidad   ON empleado   (id_unidad)       TABLESPACE ts_org_indices;
CREATE INDEX ix_emp_puesto   ON empleado   (id_puesto)       TABLESPACE ts_org_indices;
CREATE INDEX ix_proy_unidad  ON proyecto   (id_unidad)       TABLESPACE ts_org_indices;

-- En ASIGNACION la PK ya cubre (id_empleado, id_proyecto), asi que la FK a
-- empleado esta servida. Falta la otra direccion: "quien esta en este
-- proyecto" no puede usar la PK porque id_proyecto no es su primera columna.
CREATE INDEX ix_asig_proy    ON asignacion (id_proyecto)     TABLESPACE ts_org_indices;

PROMPT    6 indices creados en TS_ORG_INDICES.

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 7 - VERIFICACION DEL DISENO FISICO                           #
PROMPT ######################################################################
PROMPT

SET FEEDBACK ON
COLUMN objeto     FORMAT A24 HEADING 'OBJETO'
COLUMN tipo       FORMAT A12 HEADING 'TIPO'
COLUMN tablespace FORMAT A16 HEADING 'TABLESPACE'

PROMPT --- Cada segmento y en que tablespace quedo --------------------------
PROMPT --- (esta es la prueba de que datos e indices estan separados) -------
SELECT segment_name    AS objeto,
       segment_type    AS tipo,
       tablespace_name AS tablespace
  FROM user_segments
 ORDER BY tablespace_name, segment_type, segment_name;

COLUMN tabla FORMAT A14
COLUMN constraint_name FORMAT A22
COLUMN tipo_r FORMAT A26 HEADING 'TIPO'

PROMPT --- Restricciones declaradas ----------------------------------------
SELECT table_name AS tabla,
       constraint_name,
       CASE constraint_type
         WHEN 'P' THEN 'PRIMARY KEY'
         WHEN 'R' THEN 'FOREIGN KEY'
         WHEN 'U' THEN 'UNIQUE'
         WHEN 'C' THEN 'CHECK / NOT NULL'
       END AS tipo_r
  FROM user_constraints
 WHERE table_name IN ('UNIDAD_ORG','PUESTO','EMPLEADO','PROYECTO','ASIGNACION')
   AND constraint_type IN ('P','R','U')
 ORDER BY table_name, constraint_type;

PROMPT
PROMPT === Listo. Siguiente:  @03_cargar_datos.sql
PROMPT
