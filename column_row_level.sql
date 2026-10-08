/* =====================================================================
   SNOWFLAKE DYNAMIC DATA MASKING + COLUMN-LEVEL SECURITY 
   ---------------------------------------------------------------------
   Requires: Enterprise edition or higher (masking policies, tags)
   Data    : 100% fake. Uses its own schema, so your dbt tables are untouched.

   Sections
     0. Setup (roles, warehouse, schema)
     1. Create + load sample tables
     2. Grants
     3. Create masking policies (email, phone, SSN, DOB, salary)
     4. Attach policies to columns
     5. Test as each role
     6. Inspect policies
     7. Change a policy safely (ALTER ... SET BODY, FORCE)
     8. Conditional masking (depends on another column)
     9. Tag-based masking (mask by classification, not by column)
    10. Gotchas worth demonstrating live
    11. Bonus: row access policy
    12. Cleanup
   ===================================================================== */


/* ---------------------------------------------------------------------
   0. SETUP  (run as ACCOUNTADMIN for the demo only; in real life use a
      dedicated governance role that owns policies)
   --------------------------------------------------------------------- */
use role accountadmin;

set my_user = 'RAHIMAN365';     -- <-- your Snowflake username
set wh      = 'COMPUTE_WH';     -- <-- your warehouse name

create database if not exists DYNAMIC_MASK;
create schema   if not exists DYNAMIC_MASK.MASKING_DEMO;
use schema DYNAMIC_MASK.MASKING_DEMO;

create role if not exists pii_admin;      -- sees everything
create role if not exists support_role;   -- sees partial data
create role if not exists analyst_role;   -- sees fully masked data


/* ---------------------------------------------------------------------
   1. SAMPLE DATA
   --------------------------------------------------------------------- */
create or replace table customers (
    customer_id        int,
    full_name          string,
    email              string,
    phone              string,
    ssn                string,
    date_of_birth      date,
    salary             number(10,2),
    region             string,
    marketing_consent  boolean,
    created_at         timestamp_ntz default current_timestamp()
);

insert into customers
    (customer_id, full_name, email, phone, ssn, date_of_birth, salary, region, marketing_consent)
values
    (1, 'Alice Johnson', 'alice.johnson@gmail.com', '415-555-0101', '123-45-6789', '1988-03-14', 125000.00, 'US',   true),
    (2, 'Bob Smith',     'bob.smith@outlook.com',   '212-555-0102', '234-56-7890', '1992-07-22',  98000.00, 'US',   false),
    (3, 'Carla Gomez',   'carla.gomez@company.io',  '305-555-0103', '345-67-8901', '1985-11-02', 143500.50, 'US',   true),
    (4, 'Deepak Rao',    'deepak.rao@yahoo.com',    '998-555-0104', '456-78-9012', '1990-01-30',  72000.00, 'APAC', true),
    (5, 'Emma Wilson',   'emma.w@proton.me',        '020-555-0105', '567-89-0123', '1995-06-18',  76000.00, 'EU',   true),
    (6, 'Farid Khan',    'farid.khan@gmail.com',    '044-555-0106', '678-90-1234', '1979-09-09', 210000.00, 'APAC', false),
    (7, 'Grace Lee',     'grace.lee@company.io',    '650-555-0107', '789-01-2345', '2000-12-25',  64000.00, 'US',   true),
    (8, 'Hans Muller',   null,                      null,           '890-12-3456', '1990-05-18',  88000.00, 'EU',   false);

-- A second table, used later for tag-based masking.
-- (Created BEFORE any policy exists so it holds the real values.)
create or replace table customers_archive as select * from customers;


/* ---------------------------------------------------------------------
   2. GRANTS
   --------------------------------------------------------------------- */
grant usage on warehouse identifier($wh)        to role pii_admin;
grant usage on warehouse identifier($wh)        to role support_role;
grant usage on warehouse identifier($wh)        to role analyst_role;

grant usage on database DYNAMIC_MASK             to role pii_admin;
grant usage on database DYNAMIC_MASK             to role support_role;
grant usage on database DYNAMIC_MASK             to role analyst_role;

grant usage on schema DYNAMIC_MASK.MASKING_DEMO  to role pii_admin;
grant usage on schema DYNAMIC_MASK.MASKING_DEMO  to role support_role;
grant usage on schema DYNAMIC_MASK.MASKING_DEMO  to role analyst_role;

grant select on all tables    in schema DYNAMIC_MASK.MASKING_DEMO to role pii_admin;
grant select on all tables    in schema DYNAMIC_MASK.MASKING_DEMO to role support_role;
grant select on all tables    in schema DYNAMIC_MASK.MASKING_DEMO to role analyst_role;
grant select on future tables in schema DYNAMIC_MASK.MASKING_DEMO to role pii_admin;
grant select on future tables in schema DYNAMIC_MASK.MASKING_DEMO to role support_role;
grant select on future tables in schema DYNAMIC_MASK.MASKING_DEMO to role analyst_role;

grant role pii_admin    to user identifier($my_user);
grant role support_role to user identifier($my_user);
grant role analyst_role to user identifier($my_user);


/* ---------------------------------------------------------------------
   3. MASKING POLICIES
      Rules: input type = output type, one policy per column at a time.
      Always handle NULL explicitly so NULLs stay NULL for admins.
      IS_ROLE_IN_SESSION respects role hierarchy (CURRENT_ROLE does not).
   --------------------------------------------------------------------- */
use role accountadmin;
use schema DYNAMIC_MASK.MASKING_DEMO;

-- EMAIL: admin = full, support = hide the name but keep the domain, others = fully masked
create or replace masking policy mask_email as (val string) returns string ->
    case
        when val is null                         then null
        when is_role_in_session('PII_ADMIN')     then val
        when is_role_in_session('SUPPORT_ROLE')  then regexp_replace(val, '^.+@', '*****@')
        else '*****@*****.com'
    end;

-- PHONE: support sees the last 4 digits only
create or replace masking policy mask_phone as (val string) returns string ->
    case
        when val is null                         then null
        when is_role_in_session('PII_ADMIN')     then val
        when is_role_in_session('SUPPORT_ROLE')  then '***-***-' || right(val, 4)
        else '***-***-****'
    end;

-- SSN: support sees the last 4, analysts see nothing
create or replace masking policy mask_ssn as (val string) returns string ->
    case
        when val is null                         then null
        when is_role_in_session('PII_ADMIN')     then val
        when is_role_in_session('SUPPORT_ROLE')  then '***-**-' || right(val, 4)
        else '***-**-****'
    end;

-- DATE OF BIRTH: support sees the year only (day/month snapped to Jan 1), analysts see NULL
create or replace masking policy mask_dob as (val date) returns date ->
    case
        when val is null                         then null
        when is_role_in_session('PII_ADMIN')     then val
        when is_role_in_session('SUPPORT_ROLE')  then date_trunc('year', val)
        else null
    end;

-- SALARY: admin only (numeric type must match the column exactly)
create or replace masking policy mask_salary as (val number(10,2)) returns number(10,2) ->
    case
        when is_role_in_session('PII_ADMIN')     then val
        else null
    end;


/* ---------------------------------------------------------------------
   4. ATTACH POLICIES TO COLUMNS
   --------------------------------------------------------------------- */
alter table customers modify column email         set masking policy mask_email;
alter table customers modify column phone         set masking policy mask_phone;
alter table customers modify column ssn           set masking policy mask_ssn;
alter table customers modify column date_of_birth set masking policy mask_dob;
alter table customers modify column salary        set masking policy mask_salary;

-- Remember: the stored data is NOT changed. Masking happens at query time.


/* ---------------------------------------------------------------------
   5. TEST AS EACH ROLE
      IMPORTANT: turn off secondary roles. Your user holds all three roles,
      and with secondary roles active IS_ROLE_IN_SESSION can return TRUE for
      PII_ADMIN even while your primary role is ANALYST_ROLE, so you would
      wrongly see unmasked data.
   --------------------------------------------------------------------- */
use secondary roles none;

use role pii_admin;
select * from customers order by customer_id;      -- everything visible

use role support_role;
select * from customers order by customer_id;      -- partial masking

use role analyst_role;
select * from customers order by customer_id;      -- fully masked

-- Moment: ACCOUNTADMIN is NOT in the policy, so it sees masked data too.
-- Being powerful and being allowed to see PII are separate things.
use role accountadmin;
select customer_id, email, ssn, salary from customers order by customer_id;


/* ---------------------------------------------------------------------
   6. INSPECT WHERE POLICIES ARE USED
   --------------------------------------------------------------------- */
use role accountadmin;
show masking policies in schema DYNAMIC_MASK.MASKING_DEMO;
describe masking policy mask_email;

select policy_name, ref_column_name, policy_status
from table(DYNAMIC_MASK.information_schema.policy_references(
        ref_entity_name   => 'DYNAMIC_MASK.MASKING_DEMO.CUSTOMERS',
        ref_entity_domain => 'TABLE'));

-- Or find every column a given policy protects:
select ref_entity_name, ref_column_name
from table(DYNAMIC_MASK.information_schema.policy_references(
        policy_name => 'DYNAMIC_MASK.MASKING_DEMO.MASK_EMAIL'));


/* ---------------------------------------------------------------------
   7. CHANGING A POLICY SAFELY
      You do NOT need to unset -> create or replace -> reattach.
      ALTER ... SET BODY edits the policy in place, even while attached.
   --------------------------------------------------------------------- */
-- Example: analysts get a deterministic hash instead of a constant, so they can
-- still count distinct customers and join on email without ever seeing it.
alter masking policy mask_email set body ->
    case
        when val is null                         then null
        when is_role_in_session('PII_ADMIN')     then val
        when is_role_in_session('SUPPORT_ROLE')  then regexp_replace(val, '^.+@', '*****@')
        else sha2(val)
    end;

use role analyst_role;
select customer_id, email from customers order by customer_id;   -- hashes now
select count(distinct email) as distinct_emails from customers;   -- works on hashes

use role accountadmin;


/* ---------------------------------------------------------------------
   8. CONDITIONAL MASKING (decision depends on ANOTHER column)
      Show the email only if the customer gave marketing consent.
   --------------------------------------------------------------------- */
create or replace masking policy mask_email_consent
    as (email string, consent boolean) returns string ->
    case
        when email is null                       then null
        when is_role_in_session('PII_ADMIN')     then email
        when consent                             then email
        else '*****@*****.com'
    end;

-- FORCE swaps the policy on a column in one step (no unset needed)
alter table customers modify column email
    set masking policy mask_email_consent using (email, marketing_consent) force;

use role analyst_role;
select customer_id, email, marketing_consent from customers order by customer_id;

use role accountadmin;
-- Switch back to the simple policy
alter table customers modify column email set masking policy mask_email force;


/* ---------------------------------------------------------------------
   9. TAG-BASED MASKING
      Tag a column once and it is masked automatically.
      Scales far better than attaching policies column by column.
   --------------------------------------------------------------------- */
create or replace tag pii_email_tag comment = 'Columns that contain email addresses';

-- Attach the policy to the TAG (one policy per data type per tag)
alter tag pii_email_tag set masking policy mask_email;

-- Tag the column; no direct policy needed on customers_archive
alter table customers_archive modify column email set tag pii_email_tag = 'email';

use role analyst_role;
select customer_id, email from customers_archive order by customer_id;   -- masked via tag

use role accountadmin;


/* ---------------------------------------------------------------------
   10. GOTCHAS - good points
   --------------------------------------------------------------------- */
use role analyst_role;

-- (a) Filtering on a masked column: the predicate sees the MASKED value
select count(*) from customers where email = 'alice.johnson@gmail.com';   -- 0

-- (b) CTAS copies the masked values, so masking can't be bypassed this way
--     (give analysts a schema they can write to if you want to try it)
-- create table my_copy as select * from customers;

-- (c) Aggregates on a NULL-masked column: SUM(salary) is NULL, AVG ignores NULLs
select sum(salary) as total_salary, count(salary) as visible_salaries from customers;

use role accountadmin;

-- (d) CREATE OR REPLACE TABLE (what dbt does on full refresh) DROPS the policy
--     attachments, so re-apply policies via a dbt post-hook or tag-based masking.

-- (e) A masking policy that is still attached cannot be dropped. Unset it first:
alter table customers modify column salary unset masking policy;


/* ---------------------------------------------------------------------
--  ROW ACCESS POLICY (row-level security, the sibling of masking)
       Each role sees only the regions it is mapped to.
   --------------------------------------------------------------------- */
create or replace table region_access (role_name string, region string);
insert into region_access values
    ('ANALYST_ROLE', 'US'),
    ('SUPPORT_ROLE', 'EU'),
    ('SUPPORT_ROLE', 'APAC');

create or replace row access policy region_rap as (row_region string) returns boolean ->
    is_role_in_session('PII_ADMIN')
    or exists (
        select 1 from region_access ra
        where ra.role_name = current_role()
          and ra.region    = row_region
    );

alter table customers add row access policy region_rap on (region);

use role analyst_role;
select customer_id, region, email from customers order by customer_id;   -- US rows only

use role support_role;
select customer_id, region, email from customers order by customer_id;   -- EU + APAC rows

use role pii_admin;
select customer_id, region, email from customers order by customer_id;   -- all rows

use role accountadmin;
alter table customers drop row access policy region_rap;


/* ---------------------------------------------------------------------
   12. CLEANUP (uncomment to reset the demo)
   --------------------------------------------------------------------- */
-- You can uncomment them by CTRL + /

-- use role accountadmin;
-- alter tag pii_email_tag unset masking policy mask_email;
-- drop tag if exists pii_email_tag;
-- drop table if exists customers;
-- drop table if exists customers_archive;
-- drop table if exists region_access;
-- drop masking policy if exists mask_email;
-- drop masking policy if exists mask_email_consent;
-- drop masking policy if exists mask_phone;
-- drop masking policy if exists mask_ssn;
-- drop masking policy if exists mask_dob;
-- drop masking policy if exists mask_salary;
-- drop row access policy if exists region_rap;
-- drop schema if exists DYNAMIC_MASK.MASKING_DEMO;
-- drop role if exists pii_admin;
-- drop role if exists support_role;
-- drop role if exists analyst_role;
