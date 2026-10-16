/* =====================================================================
   SNOWFLAKE FEATURES TUTORIAL
   Topics: EXCLUDE / RENAME / REPLACE / ILIKE, INCLUDE NULLS (UNPIVOT),
           match-by-any (LIKE ANY, = ANY, PIVOT ANY, MATCH_RECOGNIZE),
           UNION ALL (and BY NAME), INTERSECT / MINUS, INSERT variants,
           MERGE, QUALIFY, GROUP BY ALL, ORDER BY ALL
   Run section by section in a Snowflake worksheet.
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 0. SETUP
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS TUTORIAL_DB;
CREATE SCHEMA   IF NOT EXISTS TUTORIAL_DB.DEMO;
USE SCHEMA TUTORIAL_DB.DEMO;

CREATE OR REPLACE TABLE employees (
    emp_id      INT,
    emp_name    STRING,
    email       STRING,
    department  STRING,
    salary      NUMBER(10,2),
    hire_date   DATE,
    manager_id  INT
);

CREATE OR REPLACE TABLE employees_stage (   -- incoming changes (used for MERGE)
    emp_id      INT,
    emp_name    STRING,
    email       STRING,
    department  STRING,
    salary      NUMBER(10,2),
    hire_date   DATE,
    manager_id  INT,
    op_type     STRING                      -- 'I' insert/update, 'D' delete
);

select * from employees_archive;
CREATE OR REPLACE TABLE employees_archive LIKE employees;   -- same structure

CREATE OR REPLACE TABLE high_paid  LIKE employees;
CREATE OR REPLACE TABLE low_paid   LIKE employees;

CREATE OR REPLACE TABLE quarterly_sales (
    product STRING,
    q1 NUMBER, q2 NUMBER, q3 NUMBER, q4 NUMBER
);

CREATE OR REPLACE TABLE monthly_sales (
    product STRING,
    sale_month STRING,
    amount NUMBER
);

CREATE OR REPLACE TABLE stock_prices (
    symbol STRING,
    trade_date DATE,
    price NUMBER(10,2)
);

-- ---------------------------------------------------------------------
-- 1. INSERT QUERIES
-- ---------------------------------------------------------------------

-- 1a. Single-row insert
INSERT INTO employees VALUES
    (1, 'Asha Rao', 'asha@corp.com', 'IT', 90000, '2020-01-15', NULL);

-- 1b. Multi-row insert
INSERT INTO employees VALUES
    (2, 'Ravi Kumar',  'ravi@corp.com',  'IT',      75000, '2021-03-10', 1),
    (3, 'Meena Iyer',  'meena@corp.com', 'HR',      60000, '2019-07-01', 1),
    (4, 'John Smith',  'john@corp.com',  'Finance', 82000, '2018-11-20', 1),
    (5, 'Priya Nair',  NULL,             'HR',      58000, '2022-05-05', 3),
    (6, 'Karan Shah',  'karan@corp.com', 'Finance', 95000, '2017-09-12', 4);

-- 1c. Insert with explicit column list (others become NULL)
INSERT INTO employees (emp_id, emp_name, department, salary)
VALUES (7, 'Neha Jain', 'IT', 70000);

-- 1d. INSERT ... SELECT
INSERT INTO employees_archive
SELECT * FROM employees WHERE hire_date < '2019-01-01';


select * from employees_archive;
select * from high_paid;

-- 1e. INSERT OVERWRITE (truncates the target first, then inserts)
INSERT OVERWRITE INTO employees_archive
SELECT * FROM employees ;--WHERE department = 'Finance';

-- 1f. Multi-table INSERT ALL (unconditional: every row goes to both tables)
INSERT ALL
    INTO employees_archive
    INTO high_paid
SELECT * FROM employees WHERE salary >= 90000;

-- 1g. Conditional multi-table INSERT ALL (a row can land in several tables)
INSERT ALL
    WHEN salary >= 80000 THEN INTO high_paid
    WHEN salary <  80000 THEN INTO low_paid
    WHEN department = 'IT' THEN INTO employees_archive
SELECT * FROM employees;


SELECT * FROM high_paid;
SELECT * FROM low_paid;

-- 1h. INSERT FIRST (a row goes only into the FIRST matching WHEN)
TRUNCATE TABLE high_paid;
TRUNCATE TABLE low_paid;

INSERT FIRST
    WHEN salary >= 80000 THEN INTO high_paid
    WHEN salary >= 0     THEN INTO low_paid
SELECT * FROM employees;

-- 1i. Staging rows for the MERGE demo
INSERT INTO employees_stage VALUES
    (2, 'Ravi Kumar',   'ravi@corp.com',   'IT',      85000, '2021-03-10', 1, 'I'),  -- update salary
    (3, 'Meena Iyer',   'meena@corp.com',  'HR',      60000, '2019-07-01', 1, 'D'),  -- delete
    (8, 'Sara Khan',    'sara@corp.com',   'Finance', 78000, '2023-02-01', 4, 'I');  -- new row

-- Sample data for the other demos
INSERT INTO quarterly_sales VALUES
    ('Laptop', 100, NULL, 150, 200),
    ('Phone',  300, 250,  NULL, 400);

INSERT INTO monthly_sales VALUES
    ('Laptop','Jan',100),('Laptop','Feb',120),('Laptop','Mar',90),
    ('Phone', 'Jan',300),('Phone', 'Feb',280),('Phone', 'Mar',310);

INSERT INTO stock_prices VALUES
    ('ABC','2024-01-01',10),('ABC','2024-01-02',9),('ABC','2024-01-03',8),
    ('ABC','2024-01-04',11),('ABC','2024-01-05',13),('ABC','2024-01-06',12);

-- ---------------------------------------------------------------------
-- 2. EXCLUDE / RENAME / REPLACE / ILIKE  (column selection helpers)
-- ---------------------------------------------------------------------

-- 2a. EXCLUDE: everything except the listed columns
SELECT * EXCLUDE (manager_id) FROM employees;

-- 2b. EXCLUDE several columns
SELECT * EXCLUDE (manager_id, hire_date, email) FROM employees;

-- 2c. EXCLUDE with a qualified star in a join
SELECT e.* EXCLUDE (manager_id), m.emp_name AS manager_name
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id;

-- 2d. RENAME: change names of selected columns while keeping all of them
SELECT * RENAME (emp_name AS employee_name, salary AS monthly_pay)
FROM employees;

-- 2e. EXCLUDE + RENAME together (EXCLUDE must come first)
SELECT * EXCLUDE (manager_id) RENAME (emp_name AS employee_name)
FROM employees;

-- 2f. REPLACE: change an expression but keep the column name/position
SELECT * REPLACE (UPPER(emp_name) AS emp_name, salary * 1.10 AS salary)
FROM employees;

select * from employees;

-- 2g. ILIKE on column names: pick columns whose NAME matches a pattern
SELECT * ILIKE '%id%' FROM employees;      -- emp_id, manager_id

-- ---------------------------------------------------------------------
-- 3. INCLUDE NULLS / EXCLUDE NULLS  (UNPIVOT)
-- ---------------------------------------------------------------------

-- 3a. Default UNPIVOT = EXCLUDE NULLS (NULL cells are dropped)
SELECT *
FROM quarterly_sales
UNPIVOT EXCLUDE NULLS (amount FOR quarter IN (q1, q2, q3, q4))
ORDER BY product, quarter;

-- 3b. INCLUDE NULLS keeps the NULL cells as rows
SELECT *
FROM quarterly_sales
UNPIVOT INCLUDE NULLS (amount FOR quarter IN (q1, q2, q3, q4))
ORDER BY product, quarter;

-- ---------------------------------------------------------------------
-- 4. "MATCH BY ANY" STYLE FEATURES
-- ---------------------------------------------------------------------

-- 4a. LIKE ANY: row matches if it matches ANY pattern in the list
SELECT emp_name, email
FROM employees
--WHERE emp_name  LIKE  'A%' OR emp_name LIKE '%Smith' OR emp_name LIKE 'Pri%';
WHERE emp_name NOT LIKE ANY ('A%', '%Smith', 'Pri%');

-- 4b. ILIKE ANY (case-insensitive) and LIKE ALL (must match all patterns)
SELECT emp_name FROM employees WHERE emp_name ILIKE ANY ('%ASHA%', '%ravi%');
SELECT emp_name FROM employees WHERE emp_name LIKE ALL ('%a%', '%n%');

-- 4c. NOT LIKE ANY
SELECT emp_name FROM employees 
WHERE emp_name NOT LIKE ANY ('A%', 'R%'); --- Error 

-- 4d. = ANY / IN with a subquery: match if equal to ANY row of the subquery
SELECT emp_name, department
FROM employees
WHERE department = ANY (SELECT department FROM employees WHERE salary > 90000);  -- multiple rows

-- 4e. Comparison with ANY / ALL rows
SELECT emp_name, salary
FROM employees
WHERE salary > ANY (SELECT salary FROM employees WHERE department = 'HR');  -- > min HR salary

SELECT emp_name, salary
FROM employees
WHERE salary > ALL (SELECT salary FROM employees WHERE department = 'HR');  -- > max HR salary

-- 4f. EXISTS: match if ANY row exists in the correlated subquery
SELECT m.emp_name AS manager
FROM employees m
WHERE EXISTS (SELECT 1 FROM employees e WHERE e.manager_id = m.emp_id);

-- 4g. Dynamic PIVOT: ANY = use every distinct value found in the data
SELECT *
FROM monthly_sales
PIVOT (SUM(amount) FOR sale_month IN (ANY ORDER BY sale_month))
ORDER BY product;

-- 4h. PIVOT with a fixed list and default for missing values
SELECT *
FROM monthly_sales
PIVOT (SUM(amount) FOR sale_month IN ('Jan','Feb','Mar','Apr') DEFAULT ON NULL (0))
ORDER BY product;

-- 4i. MATCH_RECOGNIZE: find rows that match a PATTERN across rows
--     Here: a price fall followed by a rise (V-shape)
SELECT *
FROM stock_prices
MATCH_RECOGNIZE (
    PARTITION BY symbol
    ORDER BY trade_date
    MEASURES
        MATCH_NUMBER()        AS match_no,
        FIRST(trade_date)     AS start_date,
        LAST(trade_date)      AS end_date,
        MIN(price)            AS bottom_price
    ONE ROW PER MATCH
    PATTERN (START_ROW DOWN+ UP+)
    DEFINE
        DOWN AS price < LAG(price),
        UP   AS price > LAG(price)
);

-- 4j. COPY INTO ... MATCH_BY_COLUMN_NAME (needs a stage + file; shown for reference)
-- COPY INTO employees
-- FROM @my_stage/employees.parquet
-- FILE_FORMAT = (TYPE = PARQUET)
-- MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ---------------------------------------------------------------------
-- 5. UNION ALL / UNION / INTERSECT / MINUS
-- ---------------------------------------------------------------------

-- 5a. UNION ALL keeps duplicates (fast, no de-dup)
SELECT emp_id, emp_name, department FROM employees WHERE department = 'IT'
UNION ALL
SELECT emp_id, emp_name, department FROM employees WHERE salary > 80000;

-- 5b. UNION removes duplicates
SELECT emp_id, emp_name, department FROM employees WHERE department = 'IT'
UNION
SELECT emp_id, emp_name, department FROM employees WHERE salary > 80000;

-- 5c. UNION ALL BY NAME: columns matched by NAME, not position
SELECT emp_id, emp_name FROM employees WHERE department = 'IT'
UNION ALL BY NAME
SELECT emp_name, emp_id FROM employees WHERE department = 'HR';   -- order differs, still OK

-- 5d. BY NAME with different column sets: missing columns become NULL
SELECT emp_id, emp_name, salary FROM employees WHERE department = 'IT'
UNION ALL BY NAME
SELECT emp_id, emp_name, department FROM employees WHERE department = 'HR';

-- 5e. Combine several tables and tag the source
SELECT 'archive' AS src, * FROM employees_archive
UNION ALL
SELECT 'high_paid' AS src, * FROM high_paid
UNION ALL
SELECT 'low_paid' AS src, * FROM low_paid;

-- 5f. INTERSECT (rows in both) and MINUS / EXCEPT (rows in first only)
SELECT emp_id FROM high_paid
INTERSECT
SELECT emp_id FROM employees_archive;

SELECT emp_id FROM employees
MINUS
SELECT emp_id FROM high_paid;

-- 5g. UNION ALL inside a CTE with aggregation
WITH all_staff AS (
    SELECT emp_id, department, salary FROM employees
    UNION ALL
    SELECT emp_id, department, salary FROM employees_stage WHERE op_type = 'I'
)
SELECT department, COUNT(*) AS cnt, AVG(salary) AS avg_salary
FROM all_staff
GROUP BY ALL
ORDER BY ALL;

-- ---------------------------------------------------------------------
-- 6. MERGE  (UPSERT + DELETE in one statement)
-- ---------------------------------------------------------------------

MERGE INTO employees AS t
USING employees_stage AS s
    ON t.emp_id = s.emp_id
WHEN MATCHED AND s.op_type = 'D' THEN
    DELETE
WHEN MATCHED AND s.op_type = 'I' THEN
    UPDATE SET
        t.emp_name   = s.emp_name,
        t.email      = s.email,
        t.department = s.department,
        t.salary     = s.salary
WHEN NOT MATCHED AND s.op_type = 'I' THEN
    INSERT (emp_id, emp_name, email, department, salary, hire_date, manager_id)
    VALUES (s.emp_id, s.emp_name, s.email, s.department, s.salary, s.hire_date, s.manager_id);

-- Check the result: emp 2 salary = 85000, emp 3 deleted, emp 8 added
SELECT * FROM employees ORDER BY emp_id;

-- 6b. MERGE with UPDATE only (no insert) from a subquery source
MERGE INTO employees t
USING (SELECT department, AVG(salary) AS avg_sal FROM employees GROUP BY department) s
    ON t.department = s.department
WHEN MATCHED AND t.salary < s.avg_sal * 0.7 THEN
    UPDATE SET t.salary = t.salary * 1.05;

-- Note: if one target row matches several source rows, Snowflake can raise an
-- error or pick one row (nondeterministic). To force an error, run:
-- ALTER SESSION SET ERROR_ON_NONDETERMINISTIC_MERGE = TRUE;

-- ---------------------------------------------------------------------
-- 7. OTHER USEFUL SNOWFLAKE SHORTCUTS
-- ---------------------------------------------------------------------

-- 7a. QUALIFY: filter on window functions without a subquery
SELECT * FROM (
SELECT *,
 ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) as RN
FROM employees
) as K where RN = 1;

SELECT *
FROM employees
--where salary>90000.00
QUALIFY ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) = 1
;  -- top paid per dept

-- 7b. GROUP BY ALL / ORDER BY ALL
SELECT department, COUNT(*) AS headcount, MAX(salary) AS max_salary
FROM employees
GROUP BY ALL
ORDER BY ALL;

-- 7c. IFF, ZEROIFNULL and column aliases reused in the same SELECT
SELECT emp_name,
       salary,
       IFF(salary >= 80000, 'High', 'Normal') AS band,
       band || ' earner' AS label                 -- alias reuse works in Snowflake
FROM employees;

-- 7d. Combine: EXCLUDE + QUALIFY + UNION ALL BY NAME
SELECT * EXCLUDE (email, manager_id)
FROM employees
QUALIFY RANK() OVER (PARTITION BY department ORDER BY salary DESC) = 1
UNION ALL BY NAME
SELECT * EXCLUDE (email, manager_id)
FROM employees_archive;

-- ---------------------------------------------------------------------
-- 8. CLEANUP (optional)
-- ---------------------------------------------------------------------
-- DROP SCHEMA TUTORIAL_DB.DEMO;
-- DROP DATABASE TUTORIAL_DB;
