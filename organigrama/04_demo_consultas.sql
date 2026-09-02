-- =====================================================================
--  04_demo_consultas.sql
--  Las consultas del demo, en el orden en que se presentan.
--
--  EJECUTAR COMO:  org_app
--
--  Marcadas [NUCLEO] las que no se pueden saltar y [EXTRA] las que se
--  cortan si el tiempo aprieta.
-- =====================================================================

SET LINESIZE 160
SET PAGESIZE 200
SET FEEDBACK ON
SET VERIFY OFF

PROMPT
PROMPT ######################################################################
PROMPT #  1 [NUCLEO]  LA JERARQUIA DE UNIDADES                              #
PROMPT #  La autorreferencia de UNIDAD_ORG recorrida con CONNECT BY.        #
PROMPT ######################################################################
PROMPT

COLUMN estructura FORMAT A46 HEADING 'ESTRUCTURA DE LA EMPRESA'
COLUMN tipo       FORMAT A16 HEADING 'TIPO'
COLUMN nivel      FORMAT 9   HEADING 'NIV'

SELECT LEVEL                                        AS nivel,
       LPAD(' ', (LEVEL - 1) * 3) || nombre         AS estructura,
       tipo
  FROM unidad_org
 START WITH id_unidad_padre IS NULL
 CONNECT BY NOCYCLE PRIOR id_unidad = id_unidad_padre
 ORDER SIBLINGS BY nombre;

PROMPT
PROMPT ######################################################################
PROMPT #  2 [NUCLEO]  EL ORGANIGRAMA DE PERSONAS                            #
PROMPT #  La segunda autorreferencia: EMPLEADO.id_jefe.                     #
PROMPT ######################################################################
PROMPT

COLUMN organigrama FORMAT A44 HEADING 'ORGANIGRAMA'
COLUMN puesto      FORMAT A24 HEADING 'PUESTO'
COLUMN unidad      FORMAT A26 HEADING 'UNIDAD'
COLUMN hoja        FORMAT A4  HEADING 'HOJA'

SELECT LEVEL                                          AS nivel,
       LPAD(' ', (LEVEL - 1) * 3) || e.nombre         AS organigrama,
       p.nombre                                       AS puesto,
       u.nombre                                       AS unidad,
       CASE CONNECT_BY_ISLEAF WHEN 1 THEN 'si' END    AS hoja
  FROM empleado e
  JOIN puesto     p ON p.id_puesto = e.id_puesto
  JOIN unidad_org u ON u.id_unidad = e.id_unidad
 START WITH e.id_jefe IS NULL
 CONNECT BY NOCYCLE PRIOR e.id_empleado = e.id_jefe
 ORDER SIBLINGS BY e.nombre;

PROMPT
PROMPT --> 29 filas, 5 niveles de profundidad.
PROMPT --> NOCYCLE no es adorno: una FK autorreferente NO puede impedir un
PROMPT     ciclo de forma declarativa. El CHECK solo cubre "ser su propio
PROMPT     jefe". Un ciclo A->B->A solo se evita con trigger o desde la app.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  3 [NUCLEO]  POR QUE HACEN FALTA DOS JERARQUIAS Y NO UNA           #
PROMPT #  Reportes cuyo jefe NO esta en su unidad ni en la unidad madre.    #
PROMPT ######################################################################
PROMPT
-- Si la linea de reporte se pudiera deducir de la jerarquia de unidades,
-- esta consulta no devolveria nada y la columna id_jefe seria redundante.
-- Devuelve dos filas, y una de ellas es imposible de deducir.

COLUMN empleado    FORMAT A26
COLUMN su_unidad   FORMAT A22
COLUMN jefe        FORMAT A22
COLUMN unidad_jefe FORMAT A20
COLUMN clase       FORMAT A20

WITH ancestro (id_unidad, id_ancestro) AS (
  -- caso base: el padre directo de cada unidad
  SELECT id_unidad, id_unidad_padre
    FROM unidad_org
   WHERE id_unidad_padre IS NOT NULL
  UNION ALL
  -- paso recursivo: el padre del padre, y asi hacia arriba
  SELECT a.id_unidad, u.id_unidad_padre
    FROM ancestro a
    JOIN unidad_org u ON u.id_unidad = a.id_ancestro
   WHERE u.id_unidad_padre IS NOT NULL
)
SELECT e.nombre   AS empleado,
       ue.nombre  AS su_unidad,
       j.nombre   AS jefe,
       uj.nombre  AS unidad_jefe,
       CASE WHEN a.id_ancestro IS NOT NULL
            THEN 'salteado'
            ELSE 'MATRICIAL'
       END        AS clase
  FROM empleado e
  JOIN empleado    j  ON j.id_empleado = e.id_jefe
  JOIN unidad_org  ue ON ue.id_unidad  = e.id_unidad
  JOIN unidad_org  uj ON uj.id_unidad  = j.id_unidad
  LEFT JOIN ancestro a ON a.id_unidad    = e.id_unidad
                      AND a.id_ancestro  = j.id_unidad
 WHERE e.id_unidad <> j.id_unidad
   AND (ue.id_unidad_padre IS NULL OR ue.id_unidad_padre <> j.id_unidad)
 -- DESC a proposito: 'salteado' primero y 'MATRICIAL' despues, para que el
 -- orden en pantalla siga el orden en que se explica.
 ORDER BY clase DESC, e.nombre;

PROMPT
PROMPT --> "salteado": el jefe esta mas arriba en la MISMA rama. Todavia se
PROMPT     podria deducir de la jerarquia de unidades.
PROMPT --> "MATRICIAL": el jefe esta en una rama HERMANA. Esto ya no se
PROMPT     puede deducir de ninguna manera, y es la razon por la que
PROMPT     id_jefe tiene que existir como columna propia.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  4 [NUCLEO]  EL M:N: LA TABLA PUENTE EN ACCION                     #
PROMPT ######################################################################
PROMPT

COLUMN proyecto FORMAT A30
COLUMN estado   FORMAT A12
COLUMN personas FORMAT 999 HEADING 'PERS'
COLUMN equipo   FORMAT A78 WORD_WRAPPED

SELECT pr.nombre                                   AS proyecto,
       pr.estado,
       COUNT(*)                                    AS personas,
       LISTAGG(e.nombre || ' (' || a.rol || ')', ', ')
         WITHIN GROUP (ORDER BY a.pct_dedicacion DESC, e.nombre) AS equipo
  FROM asignacion a
  JOIN empleado   e  ON e.id_empleado = a.id_empleado
  JOIN proyecto   pr ON pr.id_proyecto = a.id_proyecto
 GROUP BY pr.nombre, pr.estado
 ORDER BY pr.nombre;

PROMPT
PROMPT ######################################################################
PROMPT #  5 [NUCLEO]  EL HALLAZGO: GENTE SOBREASIGNADA                      #
PROMPT ######################################################################
PROMPT
-- Cada fila de ASIGNACION es valida por separado (el CHECK verifica
-- 1..100). La suma NO la puede validar ninguna restriccion de tabla,
-- porque involucra varias filas. Este es el limite de las restricciones
-- declarativas, y por eso la consulta existe.

COLUMN persona     FORMAT A28
COLUMN proyectos   FORMAT 999 HEADING 'PROY'
COLUMN dedicacion  FORMAT 999 HEADING 'DED%'
COLUMN detalle     FORMAT A64 WORD_WRAPPED

SELECT e.nombre                                AS persona,
       COUNT(*)                                AS proyectos,
       SUM(a.pct_dedicacion)                   AS dedicacion,
       LISTAGG(pr.nombre || ' ' || a.pct_dedicacion || '%', ' + ')
         WITHIN GROUP (ORDER BY a.pct_dedicacion DESC) AS detalle
  FROM asignacion a
  JOIN empleado   e  ON e.id_empleado  = a.id_empleado
  JOIN proyecto   pr ON pr.id_proyecto = a.id_proyecto
 GROUP BY e.nombre
HAVING SUM(a.pct_dedicacion) > 100
 ORDER BY SUM(a.pct_dedicacion) DESC;

PROMPT
PROMPT --> 2 personas por encima del 100 %. Ninguna restriccion las detecta.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  6 [NUCLEO]  LA PRUEBA DEL DISENO FISICO                           #
PROMPT #  Donde quedo cada segmento.                                        #
PROMPT ######################################################################
PROMPT

COLUMN tablespace FORMAT A16 HEADING 'TABLESPACE'
COLUMN tipo       FORMAT A12 HEADING 'TIPO'
COLUMN objetos    FORMAT 999 HEADING 'OBJS'
COLUMN kb         FORMAT 99990 HEADING 'KB'
COLUMN extents    FORMAT 9990 HEADING 'EXTENTS'

SELECT tablespace_name      AS tablespace,
       segment_type         AS tipo,
       COUNT(*)             AS objetos,
       SUM(bytes) / 1024    AS kb,
       SUM(extents)         AS extents
  FROM user_segments
 GROUP BY tablespace_name, segment_type
 ORDER BY tablespace_name, segment_type;

PROMPT
PROMPT --> TABLE solo en TS_ORG_DATOS, INDEX solo en TS_ORG_INDICES.
PROMPT --> La columna EXTENTS es la jerarquia de la clase hecha visible:
PROMPT     segmento -> extents -> bloques.
PROMPT

PROMPT
PROMPT ######################################################################
PROMPT #  7 [EXTRA]  LA CADENA DE MANDO DE UNA PERSONA                      #
PROMPT ######################################################################
PROMPT

COLUMN cadena FORMAT A100 HEADING 'CADENA DE MANDO (de la raiz hacia abajo)'

SELECT LTRIM(SYS_CONNECT_BY_PATH(e.nombre, ' > '), ' > ') AS cadena
  FROM empleado e
 WHERE e.nombre = 'Marcela Zuniga Fallas'
 START WITH e.id_jefe IS NULL
 CONNECT BY NOCYCLE PRIOR e.id_empleado = e.id_jefe;

PROMPT
PROMPT ######################################################################
PROMPT #  8 [EXTRA]  TAMANO DEL EQUIPO DE CADA VICEPRESIDENCIA              #
PROMPT ######################################################################
PROMPT
-- CONNECT_BY_ROOT devuelve, para cada fila del recorrido, la fila donde
-- ese recorrido empezo. Sirve para agrupar un arbol por su raiz.

COLUMN vp FORMAT A26 HEADING 'ARRANCANDO EN'
COLUMN equipo_total FORMAT 999 HEADING 'PERSONAS DEBAJO'

SELECT raiz AS vp, COUNT(*) - 1 AS equipo_total
  FROM (
    SELECT CONNECT_BY_ROOT e.nombre AS raiz
      FROM empleado e
     START WITH e.id_jefe IN (SELECT id_empleado FROM empleado WHERE id_jefe IS NULL)
     CONNECT BY NOCYCLE PRIOR e.id_empleado = e.id_jefe
  )
 GROUP BY raiz
 ORDER BY 2 DESC;

PROMPT
PROMPT ######################################################################
PROMPT #  9 [EXTRA]  DISTRIBUCION DE LA PLANTILLA POR NIVEL                 #
PROMPT ######################################################################
PROMPT

COLUMN nivel FORMAT 9 HEADING 'NIV'
COLUMN personas FORMAT 999 HEADING 'PERS'
COLUMN barra FORMAT A32 HEADING 'DISTRIBUCION'

SELECT nivel,
       COUNT(*)                        AS personas,
       RPAD('#', COUNT(*), '#')        AS barra
  FROM (
    SELECT LEVEL AS nivel
      FROM empleado
     START WITH id_jefe IS NULL
     CONNECT BY NOCYCLE PRIOR id_empleado = id_jefe
  )
 GROUP BY nivel
 ORDER BY nivel;

PROMPT
PROMPT === Fin de las consultas. Siguiente:  @05_demo_indice_fk.sql
PROMPT
