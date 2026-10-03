create or replace storage integration s3_int
  type = external_stage
  storage_provider = s3
  enabled = true
  storage_aws_role_arn = 'arn:aws:iam::435098453023:role/snowflake-role'
  storage_allowed_locations = ('s3://snowflake-docs/tutorials/dataloading') ;  --('s3://testsnowflake/snowflake/', 's3://testxyzsnowflake/');

desc integration s3_int;


-- -- optional 
-- CREATE OR REPLACE STAGE my_public_stage
--   URL = 's3://snowflake-workshop-lab/citibike-trips-csv'
--   FILE_FORMAT = (TYPE = CSV);

-- LIST @my_public_stage;

-- storage integration (connection aws s3 to snowflake)

-- (pointing a folder in aws s3 to snowflake)
-- From Snowflake


---Stage creation 

  CREATE OR REPLACE STAGE my_public_stage
  URL = 's3://snowflake-docs/tutorials/dataloading'
  FILE_FORMAT = (TYPE = CSV);
  

LIST @my_public_stage;

-- contacts1 csv 
--ID|lastname|firstname|company|email|workphone|cellphone|streetaddress|city|postalcode


SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10
FROM @my_public_stage/contacts1.csv;






CREATE OR REPLACE FILE FORMAT my_pipe_format
TYPE = CSV 
FIELD_DELIMITER = '|'
SKIP_HEADER =1;

SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10
FROM @my_public_stage/contacts1.csv
(FILE_FORMAT => 'my_pipe_format');


CREATE OR REPLACE TABLE contacts (
  id INT,
  lastname STRING,
  firstname STRING,
  company STRING,
  email STRING,
  workphone STRING,
  cellphone STRING,
  streetaddress STRING,
  city STRING,
  postalcode STRING,
  source_file_name STRING,
  source_file_row_number NUMBER
);

select distinct source_file_name from contacts;

select * from contacts;

--truncate table contacts;

copy into contacts 
from @my_public_stage/contacts1.csv
file_format = 'my_pipe_format';

copy into contacts 
from @my_public_stage/contacts1.csv
file_format = 'my_pipe_format'
force=true;


-- To print file name, row number 

COPY INTO contacts (
  id, lastname, firstname, company, email,
  workphone, cellphone, streetaddress, city, postalcode,
  source_file_name, source_file_row_number
)
FROM (
  SELECT
    $1, $2, $3, $4, $5,
    $6, $7, $8, $9, $10,
    METADATA$FILENAME,
    METADATA$FILE_ROW_NUMBER
  FROM @my_public_stage
) 
PATTERN = '.*contacts[1-5]\.csv'
file_format = 'my_pipe_format';



-- Validation Mode
copy into contacts 
from @my_public_stage/contacts.json
file_format = 'my_pipe_format'
validation_mode='RETURN_ERRORS';



-- Validation Mode
copy into contacts 
from @my_public_stage/contacts.json
file_format = 'my_pipe_format'
validation_mode='RETURN_ERRORS';

copy into contacts 
from @my_public_stage/contacts.json
file_format = 'my_pipe_format'
validation_mode='RETURN_ALL_ERRORS';

copy into contacts 
from @my_public_stage/contacts.json
file_format = 'my_pipe_format'
validation_mode='RETURN_1_ROWS';



-- ON ERROR
copy into contacts 
from @my_public_stage/contacts.json
file_format = 'my_pipe_format'
on_error='CONTINUE';

copy into contacts 
from @my_public_stage/contacts.json
file_format = 'my_pipe_format'
on_error='ABORT_STATEMENT';

copy into contacts 
from @my_public_stage/contacts.json
file_format = 'my_pipe_format'
on_error='SKIP_FILE';


select * from contacts;


 
LIST @my_public_stage;


select $1
from @my_public_stage/contacts.json
(FILE_FORMAT => 'my_json_format');


CREATE OR REPLACE FILE FORMAT my_json_format
  TYPE = JSON
  STRIP_OUTER_ARRAY = TRUE
  IGNORE_UTF8_ERRORS = TRUE;

  
CREATE OR REPLACE TABLE customers_raw (
  raw_data VARIANT,
  source_file_name STRING,
  source_file_row_number NUMBER,
  load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


COPY INTO customers_raw (raw_data, source_file_name, source_file_row_number)
FROM (
  SELECT
    $1,
    METADATA$FILENAME,
    METADATA$FILE_ROW_NUMBER
  FROM @my_public_stage/contacts.json
)
FILE_FORMAT = (FORMAT_NAME = 'my_json_format')
ON_ERROR = 'CONTINUE';


select * from customers_raw;


select 
raw_data:customer:_id::varchar(50)  as custome_id,
raw_data:customer:address::varchar(50)  as address,
raw_data:customer:company::varchar(50)  as company,
raw_data:customer:email::varchar(50)  as email,
raw_data:customer:name:first::varchar(50)  as fname,
raw_data:customer:name:last::varchar(50)  as Lname,
 raw_data:customer:phone::STRING        AS phone,
from customers_raw;



---- raw table 

CREATE OR REPLACE TABLE raw_table (
  raw_data VARIANT
);

INSERT INTO raw_table (raw_data)
SELECT PARSE_JSON('{
  "customer": {
    "_id": "5730864df388f1d653e37e6f",
    "name": { "first": "Blankenship", "last": "Patrick" },
    "email": "blankenship.patrick@orbin.ca",
    "tags": ["vip", "retail", "loyalty"],
    "orders": [
      { "order_id": "O1001", "amount": 250.00 },
      { "order_id": "O1002", "amount": 89.50 }
    ]
  }
}');

INSERT INTO raw_table (raw_data)
SELECT PARSE_JSON('{
  "customer": {
    "_id": "5730864d4d8523c8baa8baf6",
    "name": { "first": "Anna", "last": "Glass" },
    "email": "anna.glass@snips.name",
    "tags": ["new"],
    "orders": [
      { "order_id": "O2001", "amount": 120.00 }
    ]
  }
}');

INSERT INTO raw_table (raw_data)
SELECT PARSE_JSON('{
  "customer": {
    "_id": "5730864e375e08523150fc04",
    "name": { "first": "Sparks", "last": "Ramos" },
    "email": "sparks.ramos@eschoir.co.uk",
    "tags": ["retail"],
    "orders": [
      { "order_id": "O3001", "amount": 310.75 },
      { "order_id": "O3002", "amount": 45.00 },
      { "order_id": "O3003", "amount": 199.99 }
    ]
  }
}');

SELECT * FROM raw_table;


-- basic flatten
SELECT
  raw_data:customer:_id::STRING          AS customer_id,
  raw_data:customer:name:first::STRING   AS first_name,
  raw_data:customer:name:last::STRING    AS last_name,
  raw_data:customer:email::STRING        AS email
FROM raw_table;


SELECT
  raw_data:customer:_id::STRING          AS customer_id,
  raw_data:customer:name:first::STRING   AS first_name,
  raw_data:customer:name:last::STRING    AS last_name,
  raw_data:customer:email::STRING        AS email,
  tag.value::varchar(100) as tag,
  orders.value:order_id::string as order_id,
  orders.value:amount::number(10,2) as Amount,
  
FROM raw_table,
lateral flatten(input =>raw_data:customer:tags) as tag,  --virtual table
lateral flatten(input =>raw_data:customer:orders) as orders  --virtual table
;









