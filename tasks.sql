CREATE OR REPLACE TASK log_products_task
    WAREHOUSE = TASK_WH
    SCHEDULE = '5 MINUTE'
AS
INSERT INTO products_log (product_id, product_name, checked_at)
SELECT product_id, product_name, CURRENT_TIMESTAMP()
FROM products;

-- Supporting log table
CREATE OR REPLACE TABLE products_log (
    product_id    NUMBER,
    product_name  VARCHAR(100),
    checked_at    TIMESTAMP_NTZ
);


ALTER TASK log_products_task RESUME;

ALTER TASK log_products_task SUSPEND;


