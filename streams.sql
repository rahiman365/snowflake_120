-- 1. Create the base table
CREATE OR REPLACE TABLE users (
    user_id       NUMBER AUTOINCREMENT PRIMARY KEY,
    first_name    VARCHAR(50),
    last_name     VARCHAR(50),
    email         VARCHAR(100),
    signup_date   DATE,
    status        VARCHAR(20),
    last_updated  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 2. Insert some sample data
INSERT INTO users (first_name, last_name, email, signup_date, status)
VALUES
    ('Alice', 'Sharma', 'alice.sharma@example.com', '2026-01-10', 'ACTIVE'),
    ('Ravi', 'Kumar', 'ravi.kumar@example.com', '2026-02-15', 'ACTIVE'),
    ('Meera', 'Patel', 'meera.patel@example.com', '2026-03-01', 'INACTIVE');

select * from users;
-- 3. Create a stream on the table to capture changes
CREATE OR REPLACE STREAM users_stream ON TABLE users;



select * from users_stream;
--drop stream users_stream;

-- 4. Make some changes to generate stream data
UPDATE users SET status = 'INACTIVE' WHERE user_id = 1;

INSERT INTO users (first_name, last_name, email, signup_date, status)
VALUES ('Karan', 'Verma', 'karan.verma@example.com', '2026-08-01', 'ACTIVE');

INSERT INTO users (first_name, last_name, email, signup_date, status)
VALUES ('Abdul', 'Rahiman', 'Abdul.rahiman@example.com', '2026-08-01', 'ACTIVE');

DELETE FROM users WHERE user_id = 3;

-- 5. Query the stream to see the changes (CDC output)
SELECT * FROM users_stream;

-- 1. Create the history table
CREATE OR REPLACE TABLE users_history (
    user_id       NUMBER PRIMARY KEY,
    first_name    VARCHAR(50),
    last_name     VARCHAR(50),
    email         VARCHAR(100),
    signup_date   DATE,
    status        VARCHAR(20),
    last_updated  TIMESTAMP_NTZ
);

-- 2. Initial load (optional, if you want history to start in sync with users)
INSERT INTO users_history
SELECT user_id, first_name, last_name, email, signup_date, status, last_updated
FROM users;

select * from users_history;

-- 3. Merge changes from the stream into users_history
MERGE INTO users_history AS tgt
USING users_stream AS src
ON tgt.user_id = src.user_id
WHEN MATCHED AND src.METADATA$ACTION = 'DELETE' AND src.METADATA$ISUPDATE = FALSE THEN
    DELETE
WHEN MATCHED AND src.METADATA$ACTION = 'INSERT'  THEN
    UPDATE SET
        tgt.first_name   = src.first_name,
        tgt.last_name    = src.last_name,
        tgt.email        = src.email,
        tgt.signup_date  = src.signup_date,
        tgt.status       = src.status,
        tgt.last_updated = src.last_updated
WHEN NOT MATCHED AND src.METADATA$ACTION = 'INSERT' THEN
    INSERT (user_id, first_name, last_name, email, signup_date, status, last_updated)
    VALUES (src.user_id, src.first_name, src.last_name, src.email, src.signup_date, src.status, src.last_updated);

-- 4. Verify
SELECT * FROM users_history ORDER BY user_id;
