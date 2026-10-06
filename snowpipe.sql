CREATE DATABASE IF NOT EXISTS snowpipe_lab;
CREATE SCHEMA IF NOT EXISTS snowpipe_lab.practice;
USE SCHEMA snowpipe_lab.practice;

CREATE OR REPLACE TABLE orders (
  order_id   INT,
  customer   STRING,
  amount     NUMBER(10,2),
  order_date DATE
);

CREATE OR REPLACE FILE FORMAT csv_ff
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"';

  -- step 2 

CREATE OR REPLACE STAGE order_stage
  URL= 's3://snowflake-rahiman/orders/'
  CREDENTIALS=(AWS_KEY_ID='a' AWS_SECRET_KEY='b')
  ENCRYPTION=(TYPE='AWS_SSE_KMS' KMS_KEY_ID = 'aws/key')
FILE_FORMAT = csv_ff;



LIST @order_stage;  -- test access

CREATE OR REPLACE PIPE orders_pipe
  AUTO_INGEST = TRUE
AS
COPY INTO orders
FROM @order_stage;

SHOW PIPES;
-- copy the notification_channel (an SQS ARN)




SELECT * FROM orders;

SELECT SYSTEM$PIPE_STATUS('orders_pipe');

SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'ORDERS',
  START_TIME => DATEADD(hour, -1, CURRENT_TIMESTAMP())));


-- need to refresh manually
ALTER PIPE orders_pipe REFRESH;

--to pause 
ALTER PIPE orders_pipe SET PIPE_EXECUTION_PAUSED = TRUE;


-- Now we will test it with bad file 
-- we can see row with bad file "Numeric value 'abc' is not recognized"
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'ORDERS',
  START_TIME => DATEADD(hour, -1, CURRENT_TIMESTAMP())));

--Check recent Snowpipe activity
SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.PIPE_USAGE_HISTORY(
        DATE_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
        DATE_RANGE_END   => CURRENT_TIMESTAMP()
    )
)
ORDER BY START_TIME DESC;


--Check a particular pipe

-- You can query account usage:
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE PIPE_NAME = 'MY_DB.MY_SCHEMA.MY_PIPE'
ORDER BY LAST_LOAD_TIME DESC;


--to see only failed loads:
SELECT
    FILE_NAME,
    LAST_LOAD_TIME,
    STATUS,
    ROW_COUNT,
    ERROR_COUNT,
    FIRST_ERROR_MESSAGE
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE PIPE_NAME = 'MY_DB.MY_SCHEMA.MY_PIPE'
  AND STATUS = 'LOAD_FAILED'
ORDER BY LAST_LOAD_TIME DESC;
