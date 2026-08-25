 -- optional 
CREATE OR REPLACE STAGE my_public_stage
  URL = 's3://snowflake-workshop-lab/citibike-trips-csv'
  FILE_FORMAT = (TYPE = CSV);

LIST @my_public_stage;


-- From Snowflake
   CREATE OR REPLACE STAGE my_public_stage
  URL = 's3://snowflake-docs/tutorials/dataloading'
  FILE_FORMAT = (TYPE = CSV);

LIST @my_public_stage;


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
  postalcode STRING
);

copy into contacts 
from @my_public_stage/contacts1.csv
file_format = 'my_pipe_format';

copy into contacts 
from @my_public_stage/contacts1.csv
file_format = 'my_pipe_format'
force=true;


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

SELECT * FROM TABLE(validate(my_table, last_query_i));



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
