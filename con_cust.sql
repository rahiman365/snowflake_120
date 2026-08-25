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
    where STREAK_LENGTH>3
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
    
