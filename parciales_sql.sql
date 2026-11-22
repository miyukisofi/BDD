--SQL

--1. listado de productos cuyas ventas del año 2012 fueron superiores al 15% del promedio de ventas
-- de los productos vendidos entre los años 2010 y 2011. Retornar: detalle del producto, 
-- mostrar "popular" si el producto figura en mas de 100 facturas del 2012 sino "sin interes",
-- cantidad de facturas en las que aparece el producto en el año 2012,
-- codigo del cliente que mas compro ese producto en el 2012 (si existe mas de 1 cliente, mostrar el de menor codigo)
select prod_detalle, 
       CASE 
        WHEN COUNT(DISTINCT fact_tipo+fact_numero+fact_sucursal) > 100 
            THEN 'popular'
        ELSE 'sin interes' 
       end,
       COUNT(DISTINCT fact_tipo+fact_numero+fact_sucursal),
       (SELECT TOP 1 fact_cliente
            FROM Factura
            JOIN Item_Factura
                ON item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
        WHERE YEAR(fact_fecha) = 2012 AND item_producto = prod_codigo
        GROUP BY fact_cliente
        ORDER BY SUM(item_cantidad) DESC, fact_cliente ASC)
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto
    JOIN Factura ON item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
WHERE YEAR(fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle
    HAVING SUM(item_cantidad * item_precio) > 0.15 * (SELECT SUM(item_cantidad * item_precio) / COUNT(DISTINCT item_producto)
                                                        FROM Factura JOIN Item_Factura ON item_tipo+item_sucursal+item_numero = 
                                                                                            fact_tipo+fact_sucursal+fact_numero
                                                        WHERE YEAR(fact_fecha) IN (2010, 2011)
                                                        GROUP BY item_producto
                                                     ) --no se pude usar avg en este caso
go;

--2. retornar las zonas que tengas 3 o mas depositos, detalle zona, cantidad depositos por zona,
-- cantidad de productos disitintos compuestos en sus depositos
-- producto mas vendido en el año 2012 que tenga stock en al manos 1 de sus depositos
-- el encargado que mas vendio en la historia perteneciente a esa zona
-- ordenado por monto total vendido del encargado descendiente (orden x facturacion del encargado q + vendio)
select zona_detalle, count(depo_codigo),
       (
            SELECT COUNT(DISTINCT stoc_producto)
                FROM STOCK 
                    JOIN Composicion ON comp_producto = stoc_producto
                    JOIN DEPOSITO ON depo_codigo = stoc_deposito
            WHERE stoc_cantidad > 0
                  AND depo_zona = zona_codigo
       ),
       (
            SELECT TOP 1 item_producto
            FROM Item_Factura
                JOIN Factura 
                    ON fact_tipo = item_tipo 
                    AND fact_sucursal = item_sucursal 
                    AND fact_numero = item_numero
            WHERE YEAR(fact_fecha) = 2012
                  AND item_producto IN (
                                          SELECT stoc_producto
                                          FROM STOCK
                                          JOIN DEPOSITO ON depo_codigo = stoc_deposito
                                          WHERE depo_zona = zona_codigo
                                            AND stoc_cantidad > 0
                                       )
            GROUP BY item_producto
            ORDER BY SUM(item_cantidad) DESC
       ),
       (
            SELECT TOP 1 fact_vendedor
            FROM Factura
            WHERE fact_vendedor IN (
                                        SELECT depo_encargado
                                        FROM DEPOSITO
                                        WHERE depo_zona = zona_codigo
                                   )
            GROUP BY fact_vendedor
            ORDER BY SUM(fact_total) DESC
       )
    from zona join DEPOSITO on zona_codigo = depo_zona
group by zona_codigo, zona_detalle
    having count(depo_codigo) >= 3
order by (
            SELECT TOP 1 SUM(fact_total)
            FROM Factura
            WHERE fact_vendedor IN (
                                        SELECT depo_encargado
                                        FROM DEPOSITO
                                        WHERE depo_zona = zona_codigo
                                   )
            GROUP BY fact_vendedor
            ORDER BY SUM(fact_total) DESC
         ) DESC;
go;

--3. mostrar los productos que tengan 3 componentes a nivel producto 
-- y cuyos componentes tengan 2 rubros distintos. Retornar:
-- codigo de producto, nombre del producto, 
-- la cantidad de veces que fueron vendidos sus componentes en 2012
-- monto total vendido del producto *supongo que en la historia*
-- ordenar por cantidad de facturas del 2012 en las cuales se vendieron los componentes
select p.prod_codigo, p.prod_detalle,
        (
            select count(*)
                FROM Factura JOIN Item_Factura
                    ON item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
            WHERE YEAR(fact_fecha) = 2012 AND item_producto in (SELECT comp_componente 
                                                                  FROM Composicion 
                                                                  WHERE comp_producto = p.prod_codigo)
        ),
        (
            select sum(isnull(item_cantidad * item_precio, 0))
                FROM Item_Factura
            WHERE item_producto = p.prod_codigo
        )
    from Producto p JOIN Composicion ON comp_producto = p.prod_codigo             -- doble join x esto: cuyos componentes tengan 2 rubros distintos
                  JOIN Producto p_comp ON p_comp.prod_codigo = comp_componente -- doble join ej: La tabla Empleado tiene la columna empl_jefe, que apunta al empl_codigo de otro empleado dentro de la misma tabla.
group by p.prod_codigo, p.prod_detalle
    having count(distinct comp_componente) = 3 and count(distinct p_comp.prod_rubro) = 2
ORDER BY (                                                                      -- las columnas q se pueden usar directamente son del from, no las del join, x eso select de nuevo
            SELECT COUNT(DISTINCT fact_tipo+fact_sucursal+fact_numero)
            FROM Item_Factura
            JOIN Factura
                ON item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
            WHERE YEAR(fact_fecha) = 2012
                  AND item_producto IN (
                                          SELECT comp_componente 
                                          FROM Composicion 
                                          WHERE comp_producto = p.prod_codigo
                                       )
         ) DESC;
go;

-- 4. clientes que compraron todos los rubros disponibles en el 2012
-- mostrar siempre para el 2012, codigo cliente, codigo y nombre de producto que en mas cantidad compro
-- cantidad de productos distintos comprados por el cliente
-- cantidad de productos con composicion comprados por el cliente
-- ordenar por razon social del cliente alfabeticamente primero, 
-- luego por los clientes que compraron entre un 20% y 30% del total facturado en 2012,
-- y luego los restantes
SELECT 
    c.clie_codigo AS Codigo_Cliente,
    (
        SELECT TOP 1 itf2.item_producto
        FROM Factura f2
        JOIN Item_Factura itf2 
            ON f2.fact_tipo = itf2.item_tipo 
            AND f2.fact_sucursal = itf2.item_sucursal 
            AND f2.fact_numero = itf2.item_numero
        WHERE f2.fact_cliente = c.clie_codigo
          AND YEAR(f2.fact_fecha) = 2012
        GROUP BY itf2.item_producto
        ORDER BY SUM(itf2.item_cantidad) DESC
    ) AS Codigo_Prod_Mas_Comprado,
    (
        SELECT TOP 1 p2.prod_detalle
        FROM Factura f2
        JOIN Item_Factura itf2 
            ON f2.fact_tipo = itf2.item_tipo 
            AND f2.fact_sucursal = itf2.item_sucursal 
            AND f2.fact_numero = itf2.item_numero
        JOIN Producto p2 ON p2.prod_codigo = itf2.item_producto
        WHERE f2.fact_cliente = c.clie_codigo
          AND YEAR(f2.fact_fecha) = 2012
        GROUP BY p2.prod_codigo, p2.prod_detalle
        ORDER BY SUM(itf2.item_cantidad) DESC
    ) AS Nombre_Prod_Mas_Comprado,
    COUNT(DISTINCT itf.item_producto) AS Cant_Productos_Distintos,
    COUNT(DISTINCT CASE 
        WHEN itf.item_producto IN (SELECT comp_producto FROM Composicion) 
        THEN itf.item_producto 
    END) AS Cant_Productos_Compuestos

FROM Cliente c
JOIN Factura f ON f.fact_cliente = c.clie_codigo
JOIN Item_Factura itf 
    ON f.fact_tipo = itf.item_tipo 
    AND f.fact_sucursal = itf.item_sucursal 
    AND f.fact_numero = itf.item_numero
JOIN Producto p ON p.prod_codigo = itf.item_producto
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY c.clie_codigo, c.clie_razon_social
    HAVING COUNT(DISTINCT p.prod_rubro) = (SELECT COUNT(*) FROM Rubro)
ORDER BY 
    c.clie_razon_social ASC,
    CASE 
        WHEN SUM(itf.item_cantidad * itf.item_precio) BETWEEN 
            0.20 * (SELECT SUM(fact_total) FROM Factura WHERE YEAR(fact_fecha) = 2012)
            AND 
            0.30 * (SELECT SUM(fact_total) FROM Factura WHERE YEAR(fact_fecha) = 2012)
        THEN 1
        ELSE 2
    END ASC;
go;

-- 5. consulta que permita saber si un cliente compro un producto en todos los meses del 2012
-- mostrar el cliente, razon social del cliente, el producto comprado, detalle del producto
-- cantidad de productos distintos comprados por el clientes
-- cantidad de productos con composicion comprados por el cliente
-- ordenar poniendo primero los clientes que compraron mas de 10 productos distintos en el 2012
SELECT 
    c.clie_codigo AS Codigo_Cliente,
    c.clie_razon_social AS Razon_Social,
    p.prod_codigo AS Codigo_Producto,
    p.prod_detalle AS Detalle_Producto,
    (
        SELECT COUNT(DISTINCT itf2.item_producto)
        FROM Factura f2
        JOIN Item_Factura itf2 
            ON f2.fact_tipo = itf2.item_tipo 
            AND f2.fact_sucursal = itf2.item_sucursal 
            AND f2.fact_numero = itf2.item_numero
        WHERE f2.fact_cliente = c.clie_codigo
          AND YEAR(f2.fact_fecha) = 2012
    ) AS Cant_Productos_Distintos_2012,
    (
        SELECT COUNT(DISTINCT itf3.item_producto)
        FROM Factura f3
        JOIN Item_Factura itf3 
            ON f3.fact_tipo = itf3.item_tipo 
            AND f3.fact_sucursal = itf3.item_sucursal 
            AND f3.fact_numero = itf3.item_numero
        WHERE f3.fact_cliente = c.clie_codigo
          AND YEAR(f3.fact_fecha) = 2012
          AND itf3.item_producto IN (SELECT comp_producto FROM Composicion)
    ) AS Cant_Productos_Compuestos_2012

FROM Cliente c
JOIN Factura f ON f.fact_cliente = c.clie_codigo
JOIN Item_Factura itf 
    ON f.fact_tipo = itf.item_tipo 
    AND f.fact_sucursal = itf.item_sucursal 
    AND f.fact_numero = itf.item_numero
JOIN Producto p ON p.prod_codigo = itf.item_producto
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY 
    c.clie_codigo, 
    c.clie_razon_social, 
    p.prod_codigo, 
    p.prod_detalle
    HAVING COUNT(DISTINCT MONTH(f.fact_fecha)) = 12
ORDER BY 
    CASE 
        WHEN (
            SELECT COUNT(DISTINCT itf4.item_producto)
            FROM Factura f4
            JOIN Item_Factura itf4 
                ON f4.fact_tipo = itf4.item_tipo 
                AND f4.fact_sucursal = itf4.item_sucursal 
                AND f4.fact_numero = itf4.item_numero
            WHERE f4.fact_cliente = c.clie_codigo
              AND YEAR(f4.fact_fecha) = 2012
        ) > 10 THEN 1
        ELSE 2
    END ASC,
    c.clie_codigo ASC;
go;

-- 6. retornar los 10 clientes que mas compraron en el 2012 y que fueron atendidos por 
-- mas de 3 vendedores distintos. Mostrar:
-- apellido y nombre del cliente,
-- cantidad de productos distintos comprados en el 2012,
-- cantidad de unidades compradas dentro del primer semestre del 2012
-- ordenar por cantidad de ventas descendente del 2012 de cada cliente,
-- en caso de igualdad ordenar por codigo cliente
SELECT TOP 10
    c.clie_razon_social AS Cliente,
    COUNT(DISTINCT itf.item_producto) AS Cant_Productos_Distintos_2012,
    SUM(
        CASE 
            WHEN MONTH(f.fact_fecha) BETWEEN 1 AND 6 THEN itf.item_cantidad 
            ELSE 0 
        END
    ) AS Unidades_Primer_Semestre_2012
FROM Cliente c
JOIN Factura f ON f.fact_cliente = c.clie_codigo
JOIN Item_Factura itf 
    ON f.fact_tipo = itf.item_tipo 
    AND f.fact_sucursal = itf.item_sucursal 
    AND f.fact_numero = itf.item_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY c.clie_codigo, c.clie_razon_social
HAVING COUNT(DISTINCT f.fact_vendedor) > 3
ORDER BY 
    SUM(itf.item_cantidad * itf.item_precio) DESC,
    c.clie_codigo ASC;
go;

-- 7. mostrar: deposito, domicilio del deposito, cantidad de productos compuestos con stock,
-- cantidad de productos no compuestos con stock, indicar "mayoria compuestos" en caso
-- de que el deposito tenga mayor cantidad de productos compuestos sino "mayoria no compuestos"
-- empleado mas joven del deposito
-- solo mostrar los depositos donde la cantidad total de productos en stock esta entre 0 y 1000
SELECT 
    d.depo_codigo AS Deposito,
    d.depo_domicilio AS Domicilio,
    COUNT(DISTINCT CASE 
        WHEN s.stoc_cantidad > 0 
             AND s.stoc_producto IN (SELECT comp_producto FROM Composicion) 
        THEN s.stoc_producto 
    END) AS Cant_Compuestos_Con_Stock,
    COUNT(DISTINCT CASE 
        WHEN s.stoc_cantidad > 0 
             AND s.stoc_producto NOT IN (SELECT comp_producto FROM Composicion) 
        THEN s.stoc_producto 
    END) AS Cant_No_Compuestos_Con_Stock,
    CASE 
        WHEN COUNT(DISTINCT CASE 
                WHEN s.stoc_cantidad > 0 
                     AND s.stoc_producto IN (SELECT comp_producto FROM Composicion) 
                THEN s.stoc_producto 
             END) 
             > 
             COUNT(DISTINCT CASE 
                WHEN s.stoc_cantidad > 0 
                     AND s.stoc_producto NOT IN (SELECT comp_producto FROM Composicion) 
                THEN s.stoc_producto 
             END) 
        THEN 'mayoria compuestos'
        ELSE 'mayoria no compuestos'
    END AS Tipo_Mayoria,
    (
        SELECT TOP 1 RTRIM(e.empl_nombre) + ' ' + RTRIM(e.empl_apellido)
        FROM Empleado e
        JOIN Departamento dep ON dep.depa_codigo = e.empl_departamento
        WHERE dep.depa_zona = d.depo_zona
        ORDER BY e.empl_nacimiento DESC
    ) AS Empleado_Mas_Joven

FROM DEPOSITO d
LEFT JOIN STOCK s ON s.stoc_deposito = d.depo_codigo
GROUP BY d.depo_codigo, d.depo_domicilio, d.depo_zona
    HAVING ISNULL(SUM(s.stoc_cantidad), 0) BETWEEN 0 AND 1000;
go;

-- 8. si un producto no es vendido en un deposito determinado, no se poseen registros de el.
-- Para los productos que se quedaron sin stock en un deposito (0 o null) y poseen en stock
-- mayor al punto de reposicion en otro deposito, retornar:
-- codigo y detalle del producto,
-- domicilio del deposito sin stock
-- cantidad de depositos con un stock superior al punto de reposicion
-- ordenar por codigo de producto
SELECT 
    p.prod_codigo AS Codigo_Producto,
    p.prod_detalle AS Detalle_Producto,
    d.depo_domicilio AS Domicilio_Deposito_Sin_Stock,
    (
        SELECT COUNT(*)
        FROM STOCK s2
        WHERE s2.stoc_producto = p.prod_codigo
          AND s2.stoc_cantidad > s2.stoc_punto_reposicion
    ) AS Cant_Depositos_Sobre_Punto_Reposicion
FROM Producto p
CROSS JOIN DEPOSITO d --combina cada fila de la primera tabla con todas las filas de la segunda tabla
LEFT JOIN STOCK s 
    ON s.stoc_producto = p.prod_codigo 
    AND s.stoc_deposito = d.depo_codigo
WHERE ISNULL(s.stoc_cantidad, 0) <= 0
  AND (
      SELECT COUNT(*)
      FROM STOCK s2
      WHERE s2.stoc_producto = p.prod_codigo
        AND s2.stoc_cantidad > s2.stoc_punto_reposicion
  ) > 0
ORDER BY p.prod_codigo ASC;
go;

-- 9. mostrar los 5 productos mas vendidos y los 5 menos vendidos durante el 2012.
-- comparar la cantidad vendida de cada uno con la cantidad vendida del año amterior
-- e indicar "mas ventas" o "menos ventas" segun corresponda. Indicar:
-- el envase, producto, comparacion año anterior, detalle de envase
-- Si un producto no tuvo ventas en el año, debe considerarse como producto menos vendido.
-- Si son mas de 5, mostrar los primeros 5 en orden alfabetico
SELECT 
    e.enva_codigo AS Envase,
    p.prod_detalle AS Producto,
    CASE 
        WHEN ISNULL((
            SELECT SUM(itf_12.item_cantidad)
            FROM Item_Factura itf_12
            JOIN Factura f_12 
                ON f_12.fact_tipo = itf_12.item_tipo 
                AND f_12.fact_sucursal = itf_12.item_sucursal 
                AND f_12.fact_numero = itf_12.item_numero
            WHERE itf_12.item_producto = p.prod_codigo
              AND YEAR(f_12.fact_fecha) = 2012
        ), 0)
        >
        ISNULL((
            SELECT SUM(itf_11.item_cantidad)
            FROM Item_Factura itf_11
            JOIN Factura f_11 
                ON f_11.fact_tipo = itf_11.item_tipo 
                AND f_11.fact_sucursal = itf_11.item_sucursal 
                AND f_11.fact_numero = itf_11.item_numero
            WHERE itf_11.item_producto = p.prod_codigo
              AND YEAR(f_11.fact_fecha) = 2011
        ), 0) THEN 'mas ventas'
        ELSE 'menos ventas'
    END AS Comparacion_Anio_Anterior,
    e.enva_detalle AS Detalle_Envase
FROM Producto p
LEFT JOIN Envases e ON e.enva_codigo = p.prod_envase
WHERE 
    -- Top 5 más vendidos en 2012
    p.prod_codigo IN (
        SELECT TOP 5 itf.item_producto
        FROM Item_Factura itf
        JOIN Factura f 
            ON f.fact_tipo = itf.item_tipo 
            AND f.fact_sucursal = itf.item_sucursal 
            AND f.fact_numero = itf.item_numero
        WHERE YEAR(f.fact_fecha) = 2012
        GROUP BY itf.item_producto
        ORDER BY SUM(itf.item_cantidad) DESC
    )
    OR 
    -- Top 5 menos vendidos en 2012
    p.prod_codigo IN (
        SELECT TOP 5 p2.prod_codigo
        FROM Producto p2
        LEFT JOIN (
            Item_Factura itf2
            JOIN Factura f2 
                ON f2.fact_tipo = itf2.item_tipo 
                AND f2.fact_sucursal = itf2.item_sucursal 
                AND f2.fact_numero = itf2.item_numero
                AND YEAR(f2.fact_fecha) = 2012
        ) ON itf2.item_producto = p2.prod_codigo
        GROUP BY p2.prod_codigo, p2.prod_detalle
        ORDER BY ISNULL(SUM(itf2.item_cantidad), 0) ASC, p2.prod_detalle ASC
    );
go;

-- 10. 
Se pide una consulta que retorne:
1. Código del Vendedor
2. Código de Familia de producto que más se facturó para ese vendedor. 3. Cantidad de envases de productos diferentes facturados de esa familia
4. Cantidad total de productos vendidos para esa familia y ese vendedor.
Solo se deberán considerar aquellos vendedores que tengan más del 50% de su cartera de clientes sin compras durante el último año.
Se deberá mostrar la información ordenada por cantidad de clientes de cada vendedor.
No se permite el uso de funciones de TSQL ni selects en el FROM.
TSQL
Crear el/los objetos de bases de datos para que, ante una operación de venta, verifique que haya suficiente stock de cada producto para concretar la operación.
En caso de haber stock para realizar la operación, debe mostrar el siguiente mensaje luego de concretar la venta:
"Factura XXXX-XXXXXXX procesada correctamente"
Si la operación no se puede realizar por stock insuficiente, debe mostrar el siguiente mensaje con las unidades de los productos que faltan para concretar la operación.
"La factura XXXX-XXXXXXX no se puede emitir"
"No se puede vender el producto XXXXXXXXX, Stock faltante: #####"
"No se puede vender el producto XXXXXXXXX, Stock faltante: #####"
"No se puede vender el producto XXXXXXXXX, Stock faltante: #####"
No deben quedar facturas incompletas



--TSQL

-- 1. realizar los objetos necesarios para que se imprima un cupon con la leyenda 
-- "ud. accederá a un 5% de descuento del total de su proxima factura" a los clientes que realicen 
-- compras superiores a $5000 y que entre los productos comprados haya adquirido algun producto 
-- de los rubros: pilas, pastillas o articulos de tocado
CREATE TRIGGER cupon_descuento
ON Item_Factura
AFTER INSERT
AS
BEGIN
    DECLARE @TIPO CHAR(1), @SUCURSAL CHAR(4), @NUMERO CHAR(8);

    DECLARE c1 CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT f.fact_tipo, f.fact_sucursal, f.fact_numero
        FROM inserted i
        JOIN Factura f 
            ON f.fact_tipo = i.item_tipo 
            AND f.fact_sucursal = i.item_sucursal 
            AND f.fact_numero = i.item_numero
        JOIN Item_Factura itf 
            ON itf.item_tipo = f.fact_tipo 
            AND itf.item_sucursal = f.fact_sucursal 
            AND itf.item_numero = f.fact_numero
        JOIN Producto p 
            ON p.prod_codigo = itf.item_producto
        JOIN Rubro r 
            ON r.rubr_id = p.prod_rubro
        WHERE f.fact_total > 5000
              AND RTRIM(r.rubr_detalle) IN ('PILAS', 'PASTILLAS', 'ARTICULOS DE TOCADOR');

    OPEN c1;
    FETCH NEXT FROM c1 INTO @TIPO, @SUCURSAL, @NUMERO;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT 'UD. accedera a un 5% de descuento del total de su proxima factura';
        
        FETCH NEXT FROM c1 INTO @TIPO, @SUCURSAL, @NUMERO;
    END;

    CLOSE c1;
    DEALLOCATE c1;
END;
GO

-- 2. actualmente el campo fact_vendedor representa al empleado que vendio la factura. 
-- Implementar los objetos necesarios para respetar la integridad referencial de dicho campo 
-- suponiendo que no existe una foreign key entre ambos. No se puede usar foreign key
CREATE TRIGGER FACTURA_VENDEDOR
ON Factura
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        WHERE i.fact_vendedor IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 
              FROM Empleado e 
              WHERE e.empl_codigo = i.fact_vendedor
          )
    )
    BEGIN
        RAISERROR('Error de integridad referencial: El vendedor asignado no existe en la tabla Empleado.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO
CREATE TRIGGER EMPLEADO_FACTURA
ON Empleado
AFTER DELETE, UPDATE
AS
BEGIN
    IF UPDATE(empl_codigo) OR NOT EXISTS (SELECT 1 FROM inserted)
    BEGIN
        IF EXISTS (
            SELECT 1 
            FROM deleted d
            JOIN Factura f ON f.fact_vendedor = d.empl_codigo
        )
        BEGIN
            RAISERROR('Error de integridad referencial: No se puede eliminar o modificar el código de un empleado con facturas asociadas.', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO

-- 3. implementar en regla de negocio en linea donde se valide que un producto compuesto
-- no pueda estar compuesto por componentes de rubros distintos a el
CREATE TRIGGER VALIDAR_RUBRO_COMPOSICION
ON Composicion
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Producto p_padre ON p_padre.prod_codigo = i.comp_producto
        JOIN Producto p_comp  ON p_comp.prod_codigo  = i.comp_componente
        WHERE ISNULL(p_padre.prod_rubro, '') <> ISNULL(p_comp.prod_rubro, '')
    )
    BEGIN
        RAISERROR('Regla de negocio violada: Un producto compuesto solo puede contener componentes de su mismo rubro.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO
CREATE TRIGGER TR_VALIDAR_RUBRO_PRODUCTO
ON Producto
AFTER UPDATE
AS
BEGIN
    IF UPDATE(prod_rubro)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM Composicion c
            JOIN Producto p_padre ON p_padre.prod_codigo = c.comp_producto
            JOIN Producto p_comp  ON p_comp.prod_codigo  = c.comp_componente
            WHERE (c.comp_producto IN (SELECT prod_codigo FROM inserted) 
                OR c.comp_componente IN (SELECT prod_codigo FROM inserted))
              AND ISNULL(p_padre.prod_rubro, '') <> ISNULL(p_comp.prod_rubro, '')
        )
        BEGIN
            RAISERROR('Regla de negocio violada: No se puede cambiar el rubro porque genera incompatibilidad en una composición existente.', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO

-- 4. Implementar una regla de negocio en línea que al realizar una venta (SOLO INSERCION) permita 
-- componer los productos descompuestos, es decir, si se guardan en la factura 2 hamb, 2 papas y 2 gaseosas 
-- se deberá guardar en la factura 2 (DOS) COMBO1. Si 1 combo1 equivale a: 1 hamb, 1 papa y 1 gaseosa.
-- Considerar que cada vez que se guardan los items, se mandan todos los productos de ese item a la vez, 
-- y no de manera parcial.
CREATE TRIGGER COMPONER_PRODUCTOS_VENTA
ON Item_Factura
AFTER INSERT
AS
BEGIN
    DECLARE @tipo CHAR(1), @sucursal CHAR(4), @numero CHAR(8);
    DECLARE @combo CHAR(8), @cant_combos DECIMAL(12,2), @precio_combo DECIMAL(12,2);

    DECLARE c_facturas CURSOR FOR
        SELECT DISTINCT item_tipo, item_sucursal, item_numero
        FROM inserted;

    OPEN c_facturas;
    FETCH NEXT FROM c_facturas INTO @tipo, @sucursal, @numero;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE c_combos CURSOR FOR
            SELECT 
                c.comp_producto,
                MIN(FLOOR(itf.item_cantidad / c.comp_cantidad)) AS combos_posibles,
                p.prod_precio
            FROM Composicion c
            JOIN Producto p ON p.prod_codigo = c.comp_producto
            JOIN Item_Factura itf 
                ON itf.item_producto = c.comp_componente
                AND itf.item_tipo = @tipo
                AND itf.item_sucursal = @sucursal
                AND itf.item_numero = @numero
            WHERE itf.item_cantidad >= c.comp_cantidad
            GROUP BY c.comp_producto, p.prod_precio
            HAVING COUNT(DISTINCT c.comp_componente) = (
                SELECT COUNT(*) 
                FROM Composicion c2 
                WHERE c2.comp_producto = c.comp_producto
            )
            ORDER BY p.prod_precio DESC;

        OPEN c_combos;
        FETCH NEXT FROM c_combos INTO @combo, @cant_combos, @precio_combo;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @cant_combos = MIN(FLOOR(itf.item_cantidad / c.comp_cantidad))
            FROM Composicion c
            JOIN Item_Factura itf 
                ON itf.item_producto = c.comp_componente
                AND itf.item_tipo = @tipo
                AND itf.item_sucursal = @sucursal
                AND itf.item_numero = @numero
            WHERE c.comp_producto = @combo;

            IF @cant_combos >= 1
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM Item_Factura 
                    WHERE item_tipo = @tipo AND item_sucursal = @sucursal 
                      AND item_numero = @numero AND item_producto = @combo
                )
                BEGIN
                    UPDATE Item_Factura
                    SET item_cantidad = item_cantidad + @cant_combos
                    WHERE item_tipo = @tipo AND item_sucursal = @sucursal 
                      AND item_numero = @numero AND item_producto = @combo;
                END
                ELSE
                BEGIN
                    INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
                    VALUES (@tipo, @sucursal, @numero, @combo, @cant_combos, @precio_combo);
                END

                UPDATE itf
                SET itf.item_cantidad = itf.item_cantidad - (@cant_combos * c.comp_cantidad)
                FROM Item_Factura itf
                JOIN Composicion c ON itf.item_producto = c.comp_componente
                WHERE c.comp_producto = @combo
                  AND itf.item_tipo = @tipo
                  AND itf.item_sucursal = @sucursal
                  AND itf.item_numero = @numero;

                DELETE FROM Item_Factura
                WHERE item_tipo = @tipo
                  AND item_sucursal = @sucursal
                  AND item_numero = @numero
                  AND item_cantidad <= 0;
            END

            FETCH NEXT FROM c_combos INTO @combo, @cant_combos, @precio_combo;
        END

        CLOSE c_combos;
        DEALLOCATE c_combos;

        FETCH NEXT FROM c_facturas INTO @tipo, @sucursal, @numero;
    END

    CLOSE c_facturas;
    DEALLOCATE c_facturas;
END;
GO

-- 5. Implementar una regla de negocio de validación en linea que permita implementar 
-- una lógica de control de precios en las ventas. Se deberá poder seleccionar una lista de 
-- rubros y aquellos productos de los rubros que sean los seleccionados no podrán aumentar 
-- por mes más de un 2 %. En caso que no se tenga referencia del mes anterior no validar dicha regla.
CREATE TABLE Rubros_Controlados (
    rubr_id CHAR(4) PRIMARY KEY,
    FOREIGN KEY (rubr_id) REFERENCES Rubro(rubr_id)
);
GO

CREATE TRIGGER CONTROL_PRECIO_RUBROS
ON Item_Factura
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Factura f 
            ON f.fact_tipo = i.item_tipo 
            AND f.fact_sucursal = i.item_sucursal 
            AND f.fact_numero = i.item_numero
        JOIN Producto p 
            ON p.prod_codigo = i.item_producto
        JOIN Rubros_Controlados rc 
            ON rc.rubr_id = p.prod_rubro
        WHERE i.item_precio > (
            SELECT MAX(itf_ant.item_precio) * 1.02
            FROM Item_Factura itf_ant
            JOIN Factura f_ant 
                ON f_ant.fact_tipo = itf_ant.item_tipo 
                AND f_ant.fact_sucursal = itf_ant.item_sucursal 
                AND f_ant.fact_numero = itf_ant.item_numero
            WHERE itf_ant.item_producto = i.item_producto
              AND YEAR(f_ant.fact_fecha) = YEAR(DATEADD(MONTH, -1, f.fact_fecha))
              AND MONTH(f_ant.fact_fecha) = MONTH(DATEADD(MONTH, -1, f.fact_fecha))
        )
    )
    BEGIN
        RAISERROR('Regla de negocio violada: El precio del producto supera el aumento máximo permitido del 2% respecto al mes anterior.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 6. Realizar un stored procedure que recba un código de producto y una fecha, 
-- y devuelva la mayor cantidad de dias consecutivos a partir de esa fecha si el producto tuvo 
-- al menos la venta de una unidad en el dia. El sistema de ventas on line está habilitado 24-7 
-- por lo que se deben evaluar todos los dias incluyendo domingos y feriados.
CREATE PROCEDURE SP_MAX_DIAS_CONSECUTIVOS_PRODUCTO
    @prod_codigo CHAR(8),
    @fecha_desde SMALLDATETIME,
    @max_dias INT OUTPUT
AS
BEGIN
    DECLARE @fecha_venta DATE;
    DECLARE @fecha_anterior DATE = NULL;
    DECLARE @racha_actual INT = 0;
    
    SET @max_dias = 0;

    DECLARE c_fechas CURSOR FOR
        SELECT DISTINCT CAST(f.fact_fecha AS DATE) AS dia_venta
        FROM Factura f
        JOIN Item_Factura itf 
            ON itf.item_tipo = f.fact_tipo 
            AND itf.item_sucursal = f.fact_sucursal 
            AND itf.item_numero = f.fact_numero
        WHERE itf.item_producto = @prod_codigo
          AND itf.item_cantidad >= 1
          AND CAST(f.fact_fecha AS DATE) >= CAST(@fecha_desde AS DATE)
        ORDER BY dia_venta ASC;

    OPEN c_fechas;
    FETCH NEXT FROM c_fechas INTO @fecha_venta;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @fecha_anterior IS NULL
        BEGIN
            SET @racha_actual = 1;
        END
        ELSE IF DATEDIFF(DAY, @fecha_anterior, @fecha_venta) = 1
        BEGIN
            SET @racha_actual = @racha_actual + 1;
        END
        ELSE
        BEGIN
            SET @racha_actual = 1;
        END

        IF @racha_actual > @max_dias
        BEGIN
            SET @max_dias = @racha_actual;
        END

        SET @fecha_anterior = @fecha_venta;
        FETCH NEXT FROM c_fechas INTO @fecha_venta;
    END

    CLOSE c_fechas;
    DEALLOCATE c_fechas;

    SELECT @max_dias AS Max_Dias_Consecutivos;
END;
GO

-- 7. Dado el contexto inflacionario se tiene que aplicar un control en el cual nunca 
-- se permita vender un producto a un precio que no esté entre 0%-5% del precio de venta 
-- del producto el mes anterior, ni tampoco que esté en más de un 50% el precio del mismo producto 
-- que hace 12 meses atrás. Aquellos productos nuevos, o que no tuvieron ventas en meses anteriores 
-- no debe considerar esta regla ya que no hay precio de referencia.

CREATE TRIGGER CONTROL_INFLACIONARIO_VENTAS
ON Item_Factura
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Factura f 
            ON f.fact_tipo = i.item_tipo 
            AND f.fact_sucursal = i.item_sucursal 
            AND f.fact_numero = i.item_numero
        WHERE 
            i.item_precio < (
                SELECT MAX(itf_m.item_precio)
                FROM Item_Factura itf_m
                JOIN Factura f_m 
                    ON f_m.fact_tipo = itf_m.item_tipo 
                    AND f_m.fact_sucursal = itf_m.item_sucursal 
                    AND f_m.fact_numero = itf_m.item_numero
                WHERE itf_m.item_producto = i.item_producto
                  AND YEAR(f_m.fact_fecha) = YEAR(DATEADD(MONTH, -1, f.fact_fecha))
                  AND MONTH(f_m.fact_fecha) = MONTH(DATEADD(MONTH, -1, f.fact_fecha))
            )
            OR 
            i.item_precio > (
                SELECT MAX(itf_m.item_precio) * 1.05
                FROM Item_Factura itf_m
                JOIN Factura f_m 
                    ON f_m.fact_tipo = itf_m.item_tipo 
                    AND f_m.fact_sucursal = itf_m.item_sucursal 
                    AND f_m.fact_numero = itf_m.item_numero
                WHERE itf_m.item_producto = i.item_producto
                  AND YEAR(f_m.fact_fecha) = YEAR(DATEADD(MONTH, -1, f.fact_fecha))
                  AND MONTH(f_m.fact_fecha) = MONTH(DATEADD(MONTH, -1, f.fact_fecha))
            )
            OR
            i.item_precio > (
                SELECT MAX(itf_a.item_precio) * 1.50
                FROM Item_Factura itf_a
                JOIN Factura f_a 
                    ON f_a.fact_tipo = itf_a.item_tipo 
                    AND f_a.fact_sucursal = itf_a.item_sucursal 
                    AND f_a.fact_numero = itf_a.item_numero
                WHERE itf_a.item_producto = i.item_producto
                  AND YEAR(f_a.fact_fecha) = YEAR(DATEADD(MONTH, -12, f.fact_fecha))
                  AND MONTH(f_a.fact_fecha) = MONTH(DATEADD(MONTH, -12, f.fact_fecha))
            )
    )
    BEGIN
        RAISERROR('Regla de negocio violada: El precio de venta no respeta los límites inflacionarios (0%-5% mensual o máx. +50% interanual).', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 8. Se pide crear el/los objetos necesarios para que se imprima un cupón con la leyenda
-- "Recuerde solicitar su regalo sorpresa en su próxima compra" a los clientes que, 
-- entre los productos comprados, hayan adquirido algún producto de los siguientes 
-- rubros: PILAS Y PASTILLAS y tengan un limite crediticio menor a $ 15000.
CREATE TRIGGER CUPON_REGALO_SORPRESA
ON Item_Factura
AFTER INSERT
AS
BEGIN
    DECLARE @TIPO CHAR(1), @SUCURSAL CHAR(4), @NUMERO CHAR(8);

    -- Iteramos por cada comprobante (factura) distinto afectado en este INSERT
    DECLARE c_facturas CURSOR FOR
        SELECT DISTINCT item_tipo, item_sucursal, item_numero
        FROM inserted;

    OPEN c_facturas;
    FETCH NEXT FROM c_facturas INTO @TIPO, @SUCURSAL, @NUMERO;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Verificamos si el cliente de la factura tiene límite < 15000 
        -- y si la factura contiene algún producto de los rubros PILAS o PASTILLAS
        IF EXISTS (
            SELECT 1
            FROM Factura f
            JOIN Cliente c 
                ON c.clie_codigo = f.fact_cliente
            JOIN Item_Factura itf 
                ON itf.item_tipo = f.fact_tipo 
                AND itf.item_sucursal = f.fact_sucursal 
                AND itf.item_numero = f.fact_numero
            JOIN Producto p 
                ON p.prod_codigo = itf.item_producto
            JOIN Rubro r 
                ON r.rubr_id = p.prod_rubro
            WHERE f.fact_tipo = @TIPO
              AND f.fact_sucursal = @SUCURSAL
              AND f.fact_numero = @NUMERO
              AND c.clie_limite_credito < 15000
              AND RTRIM(r.rubr_detalle) IN ('PILAS', 'PASTILLAS')
        )
        BEGIN
            PRINT 'Recuerde solicitar su regalo sorpresa en su próxima compra';
        END

        FETCH NEXT FROM c_facturas INTO @TIPO, @SUCURSAL, @NUMERO;
    END

    CLOSE c_facturas;
    DEALLOCATE c_facturas;
END;
GO
