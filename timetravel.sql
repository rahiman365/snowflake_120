--1. Query data as of a past timestamp
-- sql
create or replace table dim_customer_2 as select * from dim_customer;

show tables like 'dim_customer%';

select * from dim_customer
at(timestamp => '2026-08-24 22:45:34'::timestamp);

--2. Query data as of N minutes/hours ago (relative)
--sql
select *
from fact_sales
at(offset => -3600);  -- 1 hour ago, in seconds
--3. Query data "before" a specific query ID (very precise — great for debugging "what did this look like right before that bad job ran")
--sql

select *
from dim_customer
before(statement => '01c69e9c-000d-ee13-0001-965600279922');

--Get a query ID from select last_query_id(); right after running something, or from Query History.

--4. The most practical use — undo an accidental change

--Let's actually break something on purpose, then fix it with Time Travel.
--sql

-- Step 1: note the time
select current_timestamp();

-- Step 2: accidentally wreck some data
update dim_customer set city = 'UNKNOWN' where customer_id in (1,2);

-- Step 3: confirm the damage
select * from dim_customer where customer_id in (1,2);

--Now recover it:
--sql

-- Step 4: see what it looked like before the bad update
select *
from dim_customer
at(timestamp => '2026-08-24 22:45:34'::timestamp)
where customer_id in (1,2);

--5. Recover an entire dropped table — UNDROP
-- sql
drop table fact_sales;

select * from fact_sales;

-- Panic... then:
undrop table fact_sales;

select * from fact_sales;  -- it's back

--This is the single most-asked Time Travel interview question: "you accidentally dropped a production table — what do you do?" → UNDROP TABLE, instantly, no backup restore needed.

--6. Check/configure retention period
--sql

-- Check current retention (in days) for a table
show tables like 'fact_sales';
-- look at the "retention_time" column in the output

-- Set retention explicitly (Standard edition: 0 or 1 day; Enterprise+: up to 90 days)
alter table fact_sales set data_retention_time_in_days = 1;

create or replace table fact_sales_2 as
select * from fact_sales;

--Recover an entire dropped table — UNDROP
-- sql
drop table fact_sales_2;

select * from fact_sales_2;

-- Panic... then:
undrop table fact_sales_2;
show tables like 'fact_sales_2';
alter table fact_sales set data_retention_time_in_days = 2;

show parameters like 'DATA_RETENTION_TIME_IN_DAYS' in account;

select current_account(), system$whitelist(); -- or check in Snowsight under Admin > Billing


select current_account(), system$allowlist(); -- or check in Snowsight under Admin > Billing
select current_organization_name(), current_account_name();

show organization accounts;
