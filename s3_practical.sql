DROP STAGE IF EXISTS external_stage;
DROP INTEGRATION IF EXISTS s3_int_abdul;

create or replace storage integration s3_int_abdul
  type = external_stage
  storage_provider = s3
  enabled = true
  storage_aws_role_arn = 'fromaws'
  storage_allowed_locations = ('s3://') ;


  
desc integration s3_int_abdul;

DESC STAGE external_stage;




--==================================== stage by IAM user 

USE SCHEMA mydb.public;

CREATE OR REPLACE STAGE external_stage2 
  URL= 's3://'
  CREDENTIALS=(AWS_KEY_ID='a' AWS_SECRET_KEY='b')
  ENCRYPTION=(TYPE='AWS_SSE_KMS' KMS_KEY_ID = 'aws/key');

  list @external_stage2;

  -- format 

  CREATE OR REPLACE FILE FORMAT my_csv_format
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"';

-- Preview the data first
SELECT $1, $2, $3
FROM @external_stage2/csv/customers_001.csv
(FILE_FORMAT => 'my_csv_format')
LIMIT 10;

-- Then load it into a table (create the table first with matching columns)
COPY INTO customers
FROM @external_stage2/csv/
FILE_FORMAT = (FORMAT_NAME = 'my_csv_format')
PATTERN = '.*customers.*[.]csv';

CREATE OR REPLACE TABLE customers (
  customer_id   NUMBER(10,0)  NOT NULL,
  first_name    VARCHAR(50),
  last_name     VARCHAR(50),
  email         VARCHAR(100),
  phone         VARCHAR(20),
  city          VARCHAR(50),
  state         VARCHAR(50),
  segment       VARCHAR(20),
  signup_date   DATE,
  credit_limit  NUMBER(12,2),
  is_active     BOOLEAN,
  PRIMARY KEY (customer_id)
);


select * from customers;

SELECT COUNT(*) FROM customers;   -- should be 25 for this file



SELECT segment, COUNT(*) AS cnt, SUM(credit_limit) AS total_credit
FROM customers
GROUP BY segment;

--- json files but table structure remains same 


CREATE OR REPLACE FILE FORMAT customer_json_format
  TYPE = JSON
  STRIP_OUTER_ARRAY = TRUE;

  LIST @external_stage2;


-- stage table for raw json data
  CREATE OR REPLACE TABLE customers_raw_json (
  v          VARIANT,
  src_file   VARCHAR,
  loaded_at  TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);



COPY INTO customers_raw_json (v, src_file)
FROM (
  SELECT $1, METADATA$FILENAME
  FROM @external_stage2/json/
)
FILE_FORMAT = (FORMAT_NAME = 'customer_json_format')
PATTERN = '.*[.]json';

SELECT COUNT(*) FROM customers_raw_json;  
-- expect 50
SELECT src_file, COUNT(*) FROM customers_raw_json GROUP BY src_file;  -- 25 + 25

--Query the nested fields

SELECT
  v:customer_id::NUMBER          AS customer_id,
  v:name.first::STRING           AS first_name,
  v:name.last::STRING            AS last_name,
  v:email::STRING                AS email,
  v:phone::STRING                AS phone,
  v:address.city::STRING         AS city,
  v:address.state::STRING        AS state,
  v:address.country::STRING      AS country,
  v:segment::STRING              AS segment,
  v:signup_date::DATE            AS signup_date,
  v:credit_limit::NUMBER(12,2)   AS credit_limit,
  v:is_active::BOOLEAN           AS is_active,
  v:preferences.newsletter::BOOLEAN AS newsletter,
  v:preferences.channels         AS channels
FROM customers_raw_json;

--Create a structured table from it

CREATE OR REPLACE TABLE customers_json AS
SELECT
  v:customer_id::NUMBER(10,0)    AS customer_id,
  v:name.first::VARCHAR(50)      AS first_name,
  v:name.last::VARCHAR(50)       AS last_name,
  v:email::VARCHAR(100)          AS email,
  v:phone::VARCHAR(20)           AS phone,
  v:address.city::VARCHAR(50)    AS city,
  v:address.state::VARCHAR(50)   AS state,
  v:address.country::VARCHAR(50) AS country,
  v:segment::VARCHAR(20)         AS segment,
  v:signup_date::DATE            AS signup_date,
  v:credit_limit::NUMBER(12,2)   AS credit_limit,
  v:is_active::BOOLEAN           AS is_active,
  v:preferences.newsletter::BOOLEAN AS newsletter,
  v:preferences.channels::ARRAY  AS channels
FROM customers_raw_json;


--Expand the channels array (one row per channel)
SELECT c.customer_id, f.value::STRING AS channel
FROM customers_json c,
     LATERAL FLATTEN(input => c.channels) f;

-- Customers per channel
SELECT f.value::STRING AS channel, COUNT(*) AS customers
FROM customers_json c,
     LATERAL FLATTEN(input => c.channels) f
GROUP BY 1;

/*
Things to know
COPY INTO skips files it already loaded. To reload, use FORCE = TRUE or truncate the table first.
If the array file fails with a "document is too large" error, that means the file is big. It won't happen with 25 records, but for large files Snowflake limits each element to 16 MB.
If you see only 26 rows instead of 50, the array file loaded as one row, so check that STRIP_OUTER_ARRAY = TRUE is in the format you used.
*/

