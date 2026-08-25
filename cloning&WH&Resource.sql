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

---============================================================
-- WAREHOUSES

show warehouses;

create warehouse if not exists practice_wh
    warehouse_size = 'XSMALL'
    auto_suspend = 60          -- suspend after 60 seconds idle
    auto_resume = true         -- wake up automatically on next query
    initially_suspended = true; -- don't start billing immediately on creation

alter warehouse practice_wh set warehouse_size = 'MEDIUM';

use warehouse practice_wh;
alter warehouse practice_wh set warehouse_size = 'XSMALL';

select customer_id, count(*)
from fact_sales
group by customer_id;
-- note the execution time in Query Profile

alter warehouse practice_wh set warehouse_size = 'MEDIUM';

select customer_id, count(*)
from fact_sales
group by customer_id;
-- compare execution time

alter warehouse practice_wh set
    warehouse_size = 'XSMALL'
    min_cluster_count = 1
    max_cluster_count = 3
    scaling_policy = 'STANDARD';  -- or 'ECONOMY' for slower, more cost-conscious scaling

--===== RESOURCE MONITOR 

create resource monitor practice_monitor
    with credit_quota = 100                       -- 100 credits for the period
    frequency = monthly
    start_timestamp = immediately
    triggers
        on 75 percent do notify
        on 90 percent do notify
        on 100 percent do suspend
        on 110 percent do suspend_immediate;

alter warehouse practice_wh set resource_monitor = practice_monitor;

show resource monitors;

select
    warehouse_name,
    start_time,
    end_time,
    credits_used
from snowflake.account_usage.warehouse_metering_history
where warehouse_name = 'PRACTICE_WH'
order by start_time desc;
