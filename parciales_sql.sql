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
-- ordenado por monto total vendido del encargado descendiente
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
                JOIN STOCK on item_producto = stoc_producto
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
