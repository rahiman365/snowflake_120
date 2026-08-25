CREATE OR REPLACE TABLE customer (
    customer_id  NUMBER,
    customer_name VARCHAR(100),
    latitude     FLOAT,
    longitude    FLOAT
);

INSERT INTO customer VALUES
    (1, 'Anjali Rao',   17.3850, 78.4867),   -- Hyderabad
    (2, 'Rahul Mehta',  19.0760, 72.8777),   -- Mumbai
    (3, 'Priya Nair',   12.9716, 77.5946);   -- Bangalore

CREATE OR REPLACE TABLE store (
    store_id    NUMBER,
    store_name  VARCHAR(100),
    latitude    FLOAT,
    longitude   FLOAT
);

INSERT INTO store VALUES
    (101, 'Store - Hyderabad Central', 17.4065, 78.4772),
    (102, 'Store - Secunderabad',      17.4399, 78.4983),
    (103, 'Store - Mumbai Andheri',    19.1197, 72.8468),
    (104, 'Store - Bangalore MG Road', 12.9758, 77.6046),
    (105, 'Store - Chennai T Nagar',   13.0418, 80.2341);


WITH distances AS (
    SELECT
        c.customer_id,
        c.customer_name,
        s.store_id,
        s.store_name,
        ST_DISTANCE(
            ST_MAKEPOINT(c.longitude, c.latitude),
            ST_MAKEPOINT(s.longitude, s.latitude)
        ) / 1000 AS distance_km          -- ST_DISTANCE returns meters
    FROM customer c
    CROSS JOIN store s
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY distance_km ASC) AS rn
    FROM distances
)
SELECT
    customer_id,
    customer_name,
    store_id,
    store_name,
    ROUND(distance_km, 2) AS nearest_distance_km
FROM ranked
WHERE rn = 1
ORDER BY customer_id;
