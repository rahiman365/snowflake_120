-- Create two roles to demonstrate different visibility
create role if not exists pii_admin;
create role if not exists analyst_role;

-- Grant them usage on your database/schema/warehouse
grant usage on database DBT_PROJECT to role pii_admin;
grant usage on database DBT_PROJECT to role analyst_role;
grant usage on schema DBT_PROJECT.dbt to role pii_admin;
grant usage on schema DBT_PROJECT.dbt to role analyst_role;
grant select on all tables in schema DBT_PROJECT.dbt to role pii_admin;
grant select on all tables in schema DBT_PROJECT.dbt to role analyst_role;

-- Assign roles to your current user for testing
grant role pii_admin to user rahiman365;
grant role analyst_role to user rahiman365;

select * from DBT_PROJECT.DBT.DIM_CUSTOMER;

create or replace masking policy mask_email_full as (val string) returns string -> case when current_role() in ('PII_ADMIN') then val else 'X@XXX.COM' end;

alter table dim_customer modify column email set masking policy mask_email_full;

use role analyst_role; 

select customer_id, email from dim_customer;  --nulls are appeared

select * from table(information_schema.policy_references(policy_name => 'mask_email_full'));


/*
-- Step 1: detach the policy from the column
alter table DBT_PROJECT.DBT.DIM_CUSTOMER modify column email unset masking policy;

-- Step 2: now you can safely recreate it
create or replace masking policy mask_email_full as (val string) returns string ->
    case when current_role() in ('PII_ADMIN') then val else 'NULL' end;

-- Step 3: reattach
alter table DBT_PROJECT.DBT.DIM_CUSTOMER modify column email set masking policy mask_email_full;
*/
