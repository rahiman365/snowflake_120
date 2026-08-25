-- Source table: raw product data
CREATE OR REPLACE TABLE products (
    product_id     NUMBER AUTOINCREMENT PRIMARY KEY,
    product_name   VARCHAR(100),
    category        VARCHAR(50),
    unit_price      NUMBER(10,2),
    quantity_in_stock NUMBER,
    last_updated    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO products (product_name, category, unit_price, quantity_in_stock)
VALUES
    ('Wireless Mouse', 'Electronics', 799.00, 150),
    ('Office Chair', 'Furniture', 4999.00, 40),
    ('Notebook Set', 'Stationery', 199.00, 500),
    ('LED Monitor', 'Electronics', 8999.00, 60),
    ('Standing Desk', 'Furniture', 12999.00, 20);

-- Second source table: sales transactions
CREATE OR REPLACE TABLE sales (
    sale_id       NUMBER AUTOINCREMENT PRIMARY KEY,
    product_id    NUMBER,
    quantity_sold NUMBER,
    sale_date     DATE,
    sale_amount   NUMBER(10,2)
);

INSERT INTO sales (product_id, quantity_sold, sale_date, sale_amount)
VALUES
    (1, 10, '2026-08-01', 7990.00),
    (2, 2, '2026-08-02', 9998.00),
    (3, 50, '2026-08-03', 9950.00),
    (4, 5, '2026-08-04', 44995.00),
    (1, 20, '2026-08-05', 15980.00);

select * from sales;

--drop table PRODUCT_SALES_SUMMARY;


CREATE OR REPLACE DYNAMIC TABLE PRODUCT_SALES_SUMMARY
TARGET_LAG = '5 minutes'
WAREHOUSE = COMPUTE_WH
AS
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.unit_price,
    p.quantity_in_stock,
    COALESCE(SUM(s.quantity_sold), 0)  AS total_quantity_sold,
    COALESCE(SUM(s.sale_amount), 0)    AS total_sales_amount,
    p.quantity_in_stock - COALESCE(SUM(s.quantity_sold), 0) AS remaining_stock
FROM products p
LEFT JOIN sales s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id, p.product_name, p.category, p.unit_price, p.quantity_in_stock;


SELECT * FROM product_sales_summary ORDER BY total_sales_amount DESC;

-- Add a new sale rows 
INSERT INTO sales (product_id, quantity_sold, sale_date, sale_amount)
VALUES (3, 100, '2026-08-06', 19900.00);

INSERT INTO sales (product_id, quantity_sold, sale_date, sale_amount)
VALUES (4, 2, '2026-08-06', 1999.00);

select * from sales;

-- Check refresh status/history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'product_sales_summary'));

-- After the target lag window passes (or you manually refresh), query again
SELECT * FROM product_sales_summary ORDER BY total_sales_amount DESC;

ALTER DYNAMIC TABLE product_sales_summary REFRESH;



