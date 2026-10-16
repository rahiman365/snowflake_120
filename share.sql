/*==============================================================
   ❄️  SNOWFLAKE DATA SHARING: HANDS-ON  ❄️
   
   What we'll do together:
   1) Create a Share (a "gift box" for your data)
   2) Create a Reader Account (a login for someone with no Snowflake)
   3) Create a database from the Share (opening the gift box)
   4) Add more objects to the Share
   5) Revoke access (taking the gift back)
===============================================================*/


/*--------------------------------------------------------------
  PART 0: Build some sample data (in YOUR account)
--------------------------------------------------------------*/

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE DEMO_DB;
CREATE SCHEMA DEMO_DB.DEMO_SCHEMA;
USE SCHEMA DEMO_DB.DEMO_SCHEMA;

-- A simple table
CREATE TABLE DEMO_TABLE (
    NAME STRING,
    AGE  INT
);

INSERT INTO DEMO_TABLE VALUES
  ('Edric', 56), ('Jayanthi', 23), ('Chloe', 51),
  ('Rowland', 50), ('Lorna', 33), ('Satish', 19);

-- A SECURE VIEW: shows only names of people older than 30.
-- (Sharing a view instead of the raw table is how you hide data you don't want to expose.)
CREATE SECURE VIEW DEMO_SEC_VIEW AS
SELECT NAME
FROM DEMO_TABLE
WHERE AGE > 30;


/*--------------------------------------------------------------
  PART 1: Create the Share (in YOUR account)
  Think of a share as a box. You decide what goes inside.
--------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

CREATE SHARE DEMO_SHARE COMMENT = 'Sharing demo data';

-- Give the share permission to "see" the database and schema...
GRANT USAGE ON DATABASE DEMO_DB                  TO SHARE DEMO_SHARE;
GRANT USAGE ON SCHEMA   DEMO_DB.DEMO_SCHEMA      TO SHARE DEMO_SHARE;

-- ...and then put the table inside the box
GRANT SELECT ON TABLE DEMO_DB.DEMO_SCHEMA.DEMO_TABLE TO SHARE DEMO_SHARE;

-- Check what's in the share
SHOW GRANTS TO SHARE DEMO_SHARE;


/*--------------------------------------------------------------
  PART 2: Create a Reader Account (in YOUR account)
  This is the login for your friend who has no Snowflake account.
--------------------------------------------------------------*/

CREATE MANAGED ACCOUNT SNOWFLAKE_TUTORIAL_READER_ACCOUNT
    ADMIN_NAME     = 'admin',
    ADMIN_PASSWORD = 'ChangeMe#12345',   -- use a strong password; avoid simple ones!
    TYPE           = READER;

-- Look at the output. You'll see:
--   • the reader account's LOCATOR  (copy it!)  UP14775
--   • the reader account's URL      (send this to your friend)
SHOW MANAGED ACCOUNTS;

-- Attach the reader account to your share (paste the locator from above)
ALTER SHARE DEMO_SHARE ADD ACCOUNTS = UP14775;

-- You'll also need YOUR account locator for the next part. Grab it here:
SELECT CURRENT_ACCOUNT();  --TF20192


/*--------------------------------------------------------------
  PART 3: Open the gift box (log in to the READER account)
  👉 Open the reader URL in a new tab, log in as admin
--------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

-- Turn the share into a database the reader can query
CREATE DATABASE DEMO_DB_READER
    FROM SHARE UP14775.DEMO_SHARE;   -- e.g. ek83803

-- Let SYSADMIN use it
GRANT IMPORTED PRIVILEGES ON DATABASE DEMO_DB_READER TO ROLE SYSADMIN;

USE ROLE SYSADMIN;

-- Reader accounts start with no compute, so create a small warehouse
CREATE OR REPLACE WAREHOUSE COMPUTE_XS WITH
    WAREHOUSE_SIZE    = 'XSMALL'
    WAREHOUSE_TYPE    = 'STANDARD'
    AUTO_SUSPEND      = 600     -- pauses after 10 minutes to save credits
    AUTO_RESUME       = TRUE
    SCALING_POLICY    = 'STANDARD';

USE WAREHOUSE COMPUTE_XS;
USE SCHEMA DEMO_DB_READER.DEMO_SCHEMA;

SELECT * FROM DEMO_TABLE;     -- 🎉 It works!


/*--------------------------------------------------------------
  PART 4: Add more to the Share (back in YOUR account)
--------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

GRANT SELECT ON VIEW DEMO_DB.DEMO_SCHEMA.DEMO_SEC_VIEW TO SHARE DEMO_SHARE;

-- Now switch to the READER account as SYSADMIN, and run:
--   SELECT * FROM DEMO_SEC_VIEW;
-- The new object appears instantly. No refresh or copy needed!

-- 💡 Tip: If you later change the definition of a shared object,
--         you'll need to grant it to the share again.


/*--------------------------------------------------------------
  PART 5: Take access away (in YOUR account)
--------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

ALTER SHARE DEMO_SHARE REMOVE ACCOUNTS = UP14775;

-- The reader's queries will now fail. The data was never copied, so it's gone from their side.

--create a database in reader account


/*--------------------------------------------------------------
  CLEAN UP
--------------------------------------------------------------*/

DROP SHARE DEMO_SHARE;
DROP MANAGED ACCOUNT SNOWFLAKE_TUTORIAL_READER_ACCOUNT;
DROP DATABASE DEMO_DB;


/*
docs 

https://docs.snowflake.com/en/user-guide/data-sharing-intro
*/


