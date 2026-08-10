create database project;
create schema test;
use database project;
use schema test;

CREATE WAREHOUSE TASK_WH
  WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;
--================================================

create database analytics;
create schema  test;

create or replace table customer_stage (id int, name varchar(50), address varchar(50));

--drop table customer_target;
CREATE OR REPLACE TABLE customer_target_scd1 (
    CUSTOMER_SK INT IDENTITY(10000001, 1),
    ID          INT,
    NAME        VARCHAR(50),
    ADDRESS     VARCHAR(50),
    UPDATED_AT  DATE
);

insert into customer_stage values
(1,'Abdul','Hyd'),
(2,'Rahiman','Banglore'),
(3,'ABC','Pune')
;

-- delta load , 1 new row
insert into customer_stage values
(4,'Akanksha','CHENNAI');

-- updating one previous row
update customer_stage set address = 'CHENNAI'
where id=1;

select current_date();

select * from customer_stage; -- raw layer 
---delete from customer_stage where id=4;
select * from customer_target_scd1 order by 1;




MERGE INTO customer_target_scd1 as TGT
USING customer_stage as SRC
 ON  TGT.ID = SRC.ID 

WHEN MATCHED AND (
TGT.NAME <> SRC.NAME OR
TGT.ADDRESS <> SRC.ADDRESS
)
THEN UPDATE SET 
            TGT.NAME = SRC.NAME,
            TGT.ADDRESS = SRC.ADDRESS,
            TGT.UPDATED_AT = CURRENT_DATE

WHEN NOT MATCHED THEN 
INSERT (TGT.ID, TGT.NAME, TGT.ADDRESS, TGT.UPDATED_AT)
VALUES (SRC.ID, SRC.NAME,SRC.ADDRESS, CURRENT_DATE)
;


------------------------
--- SCD 2 

create or replace table customer_stage_2 (id int, name varchar(50), address varchar(50));

insert into customer_stage_2 values
(1,'Abdul','Hyd'),
(2,'Rahiman','Banglore'),
(3,'ABC','Pune')
;

-- delta load , 1 new row
insert into customer_stage_2 values
(4,'Akanksha','CHENNAI');

-- updating one previous row
update customer_stage_2 set address = 'CHENNAI'
where id=1;



CREATE OR REPLACE TABLE customer_target_scd2 (
    CUSTOMER_SK INT IDENTITY(20000001, 1),
    ID          INT,
    NAME        VARCHAR(50),
    ADDRESS     VARCHAR(50),
    START_DATE DATE,
    END_DATE DATE,
    IS_CURRENT BOOLEAN
);

select * from customer_stage_2; -- raw layer 
---delete from customer_stage where id=4;
select * from customer_target_scd2 order by 1;


CREATE OR REPLACE PROCEDURE SP_CUSTOMER_TARGET_SCD2()
RETURNS STRING
LANGUAGE SQL 
AS
$$
BEGIN 

-- STEP 1
    MERGE INTO CUSTOMER_TARGET_SCD2 TGT
    USING CUSTOMER_STAGE_2 SRC
    ON TGT.ID = SRC.ID and TGT.IS_CURRENT = TRUE

    WHEN MATCHED AND (TGT.NAME <> SRC.NAME OR   --- UPDATING EXISTING ROWS
    TGT.ADDRESS <> SRC.ADDRESS)
    THEN UPDATE SET 
                END_DATE = CURRENT_DATE,
                IS_CURRENT = FALSE

    WHEN NOT MATCHED THEN                        --- INSERTING NEW BRAND ROWS
