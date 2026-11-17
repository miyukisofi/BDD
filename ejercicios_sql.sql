-- comando para conocer esquema de una base de datos:
SELECT 
    TABLE_SCHEMA + '.' + TABLE_NAME AS Tabla,
    COLUMN_NAME AS Columna,
    DATA_TYPE AS Tipo
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_NAME, ORDINAL_POSITION;


--1. Mostrar el código y razón social de los clientes cuyo límite de crédito
-- sea mayor o igual a $ 1000 ordenado por código de cliente

select clie_codigo, clie_razon_social --Cliente (tal que su) lim_credito
 from Cliente where clie_limite_credito >= 1000
order by clie_codigo
go;

--2. Mostrar el código, detalle de todos los artículos vendidos en el año 2012 ordenados por
--cantidad vendida.

select prod_codigo, prod_detalle --"Producto (que esta en) Item_Factura (donde) id_prod = id_item_prod"
 from Producto join Item_Factura on prod_codigo = item_producto --INNER JOIN == JOIN
  join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
 where year(fact_fecha) = 2012
group by prod_codigo, prod_detalle --te pide AGRUPAR xq 1 prod esta en N facturas
order by sum(item_cantidad) --agrupar sumando la cantidad vendida de facturas donde aparece producto
--factura y producto tienen relacion (N:N), item_factura lo corta
go;

--3. Realizar una consulta que muestre código de producto, nombre de producto y el stock
--total, sin importar en que deposito se encuentre, los datos deben ser ordenados por
--nombre del artículo de menor a mayor.

select prod_codigo, prod_detalle, sum(isnull(stoc_cantidad,0))
                                --agrupar sumando el stock de cada deposito, stock podria ser null asi q pongo 0
 from Producto left join STOCK on prod_codigo = stoc_producto
               -- left join permite mostrar productos aunq no tengan stock
group by prod_codigo, prod_detalle -- 1 prod puede estar en N depositos
order by prod_detalle asc --ASC ordena de menor a mayor
go;

--4. Realizar una consulta que muestre para todos los artículos código, detalle y cantidad de
--artículos que lo componen. Mostrar solo aquellos artículos para los cuales el stock
--promedio (AVG solo puede app dsp de agrupar con having, where me permite agrupar antes, join no) por depósito sea mayor a 100.

select prod_codigo, prod_detalle, count(comp_producto)
 from Producto left join Composicion on prod_codigo = comp_producto --LEFT xq un producto puede no ser compuesto y los incluyo
 where prod_codigo in (select stoc_producto from STOCK 
                        group by stoc_producto having avg(stoc_cantidad) > 100)
group by prod_codigo, prod_detalle
go;

--5. Realizar una consulta que muestre código de artículo, detalle y cantidad de egresos de
--stock que se realizaron para ese artículo en el año 2012 (egreso = venta). Mostrar solo aquellos 
--que hayan tenido más egresos que en el 2011. (COALESCE para los casos sin ventas)
--SUM no puede usarse en where

select prod_codigo, prod_detalle, sum(item_cantidad)
 from Producto join Item_Factura on prod_codigo = item_producto --INNER JOIN == JOIN
  join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
 where year(fact_fecha) = 2012 
group by prod_codigo, prod_detalle
 having sum(item_cantidad) > COALESCE((select sum(item_cantidad) from item_factura
	                            join factura on fact_tipo+fact_sucursal+fact_numero 
		                            = item_tipo+item_sucursal+item_numero
	                            where prod_codigo = item_producto and year(fact_fecha) = 2011), 0)
                                --para que se analicen solo los productos del 2012
go;

--6. Mostrar para todos los rubros de artículos código, detalle, cantidad de artículos de ese
--rubro y stock total de ese rubro de artículos. Solo tener en cuenta aquellos artículos que
--tengan un stock mayor al del artículo ‘00000000’ en el depósito ‘00’.

select rubr_id, rubr_detalle, count(prod_rubro), sum(isnull(stoc_cantidad,0))
 from rubro left join Producto on rubr_id = prod_rubro --usar and xq filtro del join, si filtro del from puedo usar where
                               and prod_codigo in (select stoc_producto from stock
		                                           group by stoc_producto
		                                            having sum(stoc_cantidad) > (select stoc_cantidad from stock
			                                                                     where stoc_producto = '00000000' and stoc_deposito = '00'))
  left join stock on prod_codigo = stoc_producto
group by rubr_id, rubr_detalle
go;

--7. Generar una consulta que muestre para cada artículo código, detalle, mayor precio,
--menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio =
--10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos artículos que posean
--stock. NULLIF evita /0

select prod_codigo, prod_detalle, MAX(item_precio), MIN(item_precio), ((MAX(item_precio) - MIN(item_precio)) * 100 / NULLIF(MIN(item_precio), 0))
 from Producto join Item_Factura on prod_codigo = item_producto
 where prod_codigo in (select stoc_producto from stock
		               group by stoc_producto having sum(stoc_cantidad) > 0)
group by prod_codigo, prod_detalle
go;

--8. Mostrar para el o los artículos que tengan stock en todos los depósitos, nombre del
--artículo, stock del depósito que más stock tiene.

select prod_detalle, MAX(stoc_cantidad)
 from Producto join STOCK on prod_codigo = stoc_producto
group by prod_codigo, prod_detalle having count(*) = (select count(*) from DEPOSITO)
--agregar prod_cod al agrupar ya que el nombre puede repetirse y ser productos diferentes
--count(*): cant registros de stock q tiene el producto.
--(select count(*) from DEPOSITO): cant de depositos registrados
go;

--9. Mostrar el código del jefe, código del empleado que lo tiene como jefe, nombre del
--mismo y la cantidad de depósitos que ambos tienen asignados.

select empl_jefe, empl_codigo, empl_nombre, count(depo_encargado)
 from empleado left join DEPOSITO on depo_encargado = empl_jefe or depo_encargado = empl_codigo
group by empl_jefe, empl_codigo, empl_nombre
go;
--repito las 1ras 3 columnas con una cant_deposito diferente

--10. Mostrar los 10 productos más vendidos en la historia y también los 10 productos menos
--vendidos en la historia. Además mostrar de esos productos, quien fue el cliente que
--mayor compra realizo.

select prod_detalle from Producto
where prod_codigo in (select top 10 item_producto from Item_Factura 
                      group by item_producto order by sum(item_cantidad) DESC) --mas vendidos
   or prod_codigo in (select top 10 item_producto from Item_Factura 
                      group by item_producto order by sum(item_cantidad) ASC) --menos vendidos
group by prod_codigo, prod_detalle
go;

--11. Realizar una consulta que retorne el detalle de la familia, la cantidad de diferentes
--productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deberán
--ordenar de mayor a menor, por la familia que más productos diferentes vendidos tenga,
--solo se deberán mostrar las familias que tengan una venta superior a 20000 pesos para
--el año 2012.

select fami_detalle, count(distinct prod_codigo), sum(item_cantidad * item_precio)
 from Familia join Producto on fami_id = prod_codigo 
  join Item_Factura on prod_codigo = item_producto
  join Factura on fact_tipo + fact_sucursal + fact_numero =
                   item_tipo + item_sucursal + item_numero
WHERE YEAR(fact_fecha) = 2012
GROUP BY fami_id, fami_detalle
 HAVING SUM(item_cantidad * item_precio) > 20000 --xq sum no se usa en where
ORDER BY COUNT(DISTINCT prod_codigo) DESC; --mas vendidos
GO;

--12. Mostrar nombre de producto, cantidad de clientes distintos que lo compraron, importe
--promedio pagado por el producto, cantidad de depósitos en los cuales hay stock del
--producto y stock actual del producto en todos los depósitos. Se deberán mostrar
--aquellos productos que hayan tenido operaciones en el año 2012 y los datos deberán
--ordenarse de mayor a menor por monto vendido del producto.

select prod_detalle, count(distinct fact_cliente), avg(item_precio), 
       (SELECT COUNT(*) FROM STOCK
        WHERE stoc_producto = prod_codigo AND stoc_cantidad > 0),   --no se pueden devolver +1 columna en subselect
       (SELECT sum(isnull(stoc_cantidad,0)) FROM STOCK
        WHERE stoc_producto = prod_codigo)
 from Producto join Item_Factura on prod_codigo = item_producto
  join Factura on item_tipo + item_sucursal + item_numero =
                   fact_tipo + fact_sucursal + fact_numero
where exists (select 1 from Item_Factura join Factura on item_tipo + item_sucursal + item_numero =
                                                          fact_tipo + fact_sucursal + fact_numero
               where prod_codigo = item_producto and YEAR(fact_fecha) = 2012)
group by prod_codigo, prod_detalle
order by sum(item_cantidad * item_precio) desc
go;

--13. Realizar una consulta que retorne para cada producto que posea composición nombre
--del producto, precio del producto, precio de la sumatoria de los precios por la cantidad 
--de los productos que lo componen. Solo se deberán mostrar los productos que estén
--compuestos por más de 2 productos y deben ser ordenados de mayor a menor por
--cantidad de productos que lo componen.

SELECT (SELECT prod_detalle FROM Producto
        WHERE prod_codigo = comp_producto),
       (SELECT prod_precio FROM Producto
        WHERE prod_codigo = comp_producto),
       SUM(prod_precio) * COUNT(comp_producto)
FROM Composicion JOIN Producto ON prod_codigo = comp_componente
GROUP BY comp_producto      --no se puede agrupar por producto xq es N, agrupo del 1
 HAVING COUNT(comp_producto) > 2
ORDER BY COUNT(comp_producto) DESC
go;

--14. Escriba una consulta que retorne una estadística de ventas por cliente. Los campos que
--debe retornar son:
--Código del cliente
--Cantidad de veces que compro en el último año
--Promedio por compra en el último año
--Cantidad de productos diferentes que compro en el último año
--Monto de la mayor compra que realizo en el último año
--Se deberán retornar todos los clientes ordenados por la cantidad de veces que compro en
--el último año.
--No se deberán visualizar NULLs en ninguna columna

select clie_codigo, count(distinct fact_tipo + fact_sucursal + fact_numero),
        isnull(avg(fact_total),0), count(distinct item_producto), isnull(MAX(fact_total),0)
 from Cliente left join Factura on clie_codigo = fact_cliente 
                                and YEAR(fact_fecha) = YEAR(GETDATE()) - 1 --ultimo año calendario
  join Item_Factura on item_tipo + item_sucursal + item_numero =
                        fact_tipo + fact_sucursal + fact_numero
group by clie_codigo
order by count(distinct fact_tipo + fact_sucursal + fact_numero)
go;

--15. Escriba una consulta que retorne los pares de productos que hayan sido vendidos juntos
--(en la misma factura) más de 500 veces. El resultado debe mostrar el código y
--descripción de cada uno de los productos y la cantidad de veces que fueron vendidos
--juntos. El resultado debe estar ordenado por la cantidad de veces que se vendieron
--juntos dichos productos. Los distintos pares no deben retornarse más de una vez.
--Ejemplo de lo que retornaría la consulta:
--PROD1 DETALLE1 PROD2 DETALLE2 VECES
--1731 MARLBORO KS 1 7 1 8 P H ILIPS MORRIS KS 5 0 7
--1718 PHILIPS MORRIS KS 1 7 0 5 P H I L I P S MORRIS BOX 10 5 6 2

SELECT p1.prod_codigo, p1.prod_detalle,
       p2.prod_codigo, p2.prod_detalle,
       COUNT(DISTINCT i1.item_tipo + i1.item_sucursal + i1.item_numero)
 FROM Item_Factura i1 JOIN Item_Factura i2 ON i1.item_tipo = i2.item_tipo
                                           AND i1.item_sucursal = i2.item_sucursal
                                           AND i1.item_numero = i2.item_numero
                                           AND i1.item_producto < i2.item_producto
  JOIN Producto p1 ON p1.prod_codigo = i1.item_producto
  JOIN Producto p2 ON p2.prod_codigo = i2.item_producto
GROUP BY p1.prod_codigo, p1.prod_detalle,
         p2.prod_codigo, p2.prod_detalle
 HAVING COUNT(DISTINCT i1.item_tipo + i1.item_sucursal + i1.item_numero) > 500
ORDER BY COUNT(DISTINCT i1.item_tipo + i1.item_sucursal + i1.item_numero) DESC;
GO;

--16. se pide una consulta SQL que retorne los clientes cuyas compras
--son inferiores a 1/3 del monto de ventas del producto que más se vendió en el 2012.
--Además mostrar
--1. Nombre del Cliente
--2. Cantidad de unidades totales vendidas en el 2012 para ese cliente.
--3. Código de producto que mayor venta tuvo en el 2012 (en caso de existir más de 1,
--mostrar solamente el de menor código) para ese cliente.

select clie_razon_social,
       sum(isnull(item_cantidad,0)),
       (select top (1) item_producto from factura 
            join Item_Factura on item_tipo + item_sucursal + item_numero =
                                 fact_tipo + fact_sucursal + fact_numero
        where fact_cliente = clie_codigo and YEAR(fact_fecha) = 2012
        GROUP BY item_producto
        ORDER BY SUM(item_cantidad * item_precio) DESC, item_producto ASC) --criterio principal, criterio desempate
from Cliente left join Factura on fact_cliente = clie_codigo and YEAR(fact_fecha) = 2012
             left join Item_Factura on item_tipo + item_sucursal + item_numero =
                                       fact_tipo + fact_sucursal + fact_numero
group by clie_codigo, clie_razon_social
 having SUM(item_cantidad * item_precio) < (select top (1) SUM(item_cantidad * item_precio) from factura 
                                                join Item_Factura on item_tipo + item_sucursal + item_numero =
                                                                     fact_tipo + fact_sucursal + fact_numero
                                            where fact_cliente = clie_codigo and YEAR(fact_fecha) = 2012
                                            GROUP BY item_producto
                                            ORDER BY SUM(item_cantidad * item_precio) DESC, item_producto ASC) / CAST(3 AS decimal(18, 2));

--17. Escriba una consulta que retorne una estadística de ventas por año y mes para cada
--producto.
--La consulta debe retornar:
--PERIODO: Año y mes de la estadística con el formato YYYYMM
--PROD: Código de producto
--DETALLE: Detalle del producto
--CANTIDAD_VENDIDA= Cantidad vendida del producto en el periodo
--VENTAS_AÑO_ANT= Cantidad vendida del producto en el mismo mes del periodo
--pero del año anterior
--CANT_FACTURAS= Cantidad de facturas en las que se vendió el producto en el
--periodo
--La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada
--por periodo y código de producto.

SELECT CONVERT(CHAR(4),YEAR(f.fact_fecha))+RIGHT('0'+CONVERT(VARCHAR(2),MONTH(f.fact_fecha)),2) PERIODO,
 p.prod_codigo PROD,p.prod_detalle DETALLE,SUM(i.item_cantidad) CANTIDAD_VENDIDA,
 ISNULL((SELECT SUM(i2.item_cantidad) FROM Item_Factura i2 JOIN Factura f2
 ON f2.fact_tipo+f2.fact_sucursal+f2.fact_numero=i2.item_tipo+i2.item_sucursal+i2.item_numero
 WHERE i2.item_producto=p.prod_codigo AND YEAR(f2.fact_fecha)=YEAR(f.fact_fecha)-1
 AND MONTH(f2.fact_fecha)=MONTH(f.fact_fecha)),0) VENTAS_ANIO_ANT,
 COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) CANT_FACTURAS
FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo
JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
GROUP BY p.prod_codigo,p.prod_detalle,YEAR(f.fact_fecha),MONTH(f.fact_fecha)
ORDER BY YEAR(f.fact_fecha),MONTH(f.fact_fecha),p.prod_codigo;
GO;

--18. Escriba una consulta que retorne una estadística de ventas para todos los rubros.
--La consulta debe retornar:
--DETALLE_RUBRO: Detalle del rubro
--VENTAS: Suma de las ventas en pesos de productos vendidos de dicho rubro
--PROD1: Código del producto más vendido de dicho rubro
--PROD2: Código del segundo producto más vendido de dicho rubro
--CLIENTE: Código del cliente que compro más productos del rubro en los últimos 30
--días
--La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada
--por cantidad de productos diferentes vendidos del rubro.

SELECT r.rubr_detalle,
 ISNULL(v.ventas,0) VENTAS,ISNULL(m.prod1,'') PROD1,ISNULL(s.prod2,'') PROD2,ISNULL(c.cliente,'') CLIENTE
FROM Rubro r
LEFT JOIN (SELECT p.prod_rubro,SUM(i.item_cantidad*i.item_precio) ventas FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo GROUP BY p.prod_rubro) v ON v.prod_rubro=r.rubr_id
OUTER APPLY (SELECT TOP 1 p.prod_codigo prod1 FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo WHERE p.prod_rubro=r.rubr_id GROUP BY p.prod_codigo ORDER BY SUM(i.item_cantidad) DESC,p.prod_codigo) m
OUTER APPLY (SELECT TOP 1 p.prod_codigo prod2 FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo WHERE p.prod_rubro=r.rubr_id AND p.prod_codigo<>m.prod1 GROUP BY p.prod_codigo ORDER BY SUM(i.item_cantidad) DESC,p.prod_codigo) s
OUTER APPLY (SELECT TOP 1 f.fact_cliente cliente FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero WHERE p.prod_rubro=r.rubr_id AND f.fact_fecha>=DATEADD(DAY,-30,GETDATE()) GROUP BY f.fact_cliente ORDER BY COUNT(DISTINCT p.prod_codigo) DESC,f.fact_cliente) c
ORDER BY (SELECT COUNT(DISTINCT p.prod_codigo) FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo WHERE p.prod_rubro=r.rubr_id) DESC;
GO;

--19. En virtud de una recategorizacion de productos referida a la familia de los mismos se
--solicita que desarrolle una consulta sql que retorne para todos los productos:
-- Codigo de producto
-- Detalle del producto
-- Codigo de la familia del producto
-- Detalle de la familia actual del producto
-- Codigo de la familia sugerido para el producto
-- Detalla de la familia sugerido para el producto
--La familia sugerida para un producto es la que poseen la mayoria de los productos cuyo
--detalle coinciden en los primeros 5 caracteres.
--En caso que 2 o mas familias pudieran ser sugeridas se debera seleccionar la de menor
--codigo. Solo se deben mostrar los productos para los cuales la familia actual sea
--diferente a la sugerida
--Los resultados deben ser ordenados por detalle de producto de manera ascendente

SELECT p.prod_codigo,p.prod_detalle,p.prod_familia,fa.fami_detalle familia_actual,s.fami_id familia_sugerida,s.fami_detalle detalle_familia_sugerida
FROM Producto p JOIN Familia fa ON fa.fami_id=p.prod_familia
CROSS APPLY (SELECT TOP 1 p2.prod_familia fami_id,f2.fami_detalle FROM Producto p2 JOIN Familia f2 ON f2.fami_id=p2.prod_familia
 WHERE LEFT(p2.prod_detalle,5)=LEFT(p.prod_detalle,5) GROUP BY p2.prod_familia,f2.fami_detalle ORDER BY COUNT(*) DESC,p2.prod_familia) s
WHERE p.prod_familia<>s.fami_id ORDER BY p.prod_detalle;
GO;

--20. Escriba una consulta sql que retorne un ranking de los mejores 3 empleados del 2012
--Se debera retornar legajo, nombre y apellido, anio de ingreso, puntaje 2011, puntaje
--2012. El puntaje de cada empleado se calculara de la siguiente manera: para los que
--hayan vendido al menos 50 facturas el puntaje se calculara como la cantidad de facturas
--que superen los 100 pesos que haya vendido en el año, para los que tengan menos de 50
--facturas en el año el calculo del puntaje sera el 50% de cantidad de facturas realizadas
--por sus subordinados directos en dicho año.

SELECT TOP 3 e.empl_codigo,e.empl_nombre,e.empl_apellido,YEAR(e.empl_ingreso) anio_ingreso,
 CASE WHEN q.c2011>=50 THEN q.m2011 ELSE 0.5*q.sub2011 END puntaje_2011,
 CASE WHEN q.c2012>=50 THEN q.m2012 ELSE 0.5*q.sub2012 END puntaje_2012
FROM Empleado e
CROSS APPLY (SELECT
 (SELECT COUNT(*) FROM Factura f WHERE f.fact_vendedor=e.empl_codigo AND YEAR(f.fact_fecha)=2011) c2011,
 (SELECT COUNT(*) FROM Factura f WHERE f.fact_vendedor=e.empl_codigo AND YEAR(f.fact_fecha)=2012) c2012,
 (SELECT COUNT(*) FROM Factura f WHERE f.fact_vendedor=e.empl_codigo AND YEAR(f.fact_fecha)=2011 AND f.fact_total>100) m2011,
 (SELECT COUNT(*) FROM Factura f WHERE f.fact_vendedor=e.empl_codigo AND YEAR(f.fact_fecha)=2012 AND f.fact_total>100) m2012,
 (SELECT COUNT(*) FROM Factura f JOIN Empleado s ON s.empl_codigo=f.fact_vendedor WHERE s.empl_jefe=e.empl_codigo AND YEAR(f.fact_fecha)=2011) sub2011,
 (SELECT COUNT(*) FROM Factura f JOIN Empleado s ON s.empl_codigo=f.fact_vendedor WHERE s.empl_jefe=e.empl_codigo AND YEAR(f.fact_fecha)=2012) sub2012) q
ORDER BY puntaje_2012 DESC;
GO;

--21. Escriba una consulta sql que retorne para todos los años, en los cuales se haya hecho al
--menos una factura, la cantidad de clientes a los que se les facturo de manera incorrecta
--al menos una factura y que cantidad de facturas se realizaron de manera incorrecta. Se
--considera que una factura es incorrecta cuando la diferencia entre el total de la factura
--menos el total de impuesto tiene una diferencia mayor a $ 1 respecto a la sumatoria de
--los costos de cada uno de los items de dicha factura. Las columnas que se deben mostrar
--son:
-- Año
-- Clientes a los que se les facturo mal en ese año
-- Facturas mal realizadas en ese año

SELECT YEAR(f.fact_fecha) anio,COUNT(DISTINCT f.fact_cliente) clientes_facturados_mal,COUNT(*) facturas_incorrectas
FROM Factura f JOIN Item_Factura i ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
GROUP BY YEAR(f.fact_fecha),f.fact_tipo,f.fact_sucursal,f.fact_numero,f.fact_cliente,f.fact_total,f.fact_total_impuestos
HAVING ABS((f.fact_total-f.fact_total_impuestos)-SUM(i.item_cantidad*i.item_precio))>1
ORDER BY YEAR(f.fact_fecha);
GO;

--22. Escriba una consulta sql que retorne una estadistica de venta para todos los rubros por
--trimestre contabilizando todos los años. Se mostraran como maximo 4 filas por rubro (1
--por cada trimestre).
--Se deben mostrar 4 columnas:
-- Detalle del rubro
-- Numero de trimestre del año (1 a 4)
-- Cantidad de facturas emitidas en el trimestre en las que se haya vendido al
--menos un producto del rubro
-- Cantidad de productos diferentes del rubro vendidos en el trimestre
--El resultado debe ser ordenado alfabeticamente por el detalle del rubro y dentro de cada
--rubro primero el trimestre en el que mas facturas se emitieron.
--No se deberan mostrar aquellos rubros y trimestres para los cuales las facturas emitiadas
--no superen las 100.
--En ningun momento se tendran en cuenta los productos compuestos para esta
--estadistica.

SELECT r.rubr_detalle,DATEPART(QUARTER,f.fact_fecha) trimestre,
 COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) facturas,COUNT(DISTINCT p.prod_codigo) productos_diferentes
FROM Rubro r JOIN Producto p ON p.prod_rubro=r.rubr_id
JOIN Item_Factura i ON i.item_producto=p.prod_codigo
JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
WHERE NOT EXISTS(SELECT 1 FROM Composicion co WHERE co.comp_producto=p.prod_codigo)
GROUP BY r.rubr_id,r.rubr_detalle,DATEPART(QUARTER,f.fact_fecha)
HAVING COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero)>100
ORDER BY r.rubr_detalle,facturas DESC;
GO;

--23. Realizar una consulta SQL que para cada año muestre :
-- Año
-- El producto con composición más vendido para ese año.
-- Cantidad de productos que componen directamente al producto más vendido
-- La cantidad de facturas en las cuales aparece ese producto.
-- El código de cliente que más compro ese producto.
-- El porcentaje que representa la venta de ese producto respecto al total de venta
--del año.
--El resultado deberá ser ordenado por el total vendido por año en forma descendente.

SELECT a.anio,a.prod_codigo,a.componentes,a.facturas,a.cliente,
 a.venta*100.0/NULLIF(t.total_anio,0) porcentaje_venta
FROM (SELECT YEAR(f.fact_fecha) anio,p.prod_codigo,COUNT(DISTINCT co.comp_componente) componentes,
 SUM(i.item_cantidad) unidades,COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) facturas,
 SUM(i.item_cantidad*i.item_precio) venta
 FROM Producto p JOIN Composicion co ON co.comp_producto=p.prod_codigo
 JOIN Item_Factura i ON i.item_producto=p.prod_codigo
 JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
 GROUP BY YEAR(f.fact_fecha),p.prod_codigo) a
JOIN (SELECT YEAR(f.fact_fecha) anio,SUM(i.item_cantidad*i.item_precio) total_anio FROM Item_Factura i JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero GROUP BY YEAR(f.fact_fecha)) t ON t.anio=a.anio
CROSS APPLY (SELECT TOP 1 f.fact_cliente FROM Factura f JOIN Item_Factura i ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero WHERE YEAR(f.fact_fecha)=a.anio AND i.item_producto=a.prod_codigo GROUP BY f.fact_cliente ORDER BY SUM(i.item_cantidad) DESC,f.fact_cliente) c(cliente)
WHERE a.prod_codigo=(SELECT TOP 1 p2.prod_codigo FROM Producto p2 JOIN Composicion co2 ON co2.comp_producto=p2.prod_codigo JOIN Item_Factura i2 ON i2.item_producto=p2.prod_codigo JOIN Factura f2 ON f2.fact_tipo+f2.fact_sucursal+f2.fact_numero=i2.item_tipo+i2.item_sucursal+i2.item_numero WHERE YEAR(f2.fact_fecha)=a.anio GROUP BY p2.prod_codigo ORDER BY SUM(i2.item_cantidad) DESC,p2.prod_codigo)
ORDER BY a.venta DESC;
GO;

--24. Escriba una consulta que considerando solamente las facturas correspondientes a los
--dos vendedores con mayores comisiones, retorne los productos con composición
--facturados al menos en cinco facturas,
--La consulta debe retornar las siguientes columnas:
-- Código de Producto
-- Nombre del Producto
-- Unidades facturadas
--El resultado deberá ser ordenado por las unidades facturadas descendente.

SELECT p.prod_codigo,p.prod_detalle,SUM(i.item_cantidad) unidades_facturadas
FROM Producto p JOIN Composicion c ON c.comp_producto=p.prod_codigo
JOIN Item_Factura i ON i.item_producto=p.prod_codigo
JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
WHERE f.fact_vendedor IN (SELECT TOP 2 empl_codigo FROM Empleado ORDER BY empl_comision DESC,empl_codigo)
GROUP BY p.prod_codigo,p.prod_detalle
HAVING COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero)>=5
ORDER BY SUM(i.item_cantidad) DESC;
GO;

--25. Realizar una consulta SQL que para cada año y familia muestre :
--a. Año
--b. El código de la familia más vendida en ese año.
--c. Cantidad de Rubros que componen esa familia.
--d. Cantidad de productos que componen directamente al producto más vendido de
--esa familia.
--e. La cantidad de facturas en las cuales aparecen productos pertenecientes a esa
--familia.
--f. El código de cliente que más compro productos de esa familia.
--g. El porcentaje que representa la venta de esa familia respecto al total de venta
--del año.
--El resultado deberá ser ordenado por el total vendido por año y familia en forma
--descendente.

SELECT z.anio,z.familia,z.rubros,z.componentes,z.facturas,z.cliente,z.venta*100.0/NULLIF(z.total_anio,0) porcentaje
FROM (SELECT YEAR(f.fact_fecha) anio,p.prod_familia familia,COUNT(DISTINCT p.prod_rubro) rubros,
 SUM(i.item_cantidad*i.item_precio) venta,COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) facturas,
 (SELECT COUNT(*) FROM Composicion co WHERE co.comp_producto=(SELECT TOP 1 p2.prod_codigo FROM Producto p2 JOIN Item_Factura i2 ON i2.item_producto=p2.prod_codigo JOIN Factura f2 ON f2.fact_tipo+f2.fact_sucursal+f2.fact_numero=i2.item_tipo+i2.item_sucursal+i2.item_numero WHERE p2.prod_familia=p.prod_familia AND YEAR(f2.fact_fecha)=YEAR(f.fact_fecha) GROUP BY p2.prod_codigo ORDER BY SUM(i2.item_cantidad) DESC,p2.prod_codigo)) componentes,
 SUM(SUM(i.item_cantidad*i.item_precio)) OVER(PARTITION BY YEAR(f.fact_fecha)) total_anio
 FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
 GROUP BY YEAR(f.fact_fecha),p.prod_familia) z
CROSS APPLY (SELECT TOP 1 f.fact_cliente FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero WHERE p.prod_familia=z.familia AND YEAR(f.fact_fecha)=z.anio GROUP BY f.fact_cliente ORDER BY SUM(i.item_cantidad) DESC,f.fact_cliente) c(cliente)
WHERE z.familia=(SELECT TOP 1 p.prod_familia FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero WHERE YEAR(f.fact_fecha)=z.anio GROUP BY p.prod_familia ORDER BY SUM(i.item_cantidad) DESC,p.prod_familia)
ORDER BY z.venta DESC;
GO;

--26. Escriba una consulta sql que retorne un ranking de empleados devolviendo las
--siguientes columnas:
-- Empleado
-- Depósitos que tiene a cargo
-- Monto total facturado en el año corriente
-- Codigo de Cliente al que mas le vendió
-- Producto más vendido
-- Porcentaje de la venta de ese empleado sobre el total vendido ese año.
--Los datos deberan ser ordenados por venta del empleado de mayor a menor.

SELECT e.empl_codigo,e.empl_nombre+' '+e.empl_apellido empleado,
 (SELECT COUNT(*) FROM DEPOSITO d WHERE d.depo_encargado=e.empl_codigo) depositos,
 ISNULL(v.monto,0) monto_facturado,ISNULL(c.cliente,'') cliente_mayor,
 ISNULL(p.producto,'') producto_mas_vendido,
 ISNULL(v.monto*100.0/NULLIF(t.total,0),0) porcentaje
FROM Empleado e
LEFT JOIN (SELECT fact_vendedor,SUM(fact_total) monto FROM Factura WHERE YEAR(fact_fecha)=YEAR(GETDATE()) GROUP BY fact_vendedor) v ON v.fact_vendedor=e.empl_codigo
OUTER APPLY (SELECT TOP 1 fact_cliente cliente FROM Factura WHERE fact_vendedor=e.empl_codigo AND YEAR(fact_fecha)=YEAR(GETDATE()) GROUP BY fact_cliente ORDER BY SUM(fact_total) DESC,fact_cliente) c
OUTER APPLY (SELECT TOP 1 i.item_producto producto FROM Factura f JOIN Item_Factura i ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero WHERE f.fact_vendedor=e.empl_codigo AND YEAR(f.fact_fecha)=YEAR(GETDATE()) GROUP BY i.item_producto ORDER BY SUM(i.item_cantidad) DESC,i.item_producto) p
CROSS JOIN (SELECT SUM(fact_total) total FROM Factura WHERE YEAR(fact_fecha)=YEAR(GETDATE())) t
ORDER BY v.monto DESC;
GO;

--27. Escriba una consulta sql que retorne una estadística basada en la facturacion por año y
--envase devolviendo las siguientes columnas:
-- Año
-- Codigo de envase
-- Detalle del envase
-- Cantidad de productos que tienen ese envase
-- Cantidad de productos facturados de ese envase
-- Producto mas vendido de ese envase
-- Monto total de venta de ese envase en ese año
-- Porcentaje de la venta de ese envase respecto al total vendido de ese año
--Los datos deberan ser ordenados por año y dentro del año por el envase con más
--facturación de mayor a menor

SELECT YEAR(f.fact_fecha) anio,en.enva_codigo,en.enva_detalle,
 (SELECT COUNT(*) FROM Producto p WHERE p.prod_envase=en.enva_codigo) productos_envase,
 COUNT(DISTINCT i.item_producto) productos_facturados,
 (SELECT TOP 1 i2.item_producto FROM Item_Factura i2 JOIN Factura f2 ON f2.fact_tipo+f2.fact_sucursal+f2.fact_numero=i2.item_tipo+i2.item_sucursal+i2.item_numero JOIN Producto p2 ON p2.prod_codigo=i2.item_producto WHERE p2.prod_envase=en.enva_codigo AND YEAR(f2.fact_fecha)=YEAR(f.fact_fecha) GROUP BY i2.item_producto ORDER BY SUM(i2.item_cantidad) DESC,i2.item_producto) producto_mas_vendido,
 SUM(i.item_cantidad*i.item_precio) monto,
 SUM(i.item_cantidad*i.item_precio)*100.0/NULLIF((SELECT SUM(i3.item_cantidad*i3.item_precio) FROM Item_Factura i3 JOIN Factura f3 ON f3.fact_tipo+f3.fact_sucursal+f3.fact_numero=i3.item_tipo+i3.item_sucursal+i3.item_numero WHERE YEAR(f3.fact_fecha)=YEAR(f.fact_fecha)),0) porcentaje
FROM Envases en JOIN Producto p ON p.prod_envase=en.enva_codigo JOIN Item_Factura i ON i.item_producto=p.prod_codigo JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
GROUP BY YEAR(f.fact_fecha),en.enva_codigo,en.enva_detalle
ORDER BY YEAR(f.fact_fecha),monto DESC;
GO;

--28. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las
--siguientes columnas:
-- Año.
-- Codigo de Vendedor
-- Detalle del Vendedor
-- Cantidad de facturas que realizó en ese año
-- Cantidad de clientes a los cuales les vendió en ese año.
-- Cantidad de productos facturados con composición en ese año
-- Cantidad de productos facturados sin composicion en ese año.
-- Monto total vendido por ese vendedor en ese año
--Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya
--vendido mas productos diferentes de mayor a menor.

SELECT YEAR(f.fact_fecha) anio,e.empl_codigo,e.empl_nombre+' '+e.empl_apellido vendedor,
 COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) facturas,COUNT(DISTINCT f.fact_cliente) clientes,
 COUNT(DISTINCT CASE WHEN EXISTS(SELECT 1 FROM Composicion co WHERE co.comp_producto=i.item_producto) THEN i.item_producto END) productos_compuestos,
 COUNT(DISTINCT CASE WHEN NOT EXISTS(SELECT 1 FROM Composicion co WHERE co.comp_producto=i.item_producto) THEN i.item_producto END) productos_no_compuestos,
 SUM(i.item_cantidad*i.item_precio) monto
FROM Empleado e JOIN Factura f ON f.fact_vendedor=e.empl_codigo JOIN Item_Factura i ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
GROUP BY YEAR(f.fact_fecha),e.empl_codigo,e.empl_nombre,e.empl_apellido
ORDER BY YEAR(f.fact_fecha),COUNT(DISTINCT i.item_producto) DESC;
GO;

--29. Se solicita que realice una estadística de venta por producto para el año 2011, solo para
--los productos que pertenezcan a las familias que tengan más de 20 productos asignados
--a ellas, la cual deberá devolver las siguientes columnas:
--a. Código de producto
--b. Descripción del producto
--c. Cantidad vendida
--d. Cantidad de facturas en la que esta ese producto
--e. Monto total facturado de ese producto
--Solo se deberá mostrar un producto por fila en función a los considerandos establecidos
--antes. El resultado deberá ser ordenado por el la cantidad vendida de mayor a menor.

SELECT p.prod_codigo,p.prod_detalle,SUM(i.item_cantidad) cantidad_vendida,
 COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) facturas,SUM(i.item_cantidad*i.item_precio) monto
FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
WHERE YEAR(f.fact_fecha)=2011 AND p.prod_familia IN (SELECT prod_familia FROM Producto GROUP BY prod_familia HAVING COUNT(*)>20)
GROUP BY p.prod_codigo,p.prod_detalle ORDER BY SUM(i.item_cantidad) DESC;
GO;

--30. Se desea obtener una estadistica de ventas del año 2012, para los empleados que sean
--jefes, o sea, que tengan empleados a su cargo, para ello se requiere que realice la
--consulta que retorne las siguientes columnas:
-- Nombre del Jefe
-- Cantidad de empleados a cargo
-- Monto total vendido de los empleados a cargo
-- Cantidad de facturas realizadas por los empleados a cargo
-- Nombre del empleado con mejor ventas de ese jefe
--Debido a la perfomance requerida, solo se permite el uso de una subconsulta si fuese
--necesario.
--Los datos deberan ser ordenados por de mayor a menor por el Total vendido y solo se
--deben mostrarse los jefes cuyos subordinados hayan realizado más de 10 facturas.

SELECT e.empl_nombre+' '+e.empl_apellido jefe,COUNT(DISTINCT s.empl_codigo) empleados_a_cargo,
 SUM(f.fact_total) monto_total,COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) facturas,
 (SELECT TOP 1 s2.empl_nombre+' '+s2.empl_apellido FROM Empleado s2 JOIN Factura f2 ON f2.fact_vendedor=s2.empl_codigo WHERE s2.empl_jefe=e.empl_codigo AND YEAR(f2.fact_fecha)=2012 GROUP BY s2.empl_codigo,s2.empl_nombre,s2.empl_apellido ORDER BY SUM(f2.fact_total) DESC,s2.empl_codigo) mejor_vendedor
FROM Empleado e JOIN Empleado s ON s.empl_jefe=e.empl_codigo JOIN Factura f ON f.fact_vendedor=s.empl_codigo AND YEAR(f.fact_fecha)=2012
GROUP BY e.empl_codigo,e.empl_nombre,e.empl_apellido HAVING COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero)>10
ORDER BY SUM(f.fact_total) DESC;
GO;

--31. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las
--siguientes columnas:
-- Año.
-- Codigo de Vendedor
-- Detalle del Vendedor
-- Cantidad de facturas que realizó en ese año
-- Cantidad de clientes a los cuales les vendió en ese año.
-- Cantidad de productos facturados con composición en ese año
-- Cantidad de productos facturados sin composicion en ese año.
-- Monto total vendido por ese vendedor en ese año
--Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya
--vendido mas productos diferentes de mayor a menor.

SELECT YEAR(f.fact_fecha) anio,e.empl_codigo,e.empl_nombre+' '+e.empl_apellido vendedor,
 COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) facturas,COUNT(DISTINCT f.fact_cliente) clientes,
 COUNT(DISTINCT CASE WHEN EXISTS(SELECT 1 FROM Composicion co WHERE co.comp_producto=i.item_producto) THEN i.item_producto END) productos_compuestos,
 COUNT(DISTINCT CASE WHEN NOT EXISTS(SELECT 1 FROM Composicion co WHERE co.comp_producto=i.item_producto) THEN i.item_producto END) productos_no_compuestos,
 SUM(i.item_cantidad*i.item_precio) monto
FROM Empleado e JOIN Factura f ON f.fact_vendedor=e.empl_codigo JOIN Item_Factura i ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
GROUP BY YEAR(f.fact_fecha),e.empl_codigo,e.empl_nombre,e.empl_apellido
ORDER BY YEAR(f.fact_fecha),COUNT(DISTINCT i.item_producto) DESC;
GO;

--32. Se desea conocer las familias que sus productos se facturaron juntos en las mismas
--facturas para ello se solicita que escriba una consulta sql que retorne los pares de
--familias que tienen productos que se facturaron juntos. Para ellos deberá devolver las
--siguientes columnas:
-- Código de familia
-- Detalle de familia
-- Código de familia
-- Detalle de familia
-- Cantidad de facturas
-- Total vendido
--Los datos deberan ser ordenados por Total vendido y solo se deben mostrar las familias
--que se vendieron juntas más de 10 veces.

SELECT f1.fami_id,f1.fami_detalle,f2.fami_id,f2.fami_detalle,
 COUNT(DISTINCT i1.item_tipo+i1.item_sucursal+i1.item_numero) facturas,
 SUM(i1.item_cantidad*i1.item_precio)+SUM(i2.item_cantidad*i2.item_precio) total_vendido
FROM Item_Factura i1 JOIN Item_Factura i2 ON i1.item_tipo=i2.item_tipo AND i1.item_sucursal=i2.item_sucursal AND i1.item_numero=i2.item_numero AND i1.item_producto<i2.item_producto
JOIN Producto p1 ON p1.prod_codigo=i1.item_producto JOIN Producto p2 ON p2.prod_codigo=i2.item_producto
JOIN Familia f1 ON f1.fami_id=p1.prod_familia JOIN Familia f2 ON f2.fami_id=p2.prod_familia
WHERE f1.fami_id<f2.fami_id
GROUP BY f1.fami_id,f1.fami_detalle,f2.fami_id,f2.fami_detalle
HAVING COUNT(DISTINCT i1.item_tipo+i1.item_sucursal+i1.item_numero)>10
ORDER BY total_vendido DESC;
GO;

--33. Se requiere obtener una estadística de venta de productos que sean componentes. Para
--ello se solicita que realiza la siguiente consulta que retorne la venta de los
--componentes del producto más vendido del año 2012. Se deberá mostrar:
--a. Código de producto
--b. Nombre del producto
--c. Cantidad de unidades vendidas
--d. Cantidad de facturas en la cual se facturo
--e. Precio promedio facturado de ese producto.
--f. Total facturado para ese producto
--El resultado deberá ser ordenado por el total vendido por producto para el año 2012.

SELECT p.prod_codigo,p.prod_detalle,SUM(i.item_cantidad) unidades,
 COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) facturas,AVG(i.item_precio) precio_promedio,
 SUM(i.item_cantidad*i.item_precio) total
FROM Producto p JOIN Composicion c ON c.comp_componente=p.prod_codigo
JOIN Item_Factura i ON i.item_producto=p.prod_codigo JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
WHERE YEAR(f.fact_fecha)=2012 AND i.item_producto IN
 (SELECT TOP 1 i2.item_producto FROM Item_Factura i2 JOIN Factura f2 ON f2.fact_tipo+f2.fact_sucursal+f2.fact_numero=i2.item_tipo+i2.item_sucursal+i2.item_numero WHERE YEAR(f2.fact_fecha)=2012 GROUP BY i2.item_producto ORDER BY SUM(i2.item_cantidad) DESC,i2.item_producto)
GROUP BY p.prod_codigo,p.prod_detalle ORDER BY SUM(i.item_cantidad*i.item_precio) DESC;
GO;

--34. Escriba una consulta sql que retorne para todos los rubros la cantidad de facturas mal
--facturadas por cada mes del año 2011 Se considera que una factura es incorrecta cuando
--en la misma factura se factutan productos de dos rubros diferentes. Si no hay facturas
--mal hechas se debe retornar 0. Las columnas que se deben mostrar son:
--1- Codigo de Rubro
--2- Mes
--3- Cantidad de facturas mal realizadas.

SELECT r.rubr_id,meses.mes,COUNT(DISTINCT CASE WHEN mal.facturas>1 THEN mal.factura END) facturas_incorrectas
FROM Rubro r CROSS JOIN (SELECT 1 mes UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12) meses
LEFT JOIN (SELECT p.prod_rubro,MONTH(f.fact_fecha) mes,
 f.fact_tipo+f.fact_sucursal+f.fact_numero factura
 FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
 WHERE YEAR(f.fact_fecha)=2011
 GROUP BY p.prod_rubro,MONTH(f.fact_fecha),f.fact_tipo,f.fact_sucursal,f.fact_numero
 HAVING COUNT(DISTINCT p.prod_rubro)>1) mal ON mal.prod_rubro=r.rubr_id AND mal.mes=meses.mes
GROUP BY r.rubr_id,meses.mes ORDER BY r.rubr_id,meses.mes;
GO;

--35. Se requiere realizar una estadística de ventas por año y producto, para ello se solicita
--que escriba una consulta sql que retorne las siguientes columnas:
-- Año
-- Codigo de producto
-- Detalle del producto
-- Cantidad de facturas emitidas a ese producto ese año
-- Cantidad de vendedores diferentes que compraron ese producto ese año.
-- Cantidad de productos a los cuales compone ese producto, si no compone a ninguno
--se debera retornar 0.
-- Porcentaje de la venta de ese producto respecto a la venta total de ese año.
--Los datos deberan ser ordenados por año y por producto con mayor cantidad vendida
-- RESPUESTAS 17 A 35
-- Nota: se usan subconsultas/derivadas en FROM, como prefiere el profesor.

SELECT YEAR(f.fact_fecha) anio,p.prod_codigo,p.prod_detalle,
 COUNT(DISTINCT f.fact_tipo+f.fact_sucursal+f.fact_numero) facturas,
 COUNT(DISTINCT f.fact_vendedor) vendedores,
 (SELECT COUNT(*) FROM Composicion c WHERE c.comp_componente=p.prod_codigo) productos_a_los_que_compone,
 SUM(i.item_cantidad*i.item_precio)*100.0/NULLIF(SUM(SUM(i.item_cantidad*i.item_precio)) OVER(PARTITION BY YEAR(f.fact_fecha)),0) porcentaje_venta
FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo
JOIN Factura f ON f.fact_tipo+f.fact_sucursal+f.fact_numero=i.item_tipo+i.item_sucursal+i.item_numero
GROUP BY YEAR(f.fact_fecha),p.prod_codigo,p.prod_detalle
ORDER BY YEAR(f.fact_fecha),SUM(i.item_cantidad) DESC;
GO;




--22: excluye productos compuestos (aquellos que son producto de composición)


--25: familia más vendida por año y métricas de esa familia


--31: misma estadística solicitada en ejercicio 28


--34: una factura incorrecta implica que contiene más de un rubro; se cuenta para cada rubro involucrado



