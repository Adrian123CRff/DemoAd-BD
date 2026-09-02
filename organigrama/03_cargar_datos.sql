-- =====================================================================
--  03_cargar_datos.sql
--  Datos del organigrama de Arkanova Software (software house, 28 personas)
--  Ejecutar CONECTADO COMO org_app, despues de 02_crear_modelo.sql
--
--  Generado y verificado: sin ciclos, sin huerfanos, PK sin duplicados.
-- =====================================================================
SET DEFINE OFF
SET FEEDBACK OFF

-- Vaciar en orden inverso a las dependencias (hijo antes que padre)
DELETE FROM asignacion;
DELETE FROM proyecto;
DELETE FROM empleado;
DELETE FROM puesto;
DELETE FROM unidad_org;
COMMIT;

PROMPT
PROMPT === 1/5  UNIDADES ORGANIZACIONALES =====================================
-- Se insertan por nivel: un padre nunca puede insertarse despues de su hijo,
-- porque la FK autorreferente se valida fila por fila.

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

PROMPT === 2/5  PUESTOS ==================================================
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

PROMPT === 3/5  EMPLEADOS ================================================
-- Mismo criterio: por nivel de reporte, para que el jefe ya exista.
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

PROMPT === 4/5  PROYECTOS ==============================================
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (1, 'Migracion a Oracle 21c', 5, 'EN_CURSO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (2, 'Portal de Clientes v3', 6, 'EN_CURSO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (3, 'App Movil de Cobros', 11, 'EN_CURSO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (4, 'Data Warehouse Corporativo', 8, 'EN_CURSO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (5, 'Automatizacion de Pruebas', 7, 'PLANIFICADO');
INSERT INTO proyecto (id_proyecto, nombre, id_unidad, estado) VALUES (6, 'Rediseno de Identidad Visual', 12, 'CERRADO');

PROMPT === 5/5  ASIGNACIONES (la tabla puente, M:N) =====================
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
SET FEEDBACK ON

PROMPT
PROMPT === CONTEO FINAL ====================================================
SELECT 'unidad_org' AS tabla, COUNT(*) AS filas FROM unidad_org
UNION ALL SELECT 'puesto',      COUNT(*) FROM puesto
UNION ALL SELECT 'empleado',    COUNT(*) FROM empleado
UNION ALL SELECT 'proyecto',    COUNT(*) FROM proyecto
UNION ALL SELECT 'asignacion',  COUNT(*) FROM asignacion;

PROMPT Esperado: 15 / 13 / 29 / 6 / 34
PROMPT
