show tables;

create role if not exists south_region_role;
create role if not exists north_region_role;

grant usage on database DBT_PROJECT to role south_region_role;
grant usage on database DBT_PROJECT to role north_region_role;
grant usage on schema DBT_PROJECT.dbt to role south_region_role;
grant usage on schema DBT_PROJECT.dbt to role north_region_role;
grant select on all tables in schema DBT_PROJECT.dbt to role south_region_role;
grant select on all tables in schema DBT_PROJECT.dbt to role north_region_role;

grant role south_region_role to user rahiman365;
grant role north_region_role to user rahiman365;

create or replace table region_access_map (
    role_name string,
    region string
);

insert into region_access_map values
    ('SOUTH_REGION_ROLE', 'South'),
    ('NORTH_REGION_ROLE', 'North');

create or replace row access policy region_policy
as (region string) returns boolean ->
    exists (
        select 1
        from region_access_map
        where role_name = current_role()
          and region_access_map.region = region
    )
or current_role() = 'ACCOUNTADMIN';-- admins always see everything


    alter table DBT_PROJECT.DBT.DIM_LOCATION_current
    add row access policy region_policy on (region);

    use role accountadmin;
select * from dim_location_current;
-- sees all 5 rows: South, West, South, North, South

use role south_region_role;
select * from dim_location_current;

use role north_region_role;
select * from dim_location_current;
