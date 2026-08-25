-- Normal View
create or replace view vw_active_customers as
select customer_id, customer_name, email, city
from dbt_project.dbt.dim_customer
where email is not null;


select * from vw_active_customers; --PII

select get_ddl('view', 'vw_active_customers');

--Secure view
create or replace secure view vw_secure_customer as
select
    customer_id,
    customer_name,
    email,
    city
from dbt_project.dbt.dim_customer where city='Delhi';

select * from vw_secure_customer; --PII

select get_ddl('view', 'vw_secure_customer');

use role analyst_role;
select get_ddl('view', 'vw_secure_customer');
-- fails / definition hidden, unlike a regular view

show grants to role analyst_role;

revoke select on dbt_project.dbt.dim_customer from role analyst_role;
grant select on vw_secure_customer to role analyst_role;

use role accountadmin;

create role if not exists test_analyst_role;

-- Grant ONLY what we want to test with — nothing extra
grant usage on database DBT_PROJECT to role test_analyst_role;
grant usage on schema DBT_PROJECT.dbt to role test_analyst_role;

-- Deliberately grant access to the VIEW only, NOT the base table
grant select on vw_secure_customer to role test_analyst_role;

-- Assign to yourself for testing
grant role test_analyst_role to user rahiman365;
revoke role test_analyst_role from user rahiman365;


use role test_analyst_role;

select * from vw_secure_customer; --PII

select get_ddl('view', 'vw_secure_customer');

show grants to role test_analyst_role;
select current_database(), current_schema();

select * from vw_secure_customer; --PII

select get_ddl('view', 'vw_secure_customer');


use role test_analyst_role;

alter session set use_cached_result = false;

select get_ddl('view', 'vw_secure_customer');

select * from vw_secure_customer;

use role sysadmin;

create role if not exists view_owner_role;

-- Grant view_owner_role to sysadmin so sysadmin can manage/create things under it if needed
grant role view_owner_role to role sysadmin;

-- Grant it to yourself so you can switch into it
grant role view_owner_role to user rahiman365;

use role accountadmin;

grant usage on database DBT_PROJECT to role view_owner_role;
grant usage on schema DBT_PROJECT.dbt to role view_owner_role;
grant select on dim_customer to role view_owner_role;  -- needs to read base table to build the view
grant create view on schema DBT_PROJECT.dbt to role view_owner_role;

use role view_owner_role;

create or replace secure view vw_secure_customer_v2 as
select
    customer_id,
    customer_name,
    email,
    city
from DBT_PROJECT.dbt.dim_customer
limit 3;

use role accountadmin;

create role if not exists fresh_test_role;
grant usage on database DBT_PROJECT to role fresh_test_role;
grant usage on schema DBT_PROJECT.dbt to role fresh_test_role;
grant select on vw_secure_customer_v2 to role fresh_test_role;

grant role fresh_test_role to user rahiman365;


use role fresh_test_role;

select current_role();  -- confirm

-- Test A: can it use the view?
select * from vw_secure_customer_v2;

-- Test B: can it see the DDL?
alter session set use_cached_result = false;
select get_ddl('view', 'vw_secure_customer_v2');
