CREATE OR REPLACE TABLE quarterly_sales (
    year     NUMBER,
    quarter  VARCHAR(2),
    sales    NUMBER
);

INSERT INTO quarterly_sales VALUES
    (2024, 'Q1', 1000),
    (2024, 'Q2', 1500),
    (2024, 'Q3', 1200),
    (2024, 'Q4', 1800),
    (2025, 'Q1', 1100),
    (2025, 'Q2', 1600);

SELECT * FROM QUARTERLY_SALES;

-- Method 1: Manual

SELECT
    year,
    MAX(CASE WHEN quarter = 'Q1' THEN sales END) AS q1_sales,
    MAX(CASE WHEN quarter = 'Q2' THEN sales END) AS q2_sales,
    MAX(CASE WHEN quarter = 'Q3' THEN sales END) AS q3_sales,
    MAX(CASE WHEN quarter = 'Q4' THEN sales END) AS q4_sales
FROM quarterly_sales
GROUP BY year
ORDER BY year;

---Method 2: Snowflake's native PIVOT (cleaner)

SELECT * FROM QUARTERLY_SALES
PIVOT (SUM(SALES) FOR QUARTER IN ('Q1','Q2','Q3','Q4')) AS P (YEAR,Q1_SALES,Q2_SALES,Q3_SALES,Q4_SALES)
order by YEAR;


-- UNPIVOT

CREATE OR REPLACE TABLE quarterly_sales_wide (
    year      NUMBER,
    q1_sales  NUMBER,
    q2_sales  NUMBER,
    q3_sales  NUMBER,
    q4_sales  NUMBER
);

INSERT INTO quarterly_sales_wide VALUES
    (2024, 1000, 1500, 1200, 1800),
    (2025, 1100, 1600, NULL, NULL);

SELECT * FROM quarterly_sales_wide;
--Method 1: Manual UNION ALL 

SELECT year, 'Q1' AS quarter, q1_sales AS sales FROM quarterly_sales_wide
UNION ALL
SELECT year, 'Q2' AS quarter, q2_sales AS sales FROM quarterly_sales_wide
UNION ALL
SELECT year, 'Q3' AS quarter, q3_sales AS sales FROM quarterly_sales_wide
UNION ALL
SELECT year, 'Q4' AS quarter, q4_sales AS sales FROM quarterly_sales_wide
ORDER BY year, quarter;

--Method 2: Snowflake's native UNPIVOT (cleaner)

SELECT * FROM quarterly_sales_wide
 UNPIVOT (SALES FOR QUARTER IN (Q1_SALES, Q2_SALES, Q3_SALES,Q4_SALES))
ORDER BY YEAR, QUARTER;
