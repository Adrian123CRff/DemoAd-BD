-- =====================================================================
--  06_bitacora_control_parametros.sql
--  La otra mitad de la arquitectura fisica: los archivos que NO son
--  datafiles (bitacora y control), los parametros de la instancia, y
--  los procesos y la memoria que aparecen en la pizarra de clase.
--
--  EJECUTAR COMO:  system  (o cualquier usuario con DBA)
--                  sqlplus system/<clave>@localhost:1521/FREEPDB1
--
--  POR QUE NO ORG_APP: el esquema tiene solo CREATE SESSION, CREATE TABLE
--  y CREATE VIEW. Ninguna vista V$ le es visible, y esta bien que asi sea:
--  el dueno de los datos no administra la instancia.
--
--  Es de SOLO LECTURA. No crea, no borra y no modifica nada, asi que se
--  puede correr en cualquier momento y las veces que haga falta.
--
--  LA IDEA QUE ORDENA TODO EL SCRIPT:
--    tablespaces y datafiles ..... son de la PDB   (eso es el script 01)
--    bitacora, control, memoria .. son del CDB / de la INSTANCIA
--  Un contenedor enchufado no tiene redo log propio ni archivo de control
--  propio: usa los de la instancia que lo hospeda. Por eso el script 01
--  exige estar en la PDB y este no.
-- =====================================================================

SET SERVEROUTPUT ON
SET FEEDBACK ON
SET LINESIZE 180
SET PAGESIZE 200

-- A diferencia de 01, aqui NO se aborta ante un error. Todo son consultas
-- de lectura: si una vista no esta disponible en esta instalacion, se
-- pierde esa consulta y las demas siguen. Abortar seria peor.
WHENEVER SQLERROR CONTINUE NONE

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 0 - DONDE ESTAMOS                                            #
PROMPT ######################################################################
PROMPT

DECLARE
  v_con VARCHAR2(128);
  v_ins VARCHAR2(128);
BEGIN
  SELECT SYS_CONTEXT('USERENV', 'CON_NAME'),
         SYS_CONTEXT('USERENV', 'INSTANCE_NAME')
    INTO v_con, v_ins
    FROM dual;

  DBMS_OUTPUT.PUT_LINE('Instancia ............ ' || v_ins);
  DBMS_OUTPUT.PUT_LINE('Contenedor actual .... ' || v_con);
  DBMS_OUTPUT.PUT_LINE('Usuario conectado .... ' || USER);
  DBMS_OUTPUT.PUT_LINE('');

  IF v_con = 'CDB$ROOT' THEN
    DBMS_OUTPUT.PUT_LINE('Estas en la raiz. Todo lo de este script se ve completo.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Estas en una PDB. Lo que sigue pertenece a la INSTANCIA,');
    DBMS_OUTPUT.PUT_LINE('no a este contenedor: la PDB los ve, pero no son suyos.');
  END IF;
END;
/

COLUMN base       FORMAT A12  HEADING 'BASE'
COLUMN dbid       FORMAT 9999999999 HEADING 'DBID'
COLUMN creada     FORMAT A12  HEADING 'CREADA'
COLUMN modo_log   FORMAT A12  HEADING 'LOG MODE'
COLUMN apertura   FORMAT A12  HEADING 'OPEN MODE'

PROMPT --- La base de datos, vista desde adentro ---------------------------
SELECT name                          AS base,
       dbid,
       TO_CHAR(created, 'DD/MM/YYYY') AS creada,
       log_mode                      AS modo_log,
       open_mode                     AS apertura
  FROM v$database;

PROMPT
PROMPT --> LOG MODE dice NOARCHIVELOG en una instalacion recien hecha. Eso
PROMPT     significa que la bitacora se recicla y se pierde: hay recuperacion
PROMPT     ante caida de instancia, pero NO hay recuperacion a un punto en el
PROMPT     tiempo. Para un demo esta bien; en produccion no lo estaria.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 1 - LA BITACORA (REDO LOG)                                   #
PROMPT ######################################################################
PROMPT
-- Este es el LGWR de la pizarra. La regla que lo explica todo se llama
-- write-ahead logging: antes de que un COMMIT devuelva el control, el
-- cambio ya esta escrito en la bitacora, aunque el bloque modificado siga
-- solamente en memoria y todavia no haya llegado al datafile.
--
-- De ahi se sigue algo que sorprende: quien confirma la transaccion no es
-- DBWR escribiendo datos, es LGWR escribiendo el registro del cambio. El
-- datafile se pone al dia despues, cuando DBWR quiera. Si la instancia se
-- cae en medio, al arrancar Oracle relee la bitacora y reconstruye lo que
-- no habia bajado a disco.

COLUMN grupo     FORMAT 999      HEADING 'GRUPO'
COLUMN secuencia FORMAT 99999    HEADING 'SECUENC'
COLUMN mb        FORMAT 9990     HEADING 'MB'
COLUMN miembros  FORMAT 999      HEADING 'MIEMBR'
COLUMN archivado FORMAT A9       HEADING 'ARCHIVADO'
COLUMN estado    FORMAT A10      HEADING 'ESTADO'
COLUMN primer_ts FORMAT A17      HEADING 'PRIMER CAMBIO'

PROMPT --- Los grupos de la bitacora ---------------------------------------
SELECT group#                              AS grupo,
       sequence#                           AS secuencia,
       bytes / 1024 / 1024                 AS mb,
       members                             AS miembros,
       archived                            AS archivado,
       status                              AS estado,
       TO_CHAR(first_time, 'DD/MM HH24:MI:SS') AS primer_ts
  FROM v$log
 ORDER BY group#;

PROMPT
PROMPT --> Los grupos rotan en circulo: se llena el 1, se pasa al 2, y al
PROMPT     volver al 1 se sobreescribe. Por eso son varios y no uno solo.
PROMPT     Estados:  CURRENT  = donde LGWR escribe ahora mismo
PROMPT               ACTIVE   = ya cerrado, todavia hace falta para recuperar
PROMPT               INACTIVE = ya no hace falta, se puede reutilizar
PROMPT

COLUMN tipo    FORMAT A8   HEADING 'TIPO'
COLUMN archivo FORMAT A96  HEADING 'ARCHIVO EN DISCO'

PROMPT --- Los archivos fisicos de cada grupo ------------------------------
SELECT group#  AS grupo,
       status  AS estado,
       type    AS tipo,
       member  AS archivo
  FROM v$logfile
 ORDER BY group#, member;

PROMPT
PROMPT --> Si un grupo tuviera dos o mas archivos, eso es MULTIPLEXADO: la
PROMPT     misma bitacora escrita en dos discos distintos, para que perder
PROMPT     uno no cueste la base. En esta instalacion hay un solo miembro
PROMPT     por grupo, que es el valor por omision y no una decision nuestra.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 2 - LOS ARCHIVOS DE CONTROL                                  #
PROMPT ######################################################################
PROMPT
-- El archivo de control es el indice de la base: guarda el nombre y el DBID,
-- la ruta de TODOS los datafiles y de TODOS los archivos de bitacora, y el
-- SCN del ultimo checkpoint. Es diminuto y es imprescindible: sin el, la
-- instancia no sabe que archivos abrir y no monta.
--
-- Es tambien la respuesta a una pregunta razonable: como sabe Oracle al
-- arrancar donde estan los datafiles, si en el script 01 nosotros elegimos
-- la ruta a mano. No lo adivina: quedo anotado aqui cuando se creo el
-- tablespace.

COLUMN kb        FORMAT 9,999,990 HEADING 'KB'
COLUMN bloques   FORMAT 999,990   HEADING 'BLOQUES'

PROMPT --- Los archivos de control ----------------------------------------
SELECT status                              AS estado,
       name                                AS archivo,
       block_size * file_size_blks / 1024  AS kb,
       file_size_blks                      AS bloques
  FROM v$controlfile;

PROMPT
PROMPT --> Aqui el multiplexado si suele estar puesto por omision: dos o tres
PROMPT     copias identicas en rutas distintas. Oracle las escribe todas y
PROMPT     con que sobreviva una, la base monta. Cuestan kilobytes.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 3 - LOS PARAMETROS DE LA INSTANCIA                           #
PROMPT ######################################################################
PROMPT
-- Los parametros viven en el SPFILE y se leen al arrancar. Definen el
-- tamano de la memoria, el tamano de bloque, cuantos procesos y sesiones se
-- admiten y donde estan los archivos de control.
--
-- DB_BLOCK_SIZE es el que cierra la cadena de la pizarra: BD -> tablespace
-- -> segmento -> extent -> BLOQUE. Ese numero se fija al crear la base y no
-- se puede cambiar despues. Todo el resto del almacenamiento se mide en
-- multiplos de el.

COLUMN parametro FORMAT A26  HEADING 'PARAMETRO'
COLUMN valor     FORMAT A54  HEADING 'VALOR'
COLUMN defecto   FORMAT A8   HEADING 'ES DEF?'
COLUMN pdb_mod   FORMAT A8   HEADING 'PDB MOD?'

PROMPT --- Los parametros que importan para este trabajo -------------------
SELECT name           AS parametro,
       value          AS valor,
       isdefault      AS defecto,
       ispdb_modifiable AS pdb_mod
  FROM v$parameter
 WHERE name IN ('db_name', 'db_block_size', 'db_files', 'control_files',
                'sga_target', 'sga_max_size', 'pga_aggregate_target',
                'log_buffer', 'processes', 'sessions',
                'db_recovery_file_dest', 'db_recovery_file_dest_size',
                'undo_tablespace', 'spfile')
 ORDER BY name;

PROMPT
PROMPT --> Miren la columna PDB MOD?. Los que dicen FALSE pertenecen a la
PROMPT     instancia completa y una PDB no los puede tocar: el tamano de
PROMPT     bloque, los archivos de control, la memoria. Esa columna es la
PROMPT     prueba de la frase del encabezado de este script.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 4 - LA SGA Y LOS PROCESOS DE LA PIZARRA                      #
PROMPT ######################################################################
PROMPT
-- La arquitectura fisica de la clase eran tres cosas: Procesos, Memoria y
-- Archivos. Los archivos ya estan en los pasos 1 a 3. Aqui van las otras dos.

COLUMN componente FORMAT A34  HEADING 'COMPONENTE DE LA SGA'
COLUMN redimens   FORMAT A9   HEADING 'AJUSTABLE'

PROMPT --- La memoria compartida, por partes -------------------------------
SELECT name                 AS componente,
       bytes / 1024 / 1024  AS mb,
       resizeable           AS redimens
  FROM v$sgainfo
 ORDER BY bytes DESC;

PROMPT
PROMPT --> Buffer Cache es donde viven los bloques leidos de los datafiles;
PROMPT     Redo Buffers es la antesala de la bitacora; Shared Pool guarda
PROMPT     las sentencias ya compiladas y el diccionario. La edicion gratuita
PROMPT     limita la SGA a 2 GB, asi que estos numeros son pequenos a
PROMPT     proposito y no reflejan una instalacion de produccion.
PROMPT

COLUMN proceso     FORMAT A8   HEADING 'PROCESO'
COLUMN pid_so      FORMAT A10  HEADING 'PID EN SO'
COLUMN descripcion FORMAT A56  HEADING 'QUE HACE'

PROMPT --- Los procesos de fondo, los mismos de la pizarra -----------------
SELECT p.pname       AS proceso,
       p.spid        AS pid_so,
       b.description AS descripcion
  FROM v$process p
  JOIN v$bgprocess b ON b.paddr = p.addr
 WHERE p.pname IN ('DBW0', 'LGWR', 'CKPT', 'SMON', 'PMON', 'ARC0', 'MMON')
 ORDER BY p.pname;

PROMPT
PROMPT --> DBW0 y LGWR son el DBWRITER y el LOGWRITER del diagrama, y tienen
PROMPT     PID del sistema operativo: son procesos reales, no una metafora.
PROMPT     CKPT marca el checkpoint que sincroniza memoria y datafiles, y es
PROMPT     el que anota el SCN en el archivo de control del paso 2.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  PASO 5 - SEGMENTOS, EXTENTS Y BLOQUES                             #
PROMPT ######################################################################
PROMPT
-- Cierre de la cadena, ahora sobre nuestros propios datos. El script 02 ya
-- mostro en que tablespace quedo cada objeto; esto baja un nivel mas y
-- muestra de que esta hecho cada segmento.
--
-- Si esto sale vacio es porque todavia no se corrio 02_crear_modelo.sql.

COLUMN objeto     FORMAT A24 HEADING 'OBJETO'
COLUMN tipo       FORMAT A12 HEADING 'TIPO'
COLUMN tablespace FORMAT A16 HEADING 'TABLESPACE'
COLUMN extents    FORMAT 9,990 HEADING 'EXTENTS'
COLUMN bloques    FORMAT 999,990 HEADING 'BLOQUES'
COLUMN kb         FORMAT 9,999,990 HEADING 'KB'

PROMPT --- De que esta hecho cada segmento del esquema ORG_APP -------------
SELECT segment_name          AS objeto,
       segment_type          AS tipo,
       tablespace_name       AS tablespace,
       COUNT(*)              AS extents,
       SUM(blocks)           AS bloques,
       SUM(bytes) / 1024     AS kb
  FROM dba_extents
 WHERE owner = 'ORG_APP'
 GROUP BY segment_name, segment_type, tablespace_name
 ORDER BY tablespace_name, segment_type, segment_name;

PROMPT
PROMPT --> BLOQUES x DB_BLOCK_SIZE (paso 3) da exactamente los KB de la ultima
PROMPT     columna. Esa multiplicacion es la jerarquia de almacenamiento
PROMPT     completa, medida sobre el organigrama y no sobre un ejemplo.
PROMPT --> Y noten que un segmento nunca esta a caballo entre dos tablespaces:
PROMPT     por eso separar datos e indices es una separacion real y no una
PROMPT     etiqueta.
PROMPT

PROMPT
PROMPT === Fin del anexo de arquitectura fisica.
PROMPT === Nada de lo que hizo este script modifico la base.
PROMPT
