CREATE OR REPLACE TABLE employee_source (
    employee_id     NUMBER,
    full_name       VARCHAR(100),
    department      VARCHAR(50),
    role            VARCHAR(50),
    manager_id      NUMBER,
    salary          NUMBER(10,2),
    updated_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Initial data
INSERT INTO employee_source (employee_id, full_name, department, role, manager_id, salary)
VALUES
    (101, 'Anjali Rao', 'Sales', 'Sales Executive', 105, 55000.00),
    (102, 'Rahul Mehta', 'Engineering', 'Software Engineer', 106, 85000.00),
    (105, 'Vikram Singh', 'Sales', 'Sales Manager', NULL, 120000.00),
    (106, 'Sara Khan', 'Engineering', 'Engineering Manager', NULL, 140000.00);


-- changes
INSERT INTO employee_source (employee_id, full_name, department, role, manager_id, salary)
VALUES
    (107, 'Naga', 'Engineering', 'Engineering Manager', 1054, 140000.00);
    
UPDATE employee_source
SET salary = 95000.00, updated_at = CURRENT_TIMESTAMP()
WHERE employee_id = 102;

UPDATE employee_source
SET role = 'Regional Sales Manager', salary = 130000.00
WHERE employee_id = 101;


-- 2nd level of changes 

INSERT INTO employee_source (employee_id, full_name, department, role, manager_id, salary)
VALUES
    (108, 'Abdul', 'Engineering', 'Engineering Manager', 105, 200000.00);
    
UPDATE employee_source
SET salary = 200000.00
WHERE employee_id = 106;



CREATE OR REPLACE TABLE dim_employee_scd2 (
    employee_key    NUMBER AUTOINCREMENT PRIMARY KEY,   -- surrogate key
    employee_id     NUMBER,                              -- natural/business key
    full_name       VARCHAR(100),
    department      VARCHAR(50),
    role            VARCHAR(50),
    manager_id      NUMBER,
    salary          NUMBER(10,2),
    start_date  DATE,
    end_date        DATE,
    is_current      BOOLEAN,
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


INSERT INTO dim_employee_scd2
    (employee_id, full_name, department, role, manager_id, salary, start_date, end_date, is_current)
SELECT
    employee_id, full_name, department, role, manager_id, salary,
    CURRENT_DATE(), '9999-12-31', TRUE
FROM employee_source;


select * from dim_employee_scd2;


--CREATE OR REPLACE STREAM employee_source_stream ON TABLE employee_source;

Create or replace stream employee_source_stream on table employee_source;

select * from employee_source_stream;

select * from dim_employee_scd2;
select * from dim_employee_scd2 where is_current='TRUE' order by 2;




CREATE OR REPLACE PROCEDURE sp_apply_employee_scd2()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    BEGIN TRANSACTION;

    -- Statement 1: MERGE — expire current rows and insert brand new rows
    MERGE INTO dim_employee_scd2 AS T
    USING employee_source_stream AS S
        ON T.employee_id = S.employee_id AND T.is_current = 'TRUE'
    WHEN MATCHED AND S.metadata$action = 'DELETE' AND S.metadata$isupdate = TRUE   -- Update 
    THEN UPDATE
        SET T.end_date   = CURRENT_DATE(),
            T.is_current = 'FALSE'
    WHEN NOT MATCHED AND S.metadata$action = 'INSERT' AND S.metadata$isupdate = FALSE   -- Brand New
    THEN INSERT (employee_id, full_name, department, role, manager_id, salary, start_date, end_date, is_current)
    VALUES (S.employee_id, S.full_name, S.department, S.role, S.manager_id, S.salary,
            CURRENT_DATE(), '9999-12-31', 'TRUE');

    -- Statement 2: INSERT new version of updated rows as new rows  -- new version of updated rows 
    INSERT INTO dim_employee_scd2 (employee_id, full_name, department, role, manager_id, salary, start_date, end_date, is_current)
    SELECT S.employee_id, S.full_name, S.department, S.role, S.manager_id, S.salary,
           CURRENT_DATE(), '9999-12-31', 'TRUE'
    FROM employee_source_stream S
    WHERE S.metadata$action = 'INSERT' AND S.metadata$isupdate = TRUE;

    COMMIT;

    RETURN 'SCD2 merge completed at ' || CURRENT_TIMESTAMP()::STRING || ' Successful';
END;
$$;



CREATE OR REPLACE TASK task_employee_scd2
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('employee_source_stream')
AS
CALL sp_apply_employee_scd2();


ALTER TASK task_employee_scd2 RESUME;


EXECUTE TASK task_employee_scd2;  -- manually force 

SELECT employee_id, full_name, department, role, salary,
       start_date, end_date, is_current
FROM dim_employee_scd2
ORDER BY employee_id, start_date;


select
    query_id,
    query_text,
    query_type,
    query_tag,
    user_name,
    warehouse_name,
    start_time,
    total_elapsed_time,
    rows_inserted,
    rows_deleted,
    rows_updated
from snowflake.account_usage.query_history
where query_tag = 'Im from DBT'
order by start_time desc
limit 50;

--=============================

SELECT
    warehouse_name,
    SUM(credits_used) AS total_credits_used
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits_used DESC;


SELECT
    usage_date,
    SUM(credits_used) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY usage_date
ORDER BY usage_date DESC;

SELECT
    query_tag,
    COUNT(*) AS query_count,
    SUM(total_elapsed_time) / 1000 AS total_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND query_tag ILIKE '%dbt%'
GROUP BY query_tag
ORDER BY total_seconds DESC;


DROP WAREHOUSE IF EXISTS TASK_WH;

select * from snapshots.snapshot_location order by location_id;



---=================================

SELECT	CURRENT_VERSION();
SELECT	CURRENT_ACCOUNT(),	CURRENT_REGION(),	CURRENT_ORGANIZATION_NAME();
SELECT	CURRENT_WAREHOUSE(),	CURRENT_ROLE(),	CURRENT_USER();
