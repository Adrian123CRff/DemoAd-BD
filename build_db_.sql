

Creacion y mantenimiento de bases de datos. Una base de datos es un conjunto de estructuras de datos.
Conceptos tecnicos apartir de ahora.
Arquitectura fisica de la base de datos (P,M, A) 
Ahora lo que se debe trabajar ahora es una mezcla entre la arquitectura fisica y la logica(es la distribucion apropiada para las bases de datos de las empresas).
La base de datos oracle, se puede ver como una meta data inicial, en la que tenemos una base de datos y varios tablesspace,que se esta constituicdo en segmentos <--- bloques.

Cuando se inicializa el starup toda los archivos de datos, en el los de arquivos de usuarios, y agregamos la informacion al S.G.A 
Los encargados de leer estos procesos son los DBWRITER COGWRITER.


BaseDatos->
    |
    | 
Tablespace<----- Datapiles
    ^    
    |
    | 
Segmentos <---- blques 

Semillas de produccion para las versiones 21 en adelante.
{
Sintaxis creacion 
Create DataBase ABC_BD 
Tablespace/Datafile "ABCD_DB_K001.	
"MAXSIZE = 60G, initial, next 10 ---> son las maneras mas clasicas para crear tablespace en bases de datos. 
additional tablespace ABCD_BD_F002DA
ADCTOOL TABLE------TEMP
}
la manera de manejar las bases es distribuir 
"No podemos dejar que una base de datos se expanda sola, necesitamos definir espacios con memorias, para realizar una memoria continua, ejemplo vector, de estructura tipo logica continua.
Struct Oracle-Nodo
{ tipo de informacion tablespace 
tipo de informacion Datos 
Oracle_nodes * s

princio: no mezcle datos.
}

organizacion: Se encuentra divida en diferentes tables spaces. saber interpretar para que sirven estas. Cuando disenamos una base de datos lo hacemos con tamanos, En system no puede existir ninguna tabla de usuario, solo puede existir tablas, y las tablas de transaccion de bases de datos.
{

users-> Todas las tablas estan en c y hay un riego de que la base de datos caiga.
 sysAUX
system-> se guardan todas las tablas que tiene que ver con oracle(todas las tablas que tienen el diccionario y las transacciones de manejos de datos).
Temp
}

El tamano de los data file que es system 


Ejemplo de base datos:
			ABC
		   _ _ _ |_ _ _ __________
		   |     |      |        |
 		   A1    A2     A3       AN
		   |     |      |        |
                   ->S1  ->S2   ->S2     ->S1
		   ->S2  ->S4   ->S3     ->S3
		   ->S3  ->S5            ->24

No pueden esta

vamos a suponer que las bases de datos van a tener un nucleo 
SGA -> 
PWA -> visualizar lo que esta sucediendo.



Explicacion de tables space en sql server, primary:
Su ponemos que tenemos un modelos de datos  
T1<-T2->(pkt2(pkt1,pkt2) fk2, )T3<-T4<-T5->T6<-T7)->T8<-T9
Un modelo relacional que esta aca, tiene varias tablas, indices primarios, indices foraneos,

T1 DD( 
Oracle_table T
(
a,t,
b,t,
c,t,
constraint pk(t1)
primary key 
) User 



"En modelo relacional solo existen relaciones de n a n pero solamente pueden ocurrir de 1 a n, es un requisito del modelo relacional.

select .....
from t1,t2,t3 (sigma,pi)

El arbol de resolucion
Funscan 
Funcionamiento de sql transaccionales(hay que estudiar esto bien antes de salir de la carrera como tal)



Deberia tener separado los tablespace separados y lo indices Tambien,
Las bases de datos se crean con distribucion. separa los datos de los indices, build_db.sql
undu rastreo de absolutamente todo.

mejorar el monitor 

hacer una demos de una base de datos de un organigrama de una empresa (escoger una simulacion db"revisar los documentos de XE oracle) le vamos a crear la  principio de carga de IO y si hay dinero, lo mas recomendable, crear un modelo, crear en la XE todo ahi crear n xe y hacer un traslado de los componentos internos a la nueva ex.
bases de datos distribuidas.

aun falta bitacora controladores, parametros de bases de datos.

