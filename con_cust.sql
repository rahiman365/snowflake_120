CREATE OR REPLACE TABLE customer_orders (
    customer_id  NUMBER,
    order_date   DATE
);

INSERT INTO customer_orders VALUES
    (1, '2026-08-01'),
    (1, '2026-08-02'),
    (1, '2026-08-03'),
    (1, '2026-08-04'),   -- customer 1: 4 consecutive days (Aug 1-4)
    (1, '2026-08-10'),

    (2, '2026-08-01'),
    (2, '2026-08-02'),   -- customer 2: only 2 consecutive days
    (2, '2026-08-05'),

    (3, '2026-08-01'),
    (3, '2026-08-02'),
    (3, '2026-08-03'),
    (3, '2026-08-04'),
    (3, '2026-08-05');   -- customer 3: 5 consecutive days

    SELECT * FROM CUSTOMER_ORDERS;

    WITH RANKED AS (
    SELECT CUSTOMER_ID, ORDER_DATE,
            ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS RN 
    FROM CUSTOMER_ORDERS
    )
    SELECT * FROM RANKED;

    -- next logic 
      WITH RANKED AS (
    SELECT CUSTOMER_ID, ORDER_DATE,
            ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS RN 
    FROM CUSTOMER_ORDERS
    ),
    GROUPED AS
    (
    SELECT CUSTOMER_ID,ORDER_DATE,DATEADD(DAY,-RN,ORDER_DATE) AS GRP FROM RANKED
    ) 
  SELECT * FROM GROUPED;

  -- final logic 

      -- next logic 
    WITH RANKED AS (
    SELECT CUSTOMER_ID, ORDER_DATE,
            ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS RN 
    FROM CUSTOMER_ORDERS
    ),
    GROUPED AS
    (
    SELECT CUSTOMER_ID,ORDER_DATE,
            DATEADD(DAY,-RN,ORDER_DATE) AS GRP 
            FROM RANKED
    ),
    STREAKS AS
    (
    SELECT CUSTOMER_ID, 
    GRP,
    MIN(ORDER_DATE) STREAK_START,
    MAX(ORDER_DATE) STREAK_END,
    COUNT(*) STREAK_LENGTH
    FROM GROUPED
    GROUP BY CUSTOMER_ID,GRP
    )
    SELECT * exclude (grp) FROM STREAKS
    where STREAK_LENGTH>=3
    ;


    ---========================================================== REPEATIVE CUSTOMER IN NEXT MONTH 

    CREATE OR REPLACE TABLE customer_orders (
    customer_id  NUMBER,
    order_date   DATE
);

INSERT INTO customer_orders VALUES
    (1, '2026-06-05'),
    (1, '2026-07-10'),   -- customer 1: repeated in July (next month)
    (2, '2026-06-15'),
    (2, '2026-08-01'),   -- customer 2: skipped July, came back in August (NOT next month)
    (3, '2026-07-01'),
    (3, '2026-07-20'),   -- customer 3: same month only, no next-month repeat
    (4, '2026-06-01'),
    (4, '2026-07-05'),
    (4, '2026-08-10');   -- customer 4: repeated in both July AND August

    SELECT * FROM CUSTOMER_ORDERS;

    --2. Core approach — get distinct order months per customer, then self-join to next month

WITH monthly_orders AS (
        SELECT DISTINCT
        customer_id,
        DATE_TRUNC('MONTH', order_date) AS order_month
    FROM customer_orders
)
SELECT cur.CUSTOMER_ID,
        cur.order_month as current_month,
        nxt.order_month as repeat_month,
        DATEADD(MONTH,1,cur.order_month)
    FROM monthly_orders cur
    JOIN monthly_orders nxt on cur.customer_id = nxt.customer_id
   and nxt.order_month = DATEADD(MONTH,1,cur.order_month)
    order by CUSTOMER_ID;
    
    ---3. Simple flag — "did this customer repeat next month?" (one row per customer-month)

    WITH monthly_orders AS (
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('MONTH', order_date) AS order_month
    FROM customer_orders
)
SELECT
    customer_id,
    order_month,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM monthly_orders nxt
            WHERE nxt.customer_id = monthly_orders.customer_id
              AND nxt.order_month = DATEADD(MONTH, 1, monthly_orders.order_month)
        ) THEN 'Y'
        ELSE 'N'
    END AS repeated_next_month
FROM monthly_orders
ORDER BY customer_id, order_month;

--========================= INTERVIEW QUESTIONS and ANSWERS =============================================

with input_data as (
    select 1 as n
    union all select 2
    union all select 3
    union all select 4
)
select n,f.* from input_data,
lateral flatten (input => array_generate_range(0,n)) f
order by n;

--another method 
create table input_data(id int);
insert into input_data values(1),(2),(3),(4);
select * from input_data; -- [1,2,3,4]

-- one method
select * from input_data ,
lateral flatten (input => array_generate_range(0,id)) F;


--second method

with cte1 as (
select id,1 as counter from input_data

union all
select id, counter+1 from cte1
where counter < id 
)
select id from cte1
order by id;

with recursive_expand  as (
    -- anchor: start counter at 1 for every input row
    select id, 1 as counter
    from input_data

    union all

    -- recursive step: keep incrementing counter until it reaches n
    select id, counter + 1
    from recursive_expand
    where counter < id
)
select id
from recursive_expand
order by id;

--=================================== greatest lowest

CREATE OR REPLACE TABLE Emp(Grp varchar(20),SEQ int);

INSERT INTO Emp VALUES('A',1),('A',2) ,('A',3),('A',5),('A',6),('A',8),('A',9) ,('B',11),('C',1),('C',2),('C',3);
select * from emp;



---======= walk up the hierarchy from a given employee to the top

create or replace table employees (
    employee_id number,
    employee_name varchar,
    manager_id number,
    designation varchar
);

insert into employees values
    (1, 'Shripadh', NULL, 'CEO'),
    (2, 'Satya', 5, 'Software Engineer'),
    (3, 'Jia', 5, 'Data Analyst'),
    (4, 'David', 5, 'Data Scientist'),
    (5, 'Michael', 7, 'Manager'),
    (6, 'Arvind', 7, 'Architect'),
    (7, 'Asha', 1, 'CTO');

    with recursive_hierarchy (employee_id, employee_name, manager_id) as (
    select employee_id, employee_name, manager_id
    from employees
    where employee_id = 2   -- input employee to start from

    union all

    select e.employee_id, e.employee_name, e.manager_id
    from employees e
    join recursive_hierarchy r on e.employee_id = r.manager_id
)
select 
    r.employee_name,
    m.employee_name as manager_name
from recursive_hierarchy r
left join employees m on r.manager_id = m.employee_id;


--==================== filling nulls 

CREATE OR REPLACE TABLE input_table (
    id          INT,
    category    VARCHAR,
    brand_name  VARCHAR
);

INSERT INTO input_table (id, category, brand_name) VALUES
    (1, 'Beverages', 'Coca Cola'),
    (2, NULL,        'Pepsi'),
    (3, NULL,        'Sprite'),
    (4, NULL,        'Fanta'),
    (5, 'Snacks',    'Lays'),
    (6, NULL,        'Doritos'),
    (7, NULL,        'Kurkure');

    SELECT * FROM input_table ORDER BY id;


    SELECT
    brand_name,
    LAST_VALUE(category IGNORE NULLS) OVER (
        ORDER BY id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS category
FROM input_table
ORDER BY id;

select 
brand_name,
last_value(category ignore nulls) over (order by id rows between unbounded preceding and current row)
as category
from input_table;


--================= missing values 

CREATE OR REPLACE TABLE date_table (dt DATE);

INSERT INTO date_table VALUES
('2024-01-01'),('2024-01-02'),('2024-01-03'),('2024-01-04'),
('2024-01-05'),('2024-01-06'),('2024-01-07'),('2024-01-08'),
('2024-01-09'),('2024-01-10'),('2024-01-11'),('2024-01-12'),
-- 13th and 14th missing
('2024-01-15'),('2024-01-16'),('2024-01-17'),('2024-01-18'),
('2024-01-19'),('2024-01-20');


select * from date_table;

--calendar_table (365 days * 100 years)

WITH RECURSIVE full_range (dt) AS (
    -- Anchor: start from the minimum date in the table
    SELECT MIN(dt) AS dt
    FROM date_table
        UNION ALL

    -- Recursive step: keep adding a day until we hit the max date
    SELECT DATEADD(day, 1, fr.dt)
    FROM full_range fr
    WHERE fr.dt < (SELECT MAX(dt) FROM date_table)
)

SELECT d.dt,f.dt AS missing_date
FROM full_range f
left join date_table d 
on f.dt = d.dt 
where d.dt is null ;
