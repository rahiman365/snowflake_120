--1. Clone a table
--sql
create table dim_customer_clone
clone dim_customer_2;

select * from dim_customer_clone;  -- identical data, instantly

--2. Clone as of a past point in time (combining with Time Travel!)
--sql
create table dim_customer_backup_aug20
clone dim_customer
at(timestamp => '2026-08-24 22:45:00'::timestamp);

select table_name, active_bytes, clone_group_id
from snowflake.account_usage.table_storage_metrics
where table_name in ('DIM_CUSTOMER_2', 'DIM_CUSTOMER_CLONE');

update dim_customer_clone set city = 'CLONE_TEST' where customer_id = 1;

select customer_id, city from dim_customer_2 where customer_id = 1;        -- unaffected
select customer_id, city from dim_customer_clone where customer_id = 1;  -- changed
