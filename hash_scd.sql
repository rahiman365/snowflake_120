CREATE OR REPLACE TABLE customer_target_hash_scd1 (
    CUSTOMER_SK INT IDENTITY(10000001, 1),
    ID          INT,
    NAME        VARCHAR(50),
    ADDRESS     VARCHAR(50),
    KEY_HASH    VARCHAR(32),   -- MD5 hash of key column(s)
    ROW_HASH   VARCHAR(32),   -- MD5 hash of non-key columns
    UPDATED_AT  DATE
);

select * from customer_target_hash_scd1;


    SELECT
        ID,
        NAME,
        ADDRESS,
        MD5(CAST(ID AS VARCHAR))                                   AS KEY_HASH,
        MD5(CONCAT_WS('||', COALESCE(NAME,''), COALESCE(ADDRESS,''))) AS ROW_HASH
    FROM customer_stage;


select * from customer_stage;
-- 1 c4ca4238a0b923820dcc509a6f75849b	0ed6a556f9a92d0194f5354a4864ffa6
CREATE OR REPLACE TABLE customer_stage (id INT, name VARCHAR(50), address VARCHAR(50));

INSERT INTO customer_stage VALUES
(1,'Abdul','Hyd'),
(2,'Rahiman','Banglore'),
(3,'ABC','Pune');

-- delta load: 1 new row
INSERT INTO customer_stage VALUES (4,'Akanksha','CHENNAI');

-- update existing row
UPDATE customer_stage SET address = 'CHENNAI' WHERE id = 1;


MERGE INTO customer_target_hash_scd1 AS TGT
USING (
    SELECT
        ID,
        NAME,
        ADDRESS,
        MD5(CAST(ID AS VARCHAR))                                   AS KEY_HASH,
        MD5(CONCAT_WS('||', COALESCE(NAME,''), COALESCE(ADDRESS,''))) AS ROW_HASH
    FROM customer_stage
) AS SRC
   ON TGT.KEY_HASH = SRC.KEY_HASH
WHEN MATCHED AND TGT.ROW_HASH <> SRC.ROW_HASH THEN     -- one comparison covers ALL attributes
UPDATE SET
    TGT.NAME       = SRC.NAME,
    TGT.ADDRESS    = SRC.ADDRESS,
    TGT.ROW_HASH  = SRC.ROW_HASH,
    TGT.UPDATED_AT = CURRENT_DATE()
WHEN NOT MATCHED THEN
INSERT (ID, NAME, ADDRESS, KEY_HASH, ROW_HASH, UPDATED_AT)
VALUES (SRC.ID, SRC.NAME, SRC.ADDRESS, SRC.KEY_HASH, SRC.ROW_HASH, CURRENT_DATE());
