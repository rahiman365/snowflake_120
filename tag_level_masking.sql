/* =====================================================================
   BDC_ID TAG-BASED MASKING (ServiceNow approval -> role grant -> data visible)

   Flow:
     1. Every column is tagged with a BDC_ID (e.g. '1001').
     2. A masking policy is attached to the TAG (one policy per data type).
     3. The policy builds a role name from the tag value:
            BDC_ID '1001'  ->  role BDC_1001_ROLE
     4. If the user has that role -> real value, otherwise -> real SQL NULL.
     5. ServiceNow approval = "GRANT ROLE BDC_<id>_ROLE TO USER <requester>".

   NOTE: Replace MY_DB / MY_SCHEMA / MY_WH / JOHN with your own names.
         Tag-based masking requires Snowflake Enterprise Edition or higher.
   ===================================================================== */


/* ---------------------------------------------------------------------
   0. CONTEXT
   --------------------------------------------------------------------- */
use role accountadmin;               -- or a role that owns the objects
use warehouse compute_wh;

create database my_db;
create schema my_schema;
use database my_db;
use schema my_schema;


/* ---------------------------------------------------------------------
   1. CREATE TABLE AND INSERT DATA
   --------------------------------------------------------------------- */
create or replace table emp (
  emp_id    number,
  emp_name  varchar,
  dept      varchar,
  salary    number(10,2),
  hire_date date
);

insert into emp values
  (1,  'Asha Rao',        'HR',      55000, '2019-03-15'),
  (2,  'Ravi Kumar',      'IT',      72000, '2018-07-01'),
  (3,  'Meena Iyer',      'Finance', 68000, '2020-01-20'),
  (4,  'Suresh Reddy',    'IT',      81000, '2017-11-05'),
  (5,  'Priya Nair',      'HR',      52000, '2021-06-10'),
  (6,  'Karthik Sharma',  'Sales',   60000, '2019-09-25'),
  (7,  'Divya Menon',     'Finance', 75000, '2016-04-12'),
  (8,  'Arjun Patel',     'Sales',   58000, '2022-02-14'),
  (9,  'Lakshmi Devi',    'IT',      90000, '2015-08-30'),
  (10, 'Vikram Singh',    'Ops',     47000, '2023-01-09');

select * from emp order by emp_id;


/* ---------------------------------------------------------------------
   2. CREATE THE BDC_ID TAG
   --------------------------------------------------------------------- */
create or replace tag bdc_id
  comment = 'BDC ID that governs access to this column';


/* ---------------------------------------------------------------------
   3. MASKING POLICIES THAT READ THE BDC_ID TAG VALUE
      - One policy per data type (return type must match column type).
      - ELSE branch returns a real database NULL, not the text 'NULL'.
      - SYSTEM$GET_TAG_ON_CURRENT_COLUMN returns the tag value set on the
        column being queried (e.g. '1001').
      - Use the fully qualified tag name to avoid resolution issues.
   --------------------------------------------------------------------- */
create or replace masking policy mask_bdc_string as (val string) returns string ->
  case
    when is_role_in_session('ADMIN_ROLE') then val
    when is_role_in_session(
           'BDC_' || system$get_tag_on_current_column('MY_DB.MY_SCHEMA.BDC_ID') || '_ROLE'
         ) then val
    else null
  end;

create or replace masking policy mask_bdc_number as (val number) returns number ->
  case
    when is_role_in_session('ADMIN_ROLE') then val
    when is_role_in_session(
           'BDC_' || system$get_tag_on_current_column('MY_DB.MY_SCHEMA.BDC_ID') || '_ROLE'
         ) then val
    else null
  end;

create or replace masking policy mask_bdc_date as (val date) returns date ->
  case
    when is_role_in_session('ADMIN_ROLE') then val
    when is_role_in_session(
           'BDC_' || system$get_tag_on_current_column('MY_DB.MY_SCHEMA.BDC_ID') || '_ROLE'
         ) then val
    else null
  end;

-- Attach all three policies to the TAG (Snowflake picks the one matching
-- each column's data type automatically)
alter tag bdc_id set masking policy mask_bdc_string;
alter tag bdc_id set masking policy mask_bdc_number;
alter tag bdc_id set masking policy mask_bdc_date;


/* ---------------------------------------------------------------------
   4. TAG THE COLUMNS WITH BDC_ID
   --------------------------------------------------------------------- */

-- OPTION A: whole table under one BDC ID (columns inherit from the table).
--           Uncomment to use instead of Option B.
-- alter table emp set tag bdc_id = '1001';

-- OPTION B: different BDC IDs per column (more realistic).
--           A tag set directly on a column overrides the table-level tag.
alter table emp modify
  column emp_id    set tag bdc_id = '1001',
  column emp_name  set tag bdc_id = '1001',
  column dept      set tag bdc_id = '1001',
  column salary    set tag bdc_id = '1001',   -- needs a separate ServiceNow approval
  column hire_date set tag bdc_id = '1001';


/* ---------------------------------------------------------------------
   5. CREATE ROLES AND GRANT BASE ACCESS
      - ANALYST_ROLE : can SELECT the table but sees only NULLs
      - BDC_1001_ROLE / BDC_1002_ROLE : unlock columns tagged 1001 / 1002
        (these roles do NOT need SELECT on the table; they only unmask)
   --------------------------------------------------------------------- */
use role securityadmin;

create role if not exists admin_role;
create role if not exists analyst_role;
create role if not exists bdc_1001_role;
create role if not exists bdc_1002_role;

grant usage  on warehouse compute_wh                  to role analyst_role;
grant usage  on database  my_db                  to role analyst_role;
grant usage  on schema    my_db.my_schema        to role analyst_role;
grant select on table     my_db.my_schema.emp    to role analyst_role;


CREATE USER JOHN
    PASSWORD = 'John@Snow123'
    DEFAULT_ROLE = PUBLIC
    DEFAULT_WAREHOUSE = COMPUTE_WH
    MUST_CHANGE_PASSWORD = FALSE;
    
-- Test user gets only the base role at first
grant role analyst_role to user john;


/* ---------------------------------------------------------------------
   6. BEFORE APPROVAL: EVERYTHING IS NULL
   --------------------------------------------------------------------- */
grant role analyst_role to user rahiman365;
   
create role if not exists analyst_role;   -- sees fully masked data
use role analyst_role;

select * from emp order by emp_id;                 -- 10 rows, all columns NULL

-- Verify these are real NULLs, not the text 'NULL' (should return 10)
select count(*) as null_name_rows from emp where emp_name is null;


/* ---------------------------------------------------------------------
   7. AFTER SERVICENOW APPROVAL
      ServiceNow workflow (or an admin / stored procedure) runs this
      when the request for BDC ID 1001 is approved.
   --------------------------------------------------------------------- */
use role securityadmin;
grant role bdc_1001_role to user rahiman365;

-- John's session (secondary roles ALL lets BDC roles combine with ANALYST_ROLE)
use role analyst_role;
 use secondary roles all;
select * from emp order by emp_id;
--   -> emp_id, emp_name, dept, hire_date visible
--   -> salary still NULL until BDC 1002 is approved

-- Second approval (BDC 1002) unlocks salary:
-- use role securityadmin;
-- grant role bdc_1002_role to user john;


/* ---------------------------------------------------------------------
   8. REVOKE ACCESS (request closed / access expired)
   --------------------------------------------------------------------- */
-- use role securityadmin;
-- revoke role bdc_1001_role from user john;
-- revoke role bdc_1002_role from user john;


/* ---------------------------------------------------------------------
   9. USEFUL CHECKS
   --------------------------------------------------------------------- */
use role accountadmin;

-- Which columns carry the BDC_ID tag and with what value
select *
from table(my_db.information_schema.tag_references_all_columns('my_db.my_schema.emp', 'table'));

-- Which policies are attached to the tag
select *
from table(my_db.information_schema.policy_references(
  ref_entity_name   => 'my_db.my_schema.bdc_id',
  ref_entity_domain => 'tag'));

-- Which roles a user has
show grants to user john;




/* ---------------------------------------------------------------------
   NOTES FOR YOUR PROJECT
   - Role naming is the contract: BDC ID '1001' must map to BDC_1001_ROLE.
     If your project uses another convention, change the string
     concatenation inside the masking policies.
   - Automation: ServiceNow usually calls a stored procedure or a pipeline
     (REST / Jenkins / Airflow) that runs the GRANT ROLE after approval.
     Add an expiry step there to REVOKE the role automatically.
   - Alternative to roles: keep entitlements in a mapping table
     BDC_ACCESS(user_name, bdc_id, expiry_date) that ServiceNow updates,
     and have the policy check it with EXISTS (select 1 ...). Gives easy
     expiry and audit, but the policy queries a table on every read.
   - Masking returns rows with NULL values. If you want ZERO rows,
     use a row access policy instead.
   - A policy set directly on a column takes precedence over the tag-based one.
   - Unsupported types (some VARIANT/GEOGRAPHY cases) need a policy with a
     matching signature, otherwise they will not be masked.
   ===================================================================== */


/* =====================================================================
   10. CLEANUP (run in this order; dependencies matter)
   ===================================================================== */
use role accountadmin;
use database my_db;
use schema my_schema;

-- 10.1 Revoke the BDC roles from users
use role securityadmin;
revoke role bdc_1001_role from user john;
revoke role bdc_1002_role from user john;
revoke role analyst_role  from user john;

-- 10.2 Remove tags from the columns (and table, if Option A was used)
use role accountadmin;
alter table emp modify
  column emp_id    unset tag bdc_id,
  column emp_name  unset tag bdc_id,
  column dept      unset tag bdc_id,
  column salary    unset tag bdc_id,
  column hire_date unset tag bdc_id;

-- alter table emp unset tag bdc_id;      -- only if Option A was used

-- 10.3 Detach the masking policies from the tag
alter tag bdc_id unset masking policy mask_bdc_string;
alter tag bdc_id unset masking policy mask_bdc_number;
alter tag bdc_id unset masking policy mask_bdc_date;

-- 10.4 Drop the masking policies (must be detached first)
drop masking policy if exists mask_bdc_string;
drop masking policy if exists mask_bdc_number;
drop masking policy if exists mask_bdc_date;

-- 10.5 Drop the tag
drop tag if exists bdc_id;

-- 10.6 Drop the table
drop table if exists emp;

-- 10.7 Drop the roles
use role securityadmin;
drop role if exists bdc_1001_role;
drop role if exists bdc_1002_role;
drop role if exists analyst_role;
drop role if exists admin_role;           -- skip if ADMIN_ROLE is used elsewhere

-- 10.8 Confirm nothing is left
use role accountadmin;
show tables   like 'EMP';
show tags     like 'BDC_ID';
show masking policies like 'MASK_BDC%';
show roles    like 'BDC_%';
