-- =====================================================================
--  DEMO DEL ORGANIGRAMA FUNCIONAL - VERSION DE UNA SOLA PIEZA
--  Arkanova Software: 15 unidades, 13 puestos, 29 empleados,
--                     6 proyectos, 34 asignaciones.
--
--  PARA QUE SIRVE ESTE ARCHIVO
--  Correr el demo SIN INSTALAR NADA. Pegar el contenido completo en:
--     * Oracle LiveSQL  ->  https://livesql.oracle.com   (sin registro)
--     * o cualquier Autonomous Database / Oracle Cloud Free
--
--  QUE FUNCIONA AQUI
--  El modelo completo, los datos, y todas las consultas jerarquicas: las
--  dos autorreferencias, la tabla puente M:N, el caso matricial y la
--  sobreasignacion. Es decir, TODA la parte de modelo relacional.
--
--  QUE NO FUNCIONA AQUI, Y POR QUE
--  El diseno fisico. Ni LiveSQL ni Autonomous Database permiten
--  CREATE TABLESPACE: Autonomous administra el almacenamiento por su
--  cuenta y devuelve ORA-01031 si se intenta. Por eso este archivo no
--  tiene ninguna clausula TABLESPACE ni USING INDEX TABLESPACE, y tampoco
--  la verificacion contra USER_SEGMENTS ni la prueba de EXPLAIN PLAN.
--  Para esa mitad del demo hace falta una instancia propia: ver 00_LEEME.md.
--
--  Es idempotente: se puede correr varias veces.
-- =====================================================================


-- =====================================================================
--  PARTE 1 - LIMPIAR LO ANTERIOR
--  Oracle no tiene CREATE OR REPLACE TABLE: el patron es intentar el DROP
--  y tragarse el ORA-00942 (la tabla no existe).
-- =====================================================================

DECLARE
  TYPE t_lista IS TABLE OF VARCHAR2(30);
  v_tablas t_lista := t_lista('asignacion', 'proyecto', 'empleado',
                              'puesto', 'unidad_org');
BEGIN
  FOR i IN 1 .. v_tablas.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE ' || v_tablas(i)
                     || ' CASCADE CONSTRAINTS PURGE';
    EXCEPTION
      WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
    END;
  END LOOP;
END;
/


-- =====================================================================
--  PARTE 2 - EL MODELO
--  Los tres patrones del modelo relacional, uno por tabla.
-- =====================================================================

-- PATRON 1 de 3: AUTORREFERENCIA. La jerarquia de unidades.
CREATE TABLE unidad_org (
  id_unidad        NUMBER(6)     NOT NULL,
  nombre           VARCHAR2(80)  NOT NULL,
  tipo             VARCHAR2(20)  NOT NULL,
  id_unidad_padre  NUMBER(6),
  CONSTRAINT pk_unidad PRIMARY KEY (id_unidad),
  CONSTRAINT uk_unidad_nombre UNIQUE (nombre),
  CONSTRAINT fk_unidad_padre FOREIGN KEY (id_unidad_padre)
    REFERENCES unidad_org (id_unidad),
  CONSTRAINT ck_unidad_no_self CHECK (id_unidad <> id_unidad_padre),
  CONSTRAINT ck_unidad_tipo CHECK
    (tipo IN ('DIRECCION', 'VICEPRESIDENCIA', 'AREA', 'SQUAD'))
);

-- PATRON 2 de 3: CADENA 1:N pura. Un catalogo.
CREATE TABLE puesto (
  id_puesto         NUMBER(6)     NOT NULL,
  nombre            VARCHAR2(80)  NOT NULL,
  nivel_jerarquico  NUMBER(2)     NOT NULL,
  familia           VARCHAR2(30)  NOT NULL,
  CONSTRAINT pk_puesto PRIMARY KEY (id_puesto),
  CONSTRAINT uk_puesto_nombre UNIQUE (nombre),
  CONSTRAINT ck_puesto_nivel CHECK (nivel_jerarquico BETWEEN 1 AND 10)
);

-- La SEGUNDA autorreferencia, y la decision de diseno del trabajo:
-- la linea de reporte (id_jefe) es INDEPENDIENTE de la jerarquia de
-- unidades (id_unidad). Suelen coincidir, pero no siempre, y esa
-- diferencia es lo que hace "funcional" al organigrama.
CREATE TABLE empleado (
  id_empleado    NUMBER(8)      NOT NULL,
  nombre         VARCHAR2(120)  NOT NULL,
  email          VARCHAR2(120)  NOT NULL,
  fecha_ingreso  DATE           NOT NULL,
  id_unidad      NUMBER(6)      NOT NULL,
  id_puesto      NUMBER(6)      NOT NULL,
  id_jefe        NUMBER(8),
  CONSTRAINT pk_empleado PRIMARY KEY (id_empleado),
  CONSTRAINT uk_empleado_email UNIQUE (email),
  CONSTRAINT fk_emp_unidad FOREIGN KEY (id_unidad) REFERENCES unidad_org (id_unidad),
  CONSTRAINT fk_emp_puesto FOREIGN KEY (id_puesto) REFERENCES puesto (id_puesto),
  CONSTRAINT fk_emp_jefe   FOREIGN KEY (id_jefe)   REFERENCES empleado (id_empleado),
  CONSTRAINT ck_emp_no_self CHECK (id_empleado <> id_jefe)
);

CREATE TABLE proyecto (
  id_proyecto  NUMBER(8)      NOT NULL,
  nombre       VARCHAR2(120)  NOT NULL,
  id_unidad    NUMBER(6)      NOT NULL,
  estado       VARCHAR2(20)   NOT NULL,
  CONSTRAINT pk_proyecto PRIMARY KEY (id_proyecto),
  CONSTRAINT fk_proy_unidad FOREIGN KEY (id_unidad) REFERENCES unidad_org (id_unidad),
  CONSTRAINT ck_proy_estado CHECK (estado IN ('PLANIFICADO','EN_CURSO','CERRADO'))
);

-- PATRON 3 de 3: TABLA PUENTE. Resuelve el M:N empleado <-> proyecto.
-- El rol y el porcentaje son atributos DEL VINCULO: no pertenecen ni a la
-- persona ni al proyecto. Por eso es una entidad y no un truco.
CREATE TABLE asignacion (
  id_empleado     NUMBER(8)     NOT NULL,
  id_proyecto     NUMBER(8)     NOT NULL,
  rol             VARCHAR2(40)  NOT NULL,
  pct_dedicacion  NUMBER(3)     NOT NULL,
  CONSTRAINT pk_asignacion PRIMARY KEY (id_empleado, id_proyecto),
  CONSTRAINT fk_asig_emp  FOREIGN KEY (id_empleado) REFERENCES empleado (id_empleado),
  CONSTRAINT fk_asig_proy FOREIGN KEY (id_proyecto) REFERENCES proyecto (id_proyecto),
  CONSTRAINT ck_asig_pct  CHECK (pct_dedicacion BETWEEN 1 AND 100)
);


-- =====================================================================
--  PARTE 3 - INDICES SOBRE LAS FOREIGN KEY
--  Oracle indexa las PRIMARY KEY y las UNIQUE por su cuenta, pero NUNCA
--  las FOREIGN KEY. Sin el indice de id_jefe, cada nivel del recorrido
--  jerarquico hace un full scan; y modificar la PK del padre con la FK del
--  hijo sin indexar toma un bloqueo de TABLA sobre el hijo, no de fila.
--  (Aqui van sin clausula TABLESPACE: el almacenamiento lo decide el
--   servicio, no nosotros.)
-- =====================================================================

CREATE INDEX ix_unidad_padre ON unidad_org (id_unidad_padre);
CREATE INDEX ix_emp_jefe     ON empleado   (id_jefe);
CREATE INDEX ix_emp_unidad   ON empleado   (id_unidad);
CREATE INDEX ix_emp_puesto   ON empleado   (id_puesto);
CREATE INDEX ix_proy_unidad  ON proyecto   (id_unidad);
CREATE INDEX ix_asig_proy    ON asignacion (id_proyecto);



-- =====================================================================
--  PARTE 4 - LOS DATOS
--  Se insertan por nivel del arbol: la FK autorreferente se valida
--  sentencia por sentencia, asi que el jefe debe existir antes que el
--  subordinado.
-- =====================================================================


-- --- Unidades organizacionales ---
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (1, 'Direccion General', 'DIRECCION', NULL);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (2, 'VP de Ingenieria', 'VICEPRESIDENCIA', 1);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (3, 'VP de Producto', 'VICEPRESIDENCIA', 1);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (4, 'VP de Operaciones', 'VICEPRESIDENCIA', 1);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (5, 'Area Plataforma', 'AREA', 2);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (6, 'Area Aplicaciones', 'AREA', 2);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (7, 'Area Calidad', 'AREA', 2);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (12, 'Area Diseno', 'AREA', 3);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (13, 'Area Gestion de Producto', 'AREA', 3);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (14, 'Area Soporte', 'AREA', 4);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (15, 'Area Administracion', 'AREA', 4);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (8, 'Squad Datos', 'SQUAD', 5);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (9, 'Squad Infraestructura', 'SQUAD', 5);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (10, 'Squad Web', 'SQUAD', 6);
INSERT INTO unidad_org (id_unidad, nombre, tipo, id_unidad_padre) VALUES (11, 'Squad Movil', 'SQUAD', 6);

-- --- Puestos ---
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (1, 'CEO', 1, 'DIRECCION');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (2, 'VP de Ingenieria', 2, 'INGENIERIA');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (3, 'VP de Producto', 2, 'PRODUCTO');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (4, 'VP de Operaciones', 2, 'OPERACIONES');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (5, 'Gerente de Area', 3, 'INGENIERIA');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (6, 'Lider Tecnico', 4, 'INGENIERIA');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (7, 'Ingeniero Senior', 5, 'INGENIERIA');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (8, 'Ingeniero', 6, 'INGENIERIA');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (9, 'Ingeniero de QA', 6, 'INGENIERIA');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (10, 'Disenador UX', 5, 'PRODUCTO');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (11, 'Product Owner', 4, 'PRODUCTO');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (12, 'Analista de Soporte', 6, 'OPERACIONES');
INSERT INTO puesto (id_puesto, nombre, nivel_jerarquico, familia) VALUES (13, 'Analista Administrativo', 6, 'OPERACIONES');

-- --- Empleados ---
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (1, 'Elena Vargas Rojas', 'elena.vargas@arkanova.com', DATE '2014-02-03', 1, 1, NULL);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (2, 'Marco Solis Pena', 'marco.solis@arkanova.com', DATE '2015-06-15', 2, 2, 1);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (3, 'Karla Jimenez Mora', 'karla.jimenez@arkanova.com', DATE '2016-01-11', 3, 3, 1);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (4, 'Andres Castro Lobo', 'andres.castro@arkanova.com', DATE '2015-09-01', 4, 4, 1);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (5, 'Diego Ramirez Soto', 'diego.ramirez@arkanova.com', DATE '2017-03-20', 5, 5, 2);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (6, 'Lucia Herrera Vega', 'lucia.herrera@arkanova.com', DATE '2017-08-07', 6, 5, 2);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (7, 'Pablo Nunez Arias', 'pablo.nunez@arkanova.com', DATE '2018-02-12', 7, 5, 2);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (24, 'Ignacio Fallas Sandi', 'ignacio.fallas@arkanova.com', DATE '2019-05-27', 12, 10, 3);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (25, 'Rebeca Morales Cubero', 'rebeca.morales@arkanova.com', DATE '2018-11-12', 13, 11, 3);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (26, 'Silvia Araya Gomez', 'silvia.araya@arkanova.com', DATE '2020-08-03', 14, 12, 4);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (27, 'Mauricio Vega Chinchilla', 'mauricio.vega@arkanova.com', DATE '2019-10-14', 15, 13, 4);
-- Reporte SALTEADO: esta en la unidad 8 (Squad Datos) pero
-- reporta a la VP de Ingenieria (2), que es una unidad ancestro.
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (28, 'Alonso Picado Solis', 'alonso.picado@arkanova.com', DATE '2016-04-19', 8, 7, 2);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (8, 'Sofia Quesada Ruiz', 'sofia.quesada@arkanova.com', DATE '2018-05-14', 8, 6, 5);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (9, 'Tomas Alvarado Cruz', 'tomas.alvarado@arkanova.com', DATE '2018-07-02', 9, 6, 5);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (10, 'Valeria Mena Solano', 'valeria.mena@arkanova.com', DATE '2019-01-21', 10, 6, 6);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (11, 'Rodrigo Salas Fonseca', 'rodrigo.salas@arkanova.com', DATE '2019-04-08', 11, 6, 6);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (22, 'Oscar Madrigal Rivera', 'oscar.madrigal@arkanova.com', DATE '2021-01-18', 7, 9, 7);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (23, 'Daniela Espinoza Barrantes', 'daniela.espinoza@arkanova.com', DATE '2022-09-05', 7, 9, 7);
-- Reporte MATRICIAL: QA embebido en el Squad Datos (8) que reporta
-- al Area Calidad (7), una rama HERMANA. Este caso es imposible de
-- deducir de la jerarquia de unidades: por eso id_jefe debe existir.
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (29, 'Marcela Zuniga Fallas', 'marcela.zuniga@arkanova.com', DATE '2021-06-07', 8, 9, 7);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (12, 'Natalia Brenes Campos', 'natalia.brenes@arkanova.com', DATE '2019-09-16', 8, 7, 8);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (13, 'Javier Urena Delgado', 'javier.urena@arkanova.com', DATE '2021-03-01', 8, 8, 8);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (14, 'Camila Rojas Aguilar', 'camila.rojas@arkanova.com', DATE '2022-07-18', 8, 8, 8);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (15, 'Fabian Chaves Montero', 'fabian.chaves@arkanova.com', DATE '2020-02-10', 9, 7, 9);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (16, 'Gabriela Perez Umana', 'gabriela.perez@arkanova.com', DATE '2022-01-24', 9, 8, 9);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (17, 'Esteban Villalobos Saenz', 'esteban.villalobos@arkanova.com', DATE '2020-06-15', 10, 7, 10);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (18, 'Mariana Cordero Blanco', 'mariana.cordero@arkanova.com', DATE '2021-11-08', 10, 8, 10);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (19, 'Adrian Segura Navarro', 'adrian.segura@arkanova.com', DATE '2023-02-06', 10, 8, 10);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (20, 'Ricardo Bonilla Zamora', 'ricardo.bonilla@arkanova.com', DATE '2020-10-05', 11, 7, 11);
INSERT INTO empleado (id_empleado, nombre, email, fecha_ingreso, id_unidad, id_puesto, id_jefe) VALUES (21, 'Paula Guzman Leiva', 'paula.guzman@arkanova.com', DATE '2022-04-11', 11, 8, 11);

-- --- Proyectos ---
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (1, 'Migracion a Oracle 21c', 5, 'EN_CURSO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (2, 'Portal de Clientes v3', 6, 'EN_CURSO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (3, 'App Movil de Cobros', 11, 'EN_CURSO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (4, 'Data Warehouse Corporativo', 8, 'EN_CURSO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (5, 'Automatizacion de Pruebas', 7, 'PLANIFICADO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (6, 'Rediseno de Identidad Visual', 12, 'CERRADO');

-- --- Asignaciones (la tabla puente) ---
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (2, 1, 'Patrocinador', 10);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (5, 1, 'Patrocinador', 20);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (9, 1, 'Lider tecnico', 60);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (12, 1, 'Asesor tecnico', 10);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (15, 1, 'Ingeniero', 80);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (16, 1, 'Ingeniero', 100);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (28, 1, 'Arquitecto', 40);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (6, 2, 'Patrocinador', 20);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (10, 2, 'Lider tecnico', 50);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (17, 2, 'Ingeniero', 70);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (18, 2, 'Ingeniero', 100);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (19, 2, 'Ingeniero', 100);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (24, 2, 'Disenador UX', 40);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (25, 2, 'Product Owner', 50);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (11, 3, 'Lider tecnico', 70);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (17, 3, 'Asesor tecnico', 50);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (20, 3, 'Ingeniero', 90);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (21, 3, 'Ingeniero', 100);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (24, 3, 'Disenador UX', 30);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (25, 3, 'Product Owner', 50);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (5, 4, 'Patrocinador', 20);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (8, 4, 'Lider tecnico', 70);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (12, 4, 'Ingeniero Senior', 90);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (13, 4, 'Ingeniero', 100);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (14, 4, 'Ingeniero', 80);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (28, 4, 'Arquitecto', 60);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (29, 4, 'Ingeniero de QA', 60);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (7, 5, 'Patrocinador', 30);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (10, 5, 'Asesor tecnico', 20);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (22, 5, 'Ingeniero de QA', 80);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (23, 5, 'Ingeniero de QA', 100);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (29, 5, 'Ingeniero de QA', 50);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (3, 6, 'Patrocinador', 15);
INSERT INTO asignacion (id_empleado, id_proyecto, rol, pct_dedicacion) VALUES (24, 6, 'Disenador UX', 30);

COMMIT;


-- =====================================================================
--  PARTE 5 - CONSULTA 1: LA JERARQUIA DE UNIDADES
-- =====================================================================

SELECT LEVEL AS nivel,
       LPAD(' ', (LEVEL - 1) * 3) || nombre AS estructura,
       tipo
  FROM unidad_org
 START WITH id_unidad_padre IS NULL
 CONNECT BY NOCYCLE PRIOR id_unidad = id_unidad_padre
 ORDER SIBLINGS BY nombre;


-- =====================================================================
--  PARTE 6 - CONSULTA 2: EL ORGANIGRAMA DE PERSONAS
--  29 filas, 5 niveles de profundidad.
--  NOCYCLE no es adorno: una FK autorreferente NO puede impedir un ciclo
--  de forma declarativa. El CHECK solo cubre "ser su propio jefe"; un
--  ciclo A->B->A requiere un trigger o validacion en la aplicacion.
-- =====================================================================

SELECT LEVEL AS nivel,
       LPAD(' ', (LEVEL - 1) * 3) || e.nombre AS organigrama,
       p.nombre AS puesto,
       u.nombre AS unidad,
       CASE CONNECT_BY_ISLEAF WHEN 1 THEN 'si' END AS hoja
  FROM empleado e
  JOIN puesto     p ON p.id_puesto = e.id_puesto
  JOIN unidad_org u ON u.id_unidad = e.id_unidad
 START WITH e.id_jefe IS NULL
 CONNECT BY NOCYCLE PRIOR e.id_empleado = e.id_jefe
 ORDER SIBLINGS BY e.nombre;


-- =====================================================================
--  PARTE 7 - CONSULTA 3: POR QUE HACEN FALTA DOS JERARQUIAS Y NO UNA
--
--  Esta es la consulta que sostiene todo el diseno. Si la linea de reporte
--  se pudiera deducir de la jerarquia de unidades, no devolveria nada y la
--  columna id_jefe seria redundante. Devuelve DOS filas:
--
--    "salteado"  -> el jefe esta mas arriba en la MISMA rama.
--                   Todavia seria deducible recorriendo el arbol.
--    "MATRICIAL" -> el jefe esta en una rama HERMANA.
--                   Esto NO se puede deducir por ningun camino.
-- =====================================================================

WITH ancestro (id_unidad, id_ancestro) AS (
  SELECT id_unidad, id_unidad_padre
    FROM unidad_org
   WHERE id_unidad_padre IS NOT NULL
  UNION ALL
  SELECT a.id_unidad, u.id_unidad_padre
    FROM ancestro a
    JOIN unidad_org u ON u.id_unidad = a.id_ancestro
   WHERE u.id_unidad_padre IS NOT NULL
)
SELECT e.nombre  AS empleado,
       ue.nombre AS su_unidad,
       j.nombre  AS jefe,
       uj.nombre AS unidad_jefe,
       CASE WHEN a.id_ancestro IS NOT NULL THEN 'salteado' ELSE 'MATRICIAL' END AS clase
  FROM empleado e
  JOIN empleado    j  ON j.id_empleado = e.id_jefe
  JOIN unidad_org  ue ON ue.id_unidad  = e.id_unidad
  JOIN unidad_org  uj ON uj.id_unidad  = j.id_unidad
  LEFT JOIN ancestro a ON a.id_unidad   = e.id_unidad
                      AND a.id_ancestro = j.id_unidad
 WHERE e.id_unidad <> j.id_unidad
   AND (ue.id_unidad_padre IS NULL OR ue.id_unidad_padre <> j.id_unidad)
 ORDER BY clase DESC, e.nombre;


-- =====================================================================
--  PARTE 8 - CONSULTA 4: EL M:N, LA TABLA PUENTE EN ACCION
-- =====================================================================

SELECT pr.nombre AS proyecto,
       pr.estado,
       COUNT(*)  AS personas,
       LISTAGG(e.nombre || ' (' || a.rol || ')', ', ')
         WITHIN GROUP (ORDER BY a.pct_dedicacion DESC, e.nombre) AS equipo
  FROM asignacion a
  JOIN empleado   e  ON e.id_empleado  = a.id_empleado
  JOIN proyecto   pr ON pr.id_proyecto = a.id_proyecto
 GROUP BY pr.nombre, pr.estado
 ORDER BY pr.nombre;


-- =====================================================================
--  PARTE 9 - CONSULTA 5: EL HALLAZGO - GENTE SOBREASIGNADA
--
--  Cada fila de ASIGNACION es valida por separado: el CHECK verifica que
--  el porcentaje este entre 1 y 100. La SUMA no la puede validar ninguna
--  restriccion de tabla, porque involucra varias filas. Aqui termina lo
--  que las restricciones declarativas pueden garantizar.
--  Devuelve 2 personas: una al 120 % y otra al 110 %.
-- =====================================================================

SELECT e.nombre               AS persona,
       COUNT(*)               AS proyectos,
       SUM(a.pct_dedicacion)  AS dedicacion_pct,
       LISTAGG(pr.nombre || ' ' || a.pct_dedicacion || '%', ' + ')
         WITHIN GROUP (ORDER BY a.pct_dedicacion DESC) AS detalle
  FROM asignacion a
  JOIN empleado   e  ON e.id_empleado  = a.id_empleado
  JOIN proyecto   pr ON pr.id_proyecto = a.id_proyecto
 GROUP BY e.nombre
HAVING SUM(a.pct_dedicacion) > 100
 ORDER BY SUM(a.pct_dedicacion) DESC;


-- =====================================================================
--  PARTE 10 - CONSULTA 6: LA CADENA DE MANDO DE UNA PERSONA
--  Justo la del caso matricial.
-- =====================================================================

SELECT LTRIM(SYS_CONNECT_BY_PATH(e.nombre, ' > '), ' > ') AS cadena_de_mando
  FROM empleado e
 WHERE e.nombre = 'Marcela Zuniga Fallas'
 START WITH e.id_jefe IS NULL
 CONNECT BY NOCYCLE PRIOR e.id_empleado = e.id_jefe;


-- =====================================================================
--  PARTE 11 - VERIFICACION: LOS INDICES EXISTEN
--  Lo que NO se puede verificar aqui es en que tablespace quedo cada uno,
--  porque el servicio administra el almacenamiento. Esa comprobacion
--  (contra USER_SEGMENTS) solo corre en una instancia propia.
-- =====================================================================

SELECT index_name, table_name, uniqueness
  FROM user_indexes
 WHERE table_name IN ('UNIDAD_ORG','PUESTO','EMPLEADO','PROYECTO','ASIGNACION')
 ORDER BY table_name, index_name;
