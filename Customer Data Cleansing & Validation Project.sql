DROP TABLE IF EXISTS customer_data_raw;

CREATE TABLE customer_data_raw (
    customer_id INT,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    gender VARCHAR(20),
    email VARCHAR(100),
    phone VARCHAR(30),
    city VARCHAR(50),
    state VARCHAR(50),
    signup_date VARCHAR(30),
    customer_status VARCHAR(30)
);
--Insert some data

INSERT INTO customer_data_raw
VALUES

(101, 'Sravya', 'Thotakuri', 'Female',
 'SRAVYA@GMAIL.COM ', '512-765-5047',
 'Dallas ', 'TX', '2022-05-10', 'Active'),

(102, 'john ', 'smith', 'M',
 'JOHN.SMITH@GMAIL.COM', '(214)555-1234',
 'Austin', 'Texas', '05/15/2022', 'active'),

(103, 'MARY', 'JONES', 'F',
 'mary.jones@gmail.com ', '469 555 8877',
 'Houston', 'TX', '2022-06-01', 'ACTIVE'),

(104, 'David', 'Brown', 'Male',
 NULL, '972-555-9988',
 'Dallas', 'Texas', '2022-06-15', 'Inactive'),

(105, ' Lisa ', 'Taylor ', 'female',
 ' LISA@YAHOO.COM ', NULL,
 'Austin ', 'TX', '2022-07-01', 'active'),

(102, 'john ', 'smith', 'M',
 'JOHN.SMITH@GMAIL.COM', '(214)555-1234',
 'Austin', 'Texas', '05/15/2022', 'active'),

(106, 'Robert', 'Wilson', '',
 'robert@gmail.com', '817.555.2233',
 'Fort Worth', 'Texas', '2022-07-20', 'Active'),

(107, 'Jennifer', 'Clark', 'F',
 'jennifer@gmail.com', '7135554444',
 'Houston', 'TX', NULL, 'Inactive'),

(108, 'Michael ', 'Lee', 'male',
 'MICHAEL@GMAIL.COM ', '214 555 6677',
 ' Dallas', 'TX', '2022-08-10', NULL);

 SELECT *
FROM customer_data_raw;

--First count the rows:
SELECT COUNT(*)

--Create a staging table
DROP TABLE IF EXISTS customer_data_staging;

CREATE TABLE customer_data_staging AS
SELECT *
FROM customer_data_raw;

--Now Check
SELECT *
FROM customer_data_staging

--Find duplicate records using a CTE
WITH duplicate_cte AS
(
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY customer_id
               ORDER BY customer_id
           ) AS row_num
    FROM customer_data_staging
)

SELECT *
FROM duplicate_cte
WHERE row_num > 1;

--Remove duplicates using a CTE
WITH duplicate_cte AS
(
    SELECT ctid,
           ROW_NUMBER() OVER(
               PARTITION BY customer_id
               ORDER BY customer_id
           ) AS row_num
    FROM customer_data_staging
)

DELETE FROM customer_data_staging
WHERE ctid IN
(
    SELECT ctid
    FROM duplicate_cte
    WHERE row_num > 1
);
-- Now check again
SELECT *
FROM customer_data_staging;
--AND
SELECT COUNT(*)
FROM customer_data_staging;

--Remove extra spaces
UPDATE customer_data_staging
SET
    first_name = TRIM(first_name),
    last_name = TRIM(last_name),
    email = TRIM(email),
    phone = TRIM(phone),
    city = TRIM(city),
    state = TRIM(state),
    customer_status = TRIM(customer_status);

	SELECT *
FROM customer_data_staging;

--Standardize names
UPDATE customer_data_staging
SET
    first_name = INITCAP(first_name),
    last_name = INITCAP(last_name),
    city = INITCAP(city);
	--Check Now
	SELECT
    first_name,
    last_name,
    city
FROM customer_data_staging;

--Standardize email addresses

UPDATE customer_data_staging
SET email = LOWER(email);
SELECT
    customer_id,
    email
FROM customer_data_staging;

--Standardize gender
UPDATE customer_data_staging
SET gender =
    CASE
        WHEN LOWER(TRIM(gender)) IN ('m', 'male')
            THEN 'Male'

        WHEN LOWER(TRIM(gender)) IN ('f', 'female')
            THEN 'Female'

        WHEN gender IS NULL OR TRIM(gender) = ''
            THEN 'Unknown'

        ELSE gender
    END;
--CHeck Now
	SELECT DISTINCT gender
FROM customer_data_staging;

---Standardize state--
UPDATE customer_data_staging
SET state =
    CASE
        WHEN UPPER(TRIM(state)) IN ('TX', 'TEXAS')
            THEN 'TX'
        ELSE UPPER(TRIM(state))
    END;
	SELECT DISTINCT state
FROM customer_data_staging;

--Clean customer status--
UPDATE customer_data_staging
SET customer_status =
    CASE

        WHEN LOWER(customer_status) = 'active'
            THEN 'Active'

        WHEN LOWER(customer_status) = 'inactive'
            THEN 'Inactive'

        WHEN customer_status IS NULL
            THEN 'Unknown'

        ELSE INITCAP(customer_status)

    END;

	--Check
	SELECT DISTINCT customer_status
FROM customer_data_staging;

--Identify NULL values--
SELECT *
FROM customer_data_staging
WHERE email IS NULL
   OR phone IS NULL
   OR signup_date IS NULL;
   --To Count Nulls--

   SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE email IS NULL
    ) AS missing_email,

    COUNT(*) FILTER (
        WHERE phone IS NULL
    ) AS missing_phone,

    COUNT(*) FILTER (
        WHERE signup_date IS NULL
    ) AS missing_signup_date

FROM customer_data_staging;

--Handle missing emails--
SELECT
    customer_id,
    first_name,
    COALESCE(email, 'Email Not Available') AS email
FROM customer_data_staging;

--Clean phone numbers--
UPDATE customer_data_staging
SET phone =
    REGEXP_REPLACE(
        phone,
        '[^0-9]',
        '',
        'g'
    )
WHERE phone IS NOT NULL;
SELECT
    customer_id,
    phone
FROM customer_data_staging;

--Validate phone numbers--
SELECT *
FROM customer_data_staging
WHERE phone IS NOT NULL
AND LENGTH(phone) <> 10;

--Clean the dates--
ALTER TABLE customer_data_staging
ADD COLUMN clean_signup_date DATE;
--Now populate--
UPDATE customer_data_staging
SET clean_signup_date =
    CASE

        WHEN signup_date ~ '^\d{4}-\d{2}-\d{2}$'
            THEN TO_DATE(signup_date, 'YYYY-MM-DD')

        WHEN signup_date ~ '^\d{2}/\d{2}/\d{4}$'
            THEN TO_DATE(signup_date, 'MM/DD/YYYY')

        ELSE NULL

    END;
	--Now Check it--
	SELECT
    signup_date,
    clean_signup_date
FROM customer_data_staging;

--Identify invalid dates--
SELECT *
FROM customer_data_staging
WHERE signup_date IS NOT NULL
AND clean_signup_date IS NULL;

--Analyze duplicate emails--
SELECT
    email,
    COUNT(*) AS occurrence_count
FROM customer_data_staging
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1;

--Create another CTE for data quality
WITH data_quality_cte AS
(
    SELECT
        customer_id,
        first_name,
        last_name,
        email,
        phone,

        CASE
            WHEN email IS NULL
                THEN 'Missing Email'

            WHEN phone IS NULL
                THEN 'Missing Phone'

            WHEN clean_signup_date IS NULL
                THEN 'Missing Date'

            ELSE 'Complete'

        END AS data_quality_status

    FROM customer_data_staging
)

SELECT *
FROM data_quality_cte;


--Create the final clean table--

DROP TABLE IF EXISTS customer_data_clean;

CREATE TABLE customer_data_clean AS

SELECT
    customer_id,
    first_name,
    last_name,
    gender,
    email,
    phone,
    city,
    state,
    clean_signup_date AS signup_date,
    customer_status

FROM customer_data_staging;
--Now Check it--
SELECT *
FROM customer_data_clean;

--Validate raw vs cleaned data--
SELECT
    (SELECT COUNT(*)
     FROM customer_data_raw)
     AS raw_records,

    (SELECT COUNT(*)
     FROM customer_data_clean)
     AS cleaned_records;


	 --Final data-quality check--
	 SELECT
    COUNT(*) AS total_customers,

    COUNT(DISTINCT customer_id)
        AS unique_customers,

    COUNT(email)
        AS customers_with_email,

    COUNT(phone)
        AS customers_with_phone,

    COUNT(signup_date)
        AS customers_with_signup_date

FROM customer_data_clean;

--One complete CTE query --
WITH cleaned_customer_data AS
(
    SELECT
        customer_id,

        INITCAP(TRIM(first_name))
            AS first_name,

        INITCAP(TRIM(last_name))
            AS last_name,

        CASE
            WHEN LOWER(TRIM(gender))
                 IN ('m', 'male')
                THEN 'Male'

            WHEN LOWER(TRIM(gender))
                 IN ('f', 'female')
                THEN 'Female'

            ELSE 'Unknown'

        END AS gender,

        LOWER(TRIM(email))
            AS email,

        REGEXP_REPLACE(
            phone,
            '[^0-9]',
            '',
            'g'
        ) AS phone,

        INITCAP(TRIM(city))
            AS city,

        CASE
            WHEN UPPER(TRIM(state))
                 IN ('TX', 'TEXAS')
                THEN 'TX'

            ELSE UPPER(TRIM(state))

        END AS state

    FROM customer_data_staging
)

SELECT *
FROM cleaned_customer_data;
