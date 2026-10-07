


CREATE OR REPLACE STAGE product_stage
  URL= 's3://snowflake-rahiman/product/'
  CREDENTIALS=(AWS_KEY_ID='x' AWS_SECRET_KEY='y')
  ENCRYPTION=(TYPE='AWS_SSE_KMS' KMS_KEY_ID = 'aws/key');

list @product_stage;

-- 5. External table
CREATE OR REPLACE EXTERNAL TABLE ext_products (
  product_id    NUMBER         AS (VALUE:c1::NUMBER),
  sku           VARCHAR        AS (VALUE:c2::VARCHAR),
  product_name  VARCHAR        AS (VALUE:c3::VARCHAR),
  category      VARCHAR        AS (VALUE:c4::VARCHAR),
  price         NUMBER(10,2)   AS (VALUE:c5::NUMBER(10,2)),
  stock_qty     NUMBER         AS (VALUE:c6::NUMBER),
  is_active     BOOLEAN        AS (VALUE:c7::BOOLEAN),
  created_at    TIMESTAMP_NTZ  AS (VALUE:c8::TIMESTAMP_NTZ)
)
LOCATION = @product_stage/
AUTO_REFRESH = FALSE
FILE_FORMAT = (FORMAT_NAME = 'csv_products_ff1')
PATTERN = '.*products_[0-9]+[.]csv';

ALTER EXTERNAL TABLE ext_products REFRESH;

SELECT * exclude (value) FROM ext_products;


INSERT INTO ext_products ()
values ()

CREATE OR REPLACE FILE FORMAT csv_products_ff1
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"';

SELECT $1, $2, $3, $4, $5, $6, $7, $8
FROM @product_stage/products_001.csv
(FILE_FORMAT => 'csv_products_ff1');

--unloading  , need to work on

COPY INTO @product_stage/products_003.csv
FROM (
  SELECT 1010, 'SKU-MIC-010', 'USB Microphone', 'Accessories',
         79.99, 45, TRUE, '2026-10-08 11:30:00'
)
FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' COMPRESSION = NONE)
HEADER = TRUE
SINGLE = TRUE
OVERWRITE = TRUE;

ALTER EXTERNAL TABLE ext_products REFRESH;

SELECT * FROM ext_products ORDER BY product_id;
