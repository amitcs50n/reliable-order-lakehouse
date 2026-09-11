USE [ReliableOrders];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF SCHEMA_ID(N'app') IS NULL
        EXEC(N'CREATE SCHEMA app AUTHORIZATION dbo;');

    IF OBJECT_ID(N'app.customers', N'U') IS NULL
    BEGIN
        CREATE TABLE app.customers
        (
            customer_id      BIGINT IDENTITY(1, 1) NOT NULL,
            customer_number  VARCHAR(32) NOT NULL,
            email            VARCHAR(320) NOT NULL,
            first_name       NVARCHAR(100) NOT NULL,
            last_name        NVARCHAR(100) NOT NULL,
            customer_status  VARCHAR(20) NOT NULL
                CONSTRAINT DF_app_customers_customer_status DEFAULT ('ACTIVE'),
            created_at       DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_customers_created_at DEFAULT (SYSUTCDATETIME()),
            updated_at       DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_customers_updated_at DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_app_customers PRIMARY KEY CLUSTERED (customer_id),
            CONSTRAINT UQ_app_customers_customer_number UNIQUE (customer_number),
            CONSTRAINT UQ_app_customers_email UNIQUE (email),
            CONSTRAINT CK_app_customers_status
                CHECK (customer_status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
            CONSTRAINT CK_app_customers_timestamps
                CHECK (updated_at >= created_at)
        );
    END;

    IF OBJECT_ID(N'app.products', N'U') IS NULL
    BEGIN
        CREATE TABLE app.products
        (
            product_id      BIGINT IDENTITY(1, 1) NOT NULL,
            sku             VARCHAR(64) NOT NULL,
            product_name    NVARCHAR(200) NOT NULL,
            category_name   NVARCHAR(100) NULL,
            unit_price      DECIMAL(19, 4) NOT NULL,
            is_active       BIT NOT NULL
                CONSTRAINT DF_app_products_is_active DEFAULT (1),
            created_at      DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_products_created_at DEFAULT (SYSUTCDATETIME()),
            updated_at      DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_products_updated_at DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_app_products PRIMARY KEY CLUSTERED (product_id),
            CONSTRAINT UQ_app_products_sku UNIQUE (sku),
            CONSTRAINT CK_app_products_unit_price CHECK (unit_price >= 0),
            CONSTRAINT CK_app_products_timestamps CHECK (updated_at >= created_at)
        );
    END;

    IF OBJECT_ID(N'app.warehouses', N'U') IS NULL
    BEGIN
        CREATE TABLE app.warehouses
        (
            warehouse_id    BIGINT IDENTITY(1, 1) NOT NULL,
            warehouse_code  VARCHAR(32) NOT NULL,
            warehouse_name  NVARCHAR(200) NOT NULL,
            city            NVARCHAR(100) NOT NULL,
            region_code     VARCHAR(32) NULL,
            country_code    CHAR(2) NOT NULL,
            is_active       BIT NOT NULL
                CONSTRAINT DF_app_warehouses_is_active DEFAULT (1),
            created_at      DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_warehouses_created_at DEFAULT (SYSUTCDATETIME()),
            updated_at      DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_warehouses_updated_at DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_app_warehouses PRIMARY KEY CLUSTERED (warehouse_id),
            CONSTRAINT UQ_app_warehouses_warehouse_code UNIQUE (warehouse_code),
            CONSTRAINT CK_app_warehouses_country_code CHECK (LEN(country_code) = 2),
            CONSTRAINT CK_app_warehouses_timestamps CHECK (updated_at >= created_at)
        );
    END;

    IF OBJECT_ID(N'app.inventory', N'U') IS NULL
    BEGIN
        CREATE TABLE app.inventory
        (
            product_id        BIGINT NOT NULL,
            warehouse_id      BIGINT NOT NULL,
            on_hand_quantity  INT NOT NULL
                CONSTRAINT DF_app_inventory_on_hand DEFAULT (0),
            reserved_quantity INT NOT NULL
                CONSTRAINT DF_app_inventory_reserved DEFAULT (0),
            reorder_level     INT NOT NULL
                CONSTRAINT DF_app_inventory_reorder_level DEFAULT (0),
            updated_at        DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_inventory_updated_at DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_app_inventory PRIMARY KEY CLUSTERED (product_id, warehouse_id),
            CONSTRAINT FK_app_inventory_product FOREIGN KEY (product_id)
                REFERENCES app.products (product_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_app_inventory_warehouse FOREIGN KEY (warehouse_id)
                REFERENCES app.warehouses (warehouse_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT CK_app_inventory_on_hand CHECK (on_hand_quantity >= 0),
            CONSTRAINT CK_app_inventory_reserved
                CHECK (reserved_quantity >= 0 AND reserved_quantity <= on_hand_quantity),
            CONSTRAINT CK_app_inventory_reorder_level CHECK (reorder_level >= 0)
        );
    END;

    IF OBJECT_ID(N'app.orders', N'U') IS NULL
    BEGIN
        CREATE TABLE app.orders
        (
            order_id       BIGINT IDENTITY(1, 1) NOT NULL,
            order_number   VARCHAR(40) NOT NULL,
            customer_id    BIGINT NOT NULL,
            order_status   VARCHAR(24) NOT NULL
                CONSTRAINT DF_app_orders_order_status DEFAULT ('PENDING'),
            currency_code  CHAR(3) NOT NULL,
            order_total    DECIMAL(19, 4) NOT NULL
                CONSTRAINT DF_app_orders_order_total DEFAULT (0),
            created_at     DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_orders_created_at DEFAULT (SYSUTCDATETIME()),
            updated_at     DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_orders_updated_at DEFAULT (SYSUTCDATETIME()),
            cancelled_at   DATETIME2(3) NULL,

            CONSTRAINT PK_app_orders PRIMARY KEY CLUSTERED (order_id),
            CONSTRAINT UQ_app_orders_order_number UNIQUE (order_number),
            CONSTRAINT FK_app_orders_customer FOREIGN KEY (customer_id)
                REFERENCES app.customers (customer_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT CK_app_orders_status CHECK
            (
                order_status IN
                (
                    'PENDING', 'PAYMENT_PENDING', 'PAID', 'PROCESSING',
                    'SHIPPED', 'DELIVERED', 'CANCELLED'
                )
            ),
            CONSTRAINT CK_app_orders_currency_code CHECK (LEN(currency_code) = 3),
            CONSTRAINT CK_app_orders_order_total CHECK (order_total >= 0),
            CONSTRAINT CK_app_orders_timestamps CHECK
                (updated_at >= created_at AND (cancelled_at IS NULL OR cancelled_at >= created_at)),
            CONSTRAINT CK_app_orders_cancelled_at CHECK
                (order_status <> 'CANCELLED' OR cancelled_at IS NOT NULL)
        );
    END;

    IF OBJECT_ID(N'app.order_items', N'U') IS NULL
    BEGIN
        CREATE TABLE app.order_items
        (
            order_item_id  BIGINT IDENTITY(1, 1) NOT NULL,
            order_id       BIGINT NOT NULL,
            product_id     BIGINT NOT NULL,
            quantity       INT NOT NULL,
            unit_price     DECIMAL(19, 4) NOT NULL,
            line_total     AS
                (CONVERT(DECIMAL(19, 4), CONVERT(DECIMAL(19, 4), quantity) * unit_price)) PERSISTED,
            created_at     DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_order_items_created_at DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_app_order_items PRIMARY KEY CLUSTERED (order_item_id),
            CONSTRAINT UQ_app_order_items_order_product UNIQUE (order_id, product_id),
            CONSTRAINT FK_app_order_items_order FOREIGN KEY (order_id)
                REFERENCES app.orders (order_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_app_order_items_product FOREIGN KEY (product_id)
                REFERENCES app.products (product_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT CK_app_order_items_quantity CHECK (quantity > 0),
            CONSTRAINT CK_app_order_items_unit_price CHECK (unit_price >= 0)
        );
    END;

    IF OBJECT_ID(N'app.payments', N'U') IS NULL
    BEGIN
        CREATE TABLE app.payments
        (
            payment_id         BIGINT IDENTITY(1, 1) NOT NULL,
            payment_reference  VARCHAR(64) NOT NULL,
            order_id           BIGINT NOT NULL,
            payment_method     VARCHAR(24) NOT NULL,
            payment_status     VARCHAR(24) NOT NULL
                CONSTRAINT DF_app_payments_payment_status DEFAULT ('PENDING'),
            currency_code      CHAR(3) NOT NULL,
            amount             DECIMAL(19, 4) NOT NULL,
            processed_at       DATETIME2(3) NULL,
            created_at         DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_payments_created_at DEFAULT (SYSUTCDATETIME()),
            updated_at         DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_payments_updated_at DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_app_payments PRIMARY KEY CLUSTERED (payment_id),
            CONSTRAINT UQ_app_payments_payment_reference UNIQUE (payment_reference),
            CONSTRAINT FK_app_payments_order FOREIGN KEY (order_id)
                REFERENCES app.orders (order_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT CK_app_payments_method CHECK
                (payment_method IN ('CARD', 'BANK_TRANSFER', 'WALLET', 'CASH_ON_DELIVERY')),
            CONSTRAINT CK_app_payments_status CHECK
                (payment_status IN ('PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUNDED')),
            CONSTRAINT CK_app_payments_currency_code CHECK (LEN(currency_code) = 3),
            CONSTRAINT CK_app_payments_amount CHECK (amount > 0),
            CONSTRAINT CK_app_payments_timestamps CHECK
            (
                updated_at >= created_at
                AND (processed_at IS NULL OR processed_at >= created_at)
            )
        );
    END;

    IF OBJECT_ID(N'app.shipments', N'U') IS NULL
    BEGIN
        CREATE TABLE app.shipments
        (
            shipment_id      BIGINT IDENTITY(1, 1) NOT NULL,
            shipment_number  VARCHAR(64) NOT NULL,
            order_id         BIGINT NOT NULL,
            warehouse_id     BIGINT NOT NULL,
            shipment_status  VARCHAR(24) NOT NULL
                CONSTRAINT DF_app_shipments_shipment_status DEFAULT ('PENDING'),
            carrier_name     NVARCHAR(100) NULL,
            tracking_number  VARCHAR(100) NULL,
            shipped_at       DATETIME2(3) NULL,
            delivered_at     DATETIME2(3) NULL,
            created_at       DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_shipments_created_at DEFAULT (SYSUTCDATETIME()),
            updated_at       DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_shipments_updated_at DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_app_shipments PRIMARY KEY CLUSTERED (shipment_id),
            CONSTRAINT UQ_app_shipments_shipment_number UNIQUE (shipment_number),
            CONSTRAINT FK_app_shipments_order FOREIGN KEY (order_id)
                REFERENCES app.orders (order_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_app_shipments_warehouse FOREIGN KEY (warehouse_id)
                REFERENCES app.warehouses (warehouse_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT CK_app_shipments_status CHECK
                (shipment_status IN ('PENDING', 'PACKED', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED')),
            CONSTRAINT CK_app_shipments_timestamps CHECK
            (
                updated_at >= created_at
                AND (shipped_at IS NULL OR shipped_at >= created_at)
                AND (delivered_at IS NULL OR (shipped_at IS NOT NULL AND delivered_at >= shipped_at))
            ),
            CONSTRAINT CK_app_shipments_shipped_at CHECK
                (shipment_status NOT IN ('SHIPPED', 'DELIVERED') OR shipped_at IS NOT NULL),
            CONSTRAINT CK_app_shipments_delivered_at CHECK
                (shipment_status <> 'DELIVERED' OR delivered_at IS NOT NULL)
        );
    END;

    IF OBJECT_ID(N'app.inventory_movements', N'U') IS NULL
    BEGIN
        CREATE TABLE app.inventory_movements
        (
            movement_id       BIGINT IDENTITY(1, 1) NOT NULL,
            product_id        BIGINT NOT NULL,
            warehouse_id      BIGINT NOT NULL,
            order_id          BIGINT NULL,
            movement_type     VARCHAR(24) NOT NULL,
            on_hand_delta     INT NOT NULL
                CONSTRAINT DF_app_inventory_movements_on_hand_delta DEFAULT (0),
            reserved_delta    INT NOT NULL
                CONSTRAINT DF_app_inventory_movements_reserved_delta DEFAULT (0),
            reason            NVARCHAR(250) NULL,
            occurred_at       DATETIME2(3) NOT NULL,
            created_at        DATETIME2(3) NOT NULL
                CONSTRAINT DF_app_inventory_movements_created_at DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_app_inventory_movements PRIMARY KEY CLUSTERED (movement_id),
            CONSTRAINT FK_app_inventory_movements_product FOREIGN KEY (product_id)
                REFERENCES app.products (product_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_app_inventory_movements_warehouse FOREIGN KEY (warehouse_id)
                REFERENCES app.warehouses (warehouse_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_app_inventory_movements_order FOREIGN KEY (order_id)
                REFERENCES app.orders (order_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT CK_app_inventory_movements_type CHECK
                (movement_type IN ('RECEIPT', 'RESERVE', 'RELEASE', 'SHIP', 'RETURN', 'ADJUSTMENT')),
            CONSTRAINT CK_app_inventory_movements_delta CHECK
                (on_hand_delta <> 0 OR reserved_delta <> 0)
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.products')
          AND name = N'IX_app_products_category_active'
    )
        CREATE INDEX IX_app_products_category_active
            ON app.products (category_name, is_active) INCLUDE (sku, product_name, unit_price);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.inventory')
          AND name = N'IX_app_inventory_warehouse_product'
    )
        CREATE INDEX IX_app_inventory_warehouse_product
            ON app.inventory (warehouse_id, product_id)
            INCLUDE (on_hand_quantity, reserved_quantity, reorder_level, updated_at);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.orders')
          AND name = N'IX_app_orders_customer_created'
    )
        CREATE INDEX IX_app_orders_customer_created
            ON app.orders (customer_id, created_at DESC)
            INCLUDE (order_number, order_status, currency_code, order_total);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.orders')
          AND name = N'IX_app_orders_status_updated'
    )
        CREATE INDEX IX_app_orders_status_updated
            ON app.orders (order_status, updated_at)
            INCLUDE (customer_id, order_total);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.order_items')
          AND name = N'IX_app_order_items_product'
    )
        CREATE INDEX IX_app_order_items_product
            ON app.order_items (product_id, order_id)
            INCLUDE (quantity, unit_price, line_total);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.payments')
          AND name = N'IX_app_payments_order_created'
    )
        CREATE INDEX IX_app_payments_order_created
            ON app.payments (order_id, created_at DESC)
            INCLUDE (payment_status, amount, currency_code);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.payments')
          AND name = N'IX_app_payments_status_updated'
    )
        CREATE INDEX IX_app_payments_status_updated
            ON app.payments (payment_status, updated_at)
            INCLUDE (order_id, amount);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.shipments')
          AND name = N'UX_app_shipments_tracking_number'
    )
        CREATE UNIQUE INDEX UX_app_shipments_tracking_number
            ON app.shipments (tracking_number)
            WHERE tracking_number IS NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.shipments')
          AND name = N'IX_app_shipments_order'
    )
        CREATE INDEX IX_app_shipments_order
            ON app.shipments (order_id, created_at DESC)
            INCLUDE (warehouse_id, shipment_status, tracking_number);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.inventory_movements')
          AND name = N'IX_app_inventory_movements_stock_timeline'
    )
        CREATE INDEX IX_app_inventory_movements_stock_timeline
            ON app.inventory_movements (product_id, warehouse_id, occurred_at, movement_id)
            INCLUDE (movement_type, on_hand_delta, reserved_delta, order_id);

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'app.inventory_movements')
          AND name = N'IX_app_inventory_movements_order'
    )
        CREATE INDEX IX_app_inventory_movements_order
            ON app.inventory_movements (order_id, occurred_at)
            INCLUDE (product_id, warehouse_id, movement_type, on_hand_delta, reserved_delta)
            WHERE order_id IS NOT NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
