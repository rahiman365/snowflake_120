--Data : 

-- ============================================================
-- Setup script: Tables + sample data for the 8 SQL UDF examples
-- Run this BEFORE creating/testing the UDFs
-- Adjust database/schema as needed, e.g.: USE DATABASE course_db; USE SCHEMA raw;
-- ============================================================


-- ------------------------------------------------------------
-- 1. GST / Tax Calculation  -> products
-- ------------------------------------------------------------

select * from products;
CREATE OR REPLACE TABLE products (
  product_id    NUMBER(10,0),
  product_name  VARCHAR(100),
  price         NUMBER(10,2)
);

INSERT INTO products (product_id, product_name, price) VALUES
  (1, 'Wireless Mouse',      799.00),
  (2, 'Mechanical Keyboard', 2999.00),
  (3, 'USB-C Hub',           1499.00),
  (4, '27-inch Monitor',     15999.00),
  (5, 'Laptop Stand',        1199.00);


-- ------------------------------------------------------------
-- 2. Age From Date of Birth -> employees
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE employees (
  employee_id    NUMBER(10,0),
  employee_name  VARCHAR(100),
  dob            DATE
);

INSERT INTO employees (employee_id, employee_name, dob) VALUES
  (1, 'Anita Rao',      '1990-03-15'),
  (2, 'Vikram Shah',    '1985-11-02'),
  (3, 'Priya Nair',     '1998-07-21'),
  (4, 'Rahul Mehta',    '1993-01-30'),
  (5, 'Sneha Kulkarni', '2000-10-05');


-- ------------------------------------------------------------
-- 3. Mask Phone Number  &  7. Email Domain Extractor -> customers
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE customers (
  customer_id    NUMBER(10,0),
  customer_name  VARCHAR(100),
  phone_number   VARCHAR(20),
  email          VARCHAR(100)
);

INSERT INTO customers (customer_id, customer_name, phone_number, email) VALUES
  (1, 'Anita Rao',      '9876543210', 'anita.rao@gmail.com'),
  (2, 'Vikram Shah',    '9823456781', 'vikram.shah@infosys.com'),
  (3, 'Priya Nair',     '9900112233', 'priya.nair@yahoo.com'),
  (4, 'Rahul Mehta',    '9765432109', 'rahul.mehta@tcs.com'),
  (5, 'Sneha Kulkarni', '9654321098', 'sneha.k@gmail.com');


-- ------------------------------------------------------------
-- 4. Business Day Calculator  &  6. CLV Tier -> orders
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE orders (
  order_id      NUMBER(10,0),
  customer_id   NUMBER(10,0),
  order_date    DATE,
  order_amount  NUMBER(10,2)
);

INSERT INTO orders (order_id, customer_id, order_date, order_amount) VALUES
  (101, 1, '2024-03-01', 12000.00),
  (102, 1, '2024-04-12', 45000.00),
  (103, 2, '2024-02-20', 8000.00),
  (104, 3, '2024-05-05', 110000.00),
  (105, 3, '2024-06-18', 25000.00),
  (106, 4, '2024-01-10', 3000.00),
  (107, 5, '2024-07-22', 60000.00);


-- ------------------------------------------------------------
-- 5. Standardize Phone Number Format -> staging.customer_import
--    (uses a separate 'staging' schema - create it if needed)
-- ------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS staging;

CREATE OR REPLACE TABLE staging.customer_import (
  import_id   NUMBER(10,0),
  raw_phone   VARCHAR(30)
);

INSERT INTO staging.customer_import (import_id, raw_phone) VALUES
  (1, '(91) 98765-43210'),
  (2, '+91-9876543210'),
  (3, '98765 43210'),
  (4, '91.9876543210'),
  (5, '9876543210');


-- ------------------------------------------------------------
-- 8. Currency Conversion -> exchange_rates + international_orders
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE exchange_rates (
  code   VARCHAR(5),
  rate   NUMBER(10,4)   -- units of this currency per 1 USD
);

INSERT INTO exchange_rates (code, rate) VALUES
  ('INR', 83.1500),
  ('EUR', 0.9200),
  ('GBP', 0.7800),
  ('JPY', 149.5000),
  ('USD', 1.0000);

CREATE OR REPLACE TABLE international_orders (
  order_id   NUMBER(10,0),
  amount     NUMBER(12,2),
  currency   VARCHAR(5)
);

INSERT INTO international_orders (order_id, amount, currency) VALUES
  (201, 5000.00,   'INR'),
  (202, 120.00,    'EUR'),
  (203, 75.50,     'GBP'),
  (204, 15000.00,  'JPY'),
  (205, 250.00,    'USD');


-- ============================================================
-- Quick sanity check - run after creating the UDFs from class
-- ============================================================
-- SELECT product_name, price,-- calculate_gst(price, 18) 
-- FROM products;
-- SELECT employee_name, dob, calculate_age(dob) FROM employees;
-- SELECT customer_name, mask_phone(phone_number) FROM customers;
-- SELECT order_date, add_business_days(order_date, 5) FROM orders;
-- SELECT raw_phone, clean_phone(raw_phone) FROM staging.customer_import;
-- SELECT customer_id, SUM(order_amount), clv_tier(SUM(order_amount)) FROM orders GROUP BY customer_id;
-- SELECT email, extract_domain(email) FROM customers;
-- SELECT order_id, amount, currency, convert_to_usd(amount, currency) FROM international_orders;

--Functions: 

CREATE OR REPLACE FUNCTION calculate_gst(amount FLOAT)
RETURNS FLOAT
AS
$$
  ROUND(amount * (1 + 20/100), 2)
$$;

SELECT product_name, price, price*1.20 as new_price,
calculate_gst(price) AS price_with_gst
FROM products;


CREATE OR REPLACE FUNCTION mask_phone(phone STRING)
RETURNS STRING
AS
$$
  'XXXXXX' || RIGHT(phone, 4)
$$;

SELECT customer_name,phone_number,  'XXXXXX' || RIGHT(phone_number, 4),
mask_phone(phone_number) AS masked_phone FROM customers;


CREATE OR REPLACE FUNCTION calculate_age(dob DATE)
RETURNS INTEGER
AS
$$
  DATEDIFF('year', dob, CURRENT_DATE()) -
  IFF(
    (MONTH(CURRENT_DATE()) < MONTH(dob)) OR
    (MONTH(CURRENT_DATE()) = MONTH(dob) AND DAY(CURRENT_DATE()) < DAY(dob)),
    1, 0
  )
$$;

SELECT employee_name, dob, calculate_age(dob) AS age FROM employees;


CREATE OR REPLACE FUNCTION add_business_days(start_date DATE, days_to_add INTEGER)
RETURNS DATE
AS
$$
  DATEADD('day', days_to_add + (FLOOR(days_to_add / 5) * 2), start_date)
$$;

SELECT order_date, add_business_days(order_date, 5) AS estimated_delivery FROM orders;


CREATE OR REPLACE FUNCTION clean_phone(raw_phone STRING)
RETURNS STRING
AS
$$
  REGEXP_REPLACE(raw_phone, '[^0-9]', '')
$$;

SELECT raw_phone, clean_phone(raw_phone) AS cleaned
FROM staging.customer_import;


CREATE OR REPLACE FUNCTION clv_tier(total_spend FLOAT)
RETURNS STRING
AS
$$
  CASE
    WHEN total_spend >= 100000 THEN 'PLATINUM'
    WHEN total_spend >= 50000  THEN 'GOLD'
    WHEN total_spend >= 10000  THEN 'SILVER'
    ELSE 'BRONZE'
  END
$$;

SELECT customer_id, SUM(order_amount) AS total_spend,
       clv_tier(SUM(order_amount)) AS tier
FROM orders
GROUP BY customer_id;



CREATE OR REPLACE FUNCTION extract_domain(email STRING)
RETURNS STRING
AS
$$
  SPLIT_PART(email, '@', 2)
$$;

SELECT extract_domain(email) AS domain, COUNT(*) AS signups
FROM customers
GROUP BY extract_domain(email)
ORDER BY signups DESC;



CREATE OR REPLACE FUNCTION convert_to_usd(amount FLOAT, currency_code STRING)
RETURNS FLOAT
AS
$$
  amount / (SELECT rate FROM exchange_rates WHERE code = currency_code)
$$;

SELECT order_id, amount, currency, convert_to_usd(amount, currency) AS amount_usd
FROM international_orders;
