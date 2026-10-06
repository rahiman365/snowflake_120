CREATE DATABASE IF NOT EXISTS demo_db;

CREATE SCHEMA IF NOT EXISTS demo_db.sales;

USE SCHEMA demo_db.sales;

SELECT GET_DDL('PROCEDURE', 'SP_CUSTOMER_TARGET_SCD2');   -- shows full definition

CREATE OR REPLACE TABLE customers (
    customer_id   INT,
    customer_name STRING,
    email         STRING,
    region        STRING
);

CREATE OR REPLACE TABLE orders (
    order_id     INT,
    customer_id  INT,
    order_date   DATE,
    amount       NUMBER(10,2),
    status       STRING
);

INSERT INTO customers VALUES
 (1,'Ravi','ravi@mail.com','SOUTH'),
 (2,'Anita','anita@mail.com','NORTH'),
 (3,'John','john@mail.com','SOUTH');

INSERT INTO orders VALUES
 (101,1,'2026-09-01',500.00,'COMPLETED'),
 (102,1,'2026-09-15',250.00,'COMPLETED'),
 (103,2,'2026-09-20',700.00,'PENDING'),
 (104,3,'2026-10-01',300.00,'COMPLETED');


 --- 1 . Standard (Regular) View

-- A stored query. It holds no data; the query runs every time you select from it.

CREATE OR REPLACE VIEW v_customer_orders AS
SELECT c.customer_id,
       c.customer_name,
       c.region,
       o.order_id,
       o.order_date,
       o.amount
FROM   customers c
JOIN   orders o ON c.customer_id = o.customer_id
WHERE  o.status = 'COMPLETED';

SELECT * FROM v_customer_orders;

SHOW VIEWS LIKE 'V_CUSTOMER_ORDERS';

DESC VIEW v_customer_orders;

SELECT GET_DDL('VIEW', 'v_customer_orders');   -- shows full definition


--2  Secure View
/*
Same as a standard view, but the definition is hidden from non-owners and the optimizer won't push down user filters in ways that could leak data. Use it for data sharing and row/column-level security.
*/

CREATE OR REPLACE SECURE VIEW sv_customer_orders AS
SELECT c.customer_id,
       c.customer_name,
       c.region,
       o.order_id,
       o.amount
FROM   customers c
JOIN   orders o ON c.customer_id = o.customer_id;

SELECT * FROM sv_customer_orders;

--Convert between standard and secure

ALTER VIEW v_customer_orders SET SECURE;
ALTER VIEW v_customer_orders UNSET SECURE;

--Check whether a view is secure

SHOW VIEWS LIKE '%CUSTOMER_ORDERS%';   -- see the is_secure column


-- 3.. Materialized View
/*
Stores the precomputed results physically. Snowflake automatically keeps it up to date in the background (this uses serverless compute credits). Great for expensive aggregations queried often.
*/

CREATE OR REPLACE MATERIALIZED VIEW mv_sales_by_customer AS
SELECT customer_id,
       COUNT(*)      AS total_orders,
       SUM(amount)   AS total_amount,
       MAX(order_date) AS last_order_date
FROM   orders
WHERE  status = 'COMPLETED'
GROUP BY customer_id;

SELECT * FROM mv_sales_by_customer;

--Test auto-refresh
INSERT INTO orders VALUES (106,4,'2026-10-05',400.00,'COMPLETED');

-- After a short delay, the MV reflects the new row
SELECT * FROM mv_sales_by_customer;

--Manage and monitor

SHOW MATERIALIZED VIEWS;

-- Pause / resume background maintenance (controls cost)
ALTER MATERIALIZED VIEW mv_sales_by_customer SUSPEND;
ALTER MATERIALIZED VIEW mv_sales_by_customer RESUME;

-- Refresh cost history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.MATERIALIZED_VIEW_REFRESH_HISTORY(
       DATE_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
       MATERIALIZED_VIEW_NAME => 'MV_SALES_BY_CUSTOMER'));



--Secure materialized view

CREATE OR REPLACE SECURE MATERIALIZED VIEW smv_sales_by_customer AS
SELECT customer_id, SUM(amount) AS total_amount
FROM   orders
GROUP BY customer_id;

-- Clustering a materialized view (optional, for large data)

CREATE OR REPLACE MATERIALIZED VIEW mv_orders_by_date
  CLUSTER BY (order_date) AS
SELECT order_date, status, SUM(amount) AS total_amount
FROM   orders
GROUP BY order_date, status;


-- snowflake will decide based micro partition ( we don;t know which column)

-- cluster by (we can mention order_date as column name) ( same like index in sql server)



-- clean up 

DROP VIEW IF EXISTS v_customer_orders;
DROP VIEW IF EXISTS sv_customer_orders;
DROP MATERIALIZED VIEW IF EXISTS mv_sales_by_customer;



--- MV1 -- 
--- V2 

---V3 --> MV1 and V2

-- select * from V3 where () 
