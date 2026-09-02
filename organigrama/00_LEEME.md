# Demo: base de datos de un organigrama funcional

Caso: **Arkanova Software**, una software house de ~180 personas.
29 empleados de muestra, 15 unidades, 13 puestos, 6 proyectos, 34 asignaciones.

---

## Sí se puede correr. Elegí una de tres rutas

Ordenadas por lo que tardan en estar funcionando.

| Ruta | Tiempo | ¿Corre el demo completo? |
|---|---|---|
| **A — Contenedor Docker** | ~10 min | Sí, todo |
| **B — Instalar Oracle Free en Windows** | 1–2 h | Sí, todo |
| **C — Oracle LiveSQL en el navegador** | ~2 min | Solo el modelo (sin tablespaces) |

**Dato importante que cambió:** «Oracle XE / Express Edition» ya no existe. Hoy el producto
gratuito se llama **Oracle AI Database Free** y su PDB se llama **`FREEPDB1`**, no `XEPDB1`.
Los scripts ya vienen con `FREEPDB1`. Si tu instalación es una XE vieja, cambiá ese nombre.

---

## Ruta A — Contenedor Docker (la más rápida y limpia)

La mejor opción si tenés Docker Desktop, o si podés instalarlo. **No necesitás instalar
Oracle ni el cliente de Oracle en Windows**: el contenedor ya trae `sqlplus` adentro.

### 1. Levantar la base (un comando)

```powershell
docker run -d --name oradb -p 1521:1521 -e ORACLE_PASSWORD=Oracle2026 gvenzl/oracle-free:slim-faststart
```

La primera vez baja ~1 GB. Esperá a que diga que está lista:

```powershell
docker logs -f oradb
```

Cuando aparezca **`DATABASE IS READY TO USE!`**, `Ctrl+C` para salir del log.

### 2. Copiar los scripts adentro del contenedor

Desde la carpeta que contiene la carpeta `organigrama`:

```powershell
docker cp organigrama oradb:/tmp/
```

### 3. Correr el demo

```powershell
docker exec -it oradb bash -c "cd /tmp/organigrama && sqlplus system/Oracle2026@localhost/FREEPDB1"
```

Ya adentro de SQL\*Plus:

```
SQL> @01_crear_tablespaces.sql
SQL> exit
```

Y ahora como el dueño del esquema:

```powershell
docker exec -it oradb bash -c "cd /tmp/organigrama && sqlplus org_app/Demo#2026@localhost/FREEPDB1"
```

```
SQL> @02_crear_modelo.sql
SQL> @03_cargar_datos.sql
SQL> @04_demo_consultas.sql
SQL> @05_demo_indice_fk.sql
```

### Para apagar y volver a empezar

```powershell
docker stop oradb          # apagar, conservando los datos
docker start oradb         # volver a encender
docker rm -f oradb         # borrar todo y empezar de cero
```

> **Ventaja para la presentación:** el contenedor se levanta en un minuto y se puede
> destruir y recrear sin dejar nada instalado en la máquina. Si algo se rompe durante
> el ensayo, `docker rm -f oradb` y de nuevo.

---

## Ruta B — Instalar Oracle AI Database Free en Windows

La vía oficial. Descarga de ~2,5 GB e instalación de 20–40 minutos, más el cliente si
querés `sqlplus` fuera del servidor.

1. Descargar de <https://www.oracle.com/database/free/> → «Download for Windows».
2. Instalar. El instalador pide una contraseña para `SYS` y `SYSTEM`: **anotala**.
3. Verificar con los tres comandos de la sección siguiente.
4. Correr los scripts como se indica en *Orden de ejecución*.

Límites de la edición gratuita: 12 GB de datos de usuario, 2 GB de RAM y 2 hilos de CPU.
Para este demo sobran holgadamente.

### Verificar que quedó bien

```powershell
Get-Service *Oracle* | Format-Table Name, Status    # debe decir Running
lsnrctl status                                      # anotá el nombre del servicio
sqlplus -V                                          # ¿existe el cliente?
```

| Lo que ves | Qué significa |
|---|---|
| `lsnrctl` lista `freepdb1` | Todo listo, los scripts funcionan sin editar nada. |
| `lsnrctl` lista `xepdb1` | Es una XE antigua: cambiá `FREEPDB1` por `XEPDB1` en las conexiones. |
| El servicio existe pero **Stopped** | `net start OracleServiceFREE` como administrador. |
| `lsnrctl` no responde | `lsnrctl start`. |
| `sqlplus` no se reconoce | Falta el PATH, o no hay nada instalado. |
| No aparece ningún servicio Oracle | No hay nada instalado. Ruta A o C. |

---

## Ruta C — Oracle LiveSQL, en el navegador, sin instalar nada

Para esto existe **`10_livesql_todo_en_uno.sql`**: un solo archivo con el modelo, los datos
y todas las consultas jerárquicas.

1. Abrir <https://livesql.oracle.com> — **no requiere registro**.
2. Pegar el contenido completo de `10_livesql_todo_en_uno.sql`.
3. Ejecutar.

El esquema que creás ahí sobrevive unos 90 días, así que se puede preparar hoy y presentar
mañana con todo cargado.

### Qué sí y qué no

**Sí funciona:** el modelo completo, las dos jerarquías autorreferentes, la tabla puente
M:N, el caso matricial, la sobreasignación, `CONNECT BY`, `SYS_CONNECT_BY_PATH`, `LISTAGG`
y la verificación de que los índices existen. Es decir: **toda la mitad de modelo relacional
del trabajo.**

**No funciona:** la mitad de **diseño físico**. Ni LiveSQL ni Oracle Autonomous Database
permiten `CREATE TABLESPACE` — Autonomous administra el almacenamiento por su cuenta y
devuelve `ORA-01031: insufficient privileges` si se intenta. Por eso también quedan fuera
`USING INDEX TABLESPACE`, la verificación contra `USER_SEGMENTS` y la prueba de
`EXPLAIN PLAN` del script 05. **Tampoco corre el `06`**: LiveSQL no da acceso a ninguna
vista `V$`, así que la bitácora, los archivos de control y los parámetros no son
observables desde ahí. Ese anexo necesita sí o sí la ruta A o la B.

> Si presentás por esta ruta, decilo de frente: «el modelo corre en vivo; la separación de
> tablespaces la mostramos en el script y en el informe, porque este entorno no permite
> crear tablespaces». Eso es preciso y se defiende mejor que disimularlo.

---

## Orden de ejecución (rutas A y B)

Dos usuarios distintos, y eso no es un detalle: el diseño físico lo hace el DBA, el esquema
lo crea el dueño de los datos.

| # | Script | Usuario | Qué hace |
|---|---|---|---|
| 1 | `01_crear_tablespaces.sql` | `system` | Tablespaces de datos e índices, usuario `org_app`, cuotas |
| 2 | `02_crear_modelo.sql` | `org_app` | Las 5 tablas, restricciones e índices de las FK |
| 3 | `03_cargar_datos.sql` | `org_app` | Los datos del organigrama |
| 4 | `04_demo_consultas.sql` | `org_app` | Las 9 consultas del demo |
| 5 | `05_demo_indice_fk.sql` | `org_app` | La prueba del índice sobre la FK |
| 6 | `06_bitacora_control_parametros.sql` | `system` | Bitácora, archivos de control, parámetros, SGA y procesos |
| — | `99_limpiar.sql` | `system` | Deja la base como estaba (para ensayar de nuevo) |

El `06` es de **solo lectura** y se puede correr en cualquier momento, incluso antes del `02`
(su último paso saldría vacío, nada más). Va como `system` porque `org_app` no ve las vistas
`V$` —tiene privilegios mínimos, y así debe ser.

### Con Oracle instalado en Windows (ruta B)

```
REM  --- paso 1, como SYSTEM, conectado a la PDB ---
sqlplus system/TU_CLAVE@localhost:1521/FREEPDB1
SQL> @01_crear_tablespaces.sql
SQL> exit

REM  --- pasos 2 a 5, como el dueño del esquema ---
sqlplus org_app/"Demo#2026"@localhost:1521/FREEPDB1
SQL> @02_crear_modelo.sql
SQL> @03_cargar_datos.sql
SQL> @04_demo_consultas.sql
SQL> @05_demo_indice_fk.sql
SQL> exit

REM  --- paso 6, otra vez como SYSTEM (vistas V$) ---
sqlplus system/TU_CLAVE@localhost:1521/FREEPDB1
SQL> @06_bitacora_control_parametros.sql
```

Si no querés escribir la clave en la línea de comandos:

```
sqlplus /nolog
SQL> CONNECT org_app@localhost:1521/FREEPDB1
Enter password:
```

**Hacé `cd` a la carpeta de los scripts antes de abrir sqlplus**, o usá la ruta completa
en el `@`.

---

## Cuatro cosas que hay que saber

1. **Conectate a la PDB, no a `CDB$ROOT`.** El script 01 lo verifica y se detiene si te
   equivocaste. Es el error más común del multitenant, y desde 21c no hay forma de
   evitarlo: toda base Oracle es un contenedor.

2. **El script 05 se corre completo, de un tirón, sin reconectar.** La `PLAN_TABLE` es una
   tabla temporal de sesión: si te reconectás en medio, la comparación de planes sale
   vacía.

3. **`99_limpiar.sql` cierra las sesiones de `org_app`** antes de borrar el usuario. Si
   tenés otra ventana abierta con `org_app`, se va a caer — es lo esperado.

4. **Todo es idempotente.** La secuencia completa se puede correr dos veces seguidas sin
   errores. Ensayá al menos una vez de principio a fin.

---

## Los archivos

| Archivo | Para qué |
|---|---|
| `00_LEEME.md` | Este archivo |
| `01` a `05`, `99` | El demo completo, para una instancia propia (rutas A y B) |
| `06_bitacora_control_parametros.sql` | Anexo de arquitectura física: redo log, control files, parámetros, SGA, procesos |
| `10_livesql_todo_en_uno.sql` | El demo en una sola pieza, sin tablespaces (ruta C) |
| `informe_organigrama.docx` | El informe escrito, 8 páginas. **Falta poner los nombres del grupo.** |
| `salida_esperada.txt` | La salida exacta del organigrama, para verificar o para el plan B |

---

## Credenciales

| | |
|---|---|
| Usuario del esquema | `org_app` |
| Clave | `Demo#2026` |
| Clave de SYSTEM (ruta A, contenedor) | `Oracle2026` |
| Tablespace de datos | `ts_org_datos` |
| Tablespace de índices | `ts_org_indices` |

La clave está en texto plano en `01_crear_tablespaces.sql`. Está bien para un demo de clase;
en cualquier otro contexto no lo estaría, y conviene decirlo si lo preguntan.

---

## Si nada funciona a tiempo

`salida_esperada.txt` tiene la salida exacta del organigrama. Se puede presentar el diseño
leyendo los scripts en el editor, con ese archivo al lado para mostrar qué devuelve cada
consulta. El contenido defendible del trabajo —el modelo, las dos jerarquías, la separación
de tablespaces, los índices de las FK— es exactamente el mismo. Y decir en una frase que la
ejecución quedó pendiente por el entorno, sin adornarlo, es mejor que pelear con una
instalación frente al aula.
