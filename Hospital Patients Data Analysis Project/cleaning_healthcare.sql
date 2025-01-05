-- The first thing we need to do is to join these tables using the appropriate keys.
-- But first, we need to do some minor cleaning on the column names to avoid data ambiguity

-- EncounterS table

SELECT *
FROM procedures;

-- Rename column name ï»¿Id to id

ALTER TABLE encounters
RENAME COLUMN ï»¿Id TO id;

ALTER TABLE encounters
RENAME COLUMN id TO id_encounter;

-- Rename column id in oganizations table

SELECT *
FROM organizations;

ALTER TABLE organizations
RENAME COLUMN Id TO Id_ORGANIZATION;

-- Rename column names in table patients
SELECT *
FROM patients;

ALTER TABLE patients
RENAME COLUMN ï»¿Id TO Id_PATIENTS;

ALTER TABLE patients
RENAME COLUMN FIRST TO FIRST_NAME,
RENAME COLUMN LAST TO LAST_NAME;


-- Rename column names in payers table

SELECT *
FROM payers;

ALTER TABLE payers
RENAME COLUMN Id TO PAYER_Id;

-- Rename column name in Procedures table
SELECT *
FROM procedures;

ALTER TABLE procedures
RENAME COLUMN ï»¿START TO PRO_START,
RENAME COLUMN STOP TO PRO_STOP;


-- After renaming all columns, we then need to join using INNER JOIN to return all rows that match in the table
-- To join, we have to note the relationships between the target tables
-- 1. Encounter, patients,organization & payers tables all have similar relationship, we need to join them based on the primary and foreign key.


SELECT en.id_encounter, pt.Id_PATIENTS, pt.FIRST_NAME, pt.LAST_NAME, pt.BIRTHDATE, pt.DEATHDATE, pt.RACE, pt.GENDER, pt.STATE, pt.COUNTY,
    org.ORG_NAME, py.PAY_NAME, en.START, en.STOP, en.BASE_ENCOUNTER_COST, en.TOTAL_CLAIM_COST, en.PAYER_COVERAGE
        
FROM encounters en
INNER JOIN organizations org
    ON 
        en.ORGANIZATION = org.Id_ORGANIZATION
INNER JOIN patients pt
    ON 
        en.PATIENT = pt.Id_PATIENTS
INNER JOIN payers py
    ON 
        en.PAYER = py.PAYER_Id;

-- The next step is to save the joined tables into a newly created table

CREATE TABLE final_encounter
-- Using a CTE
WITH new_table AS (
    SELECT en.id_encounter, pt.Id_PATIENTS, pt.FIRST_NAME, pt.LAST_NAME, pt.BIRTHDATE, pt.DEATHDATE, pt.RACE, pt.GENDER, pt.STATE, pt.COUNTY,
    org.ORG_NAME, py.PAY_NAME, en.START, en.STOP, en.BASE_ENCOUNTER_COST, en.TOTAL_CLAIM_COST, en.PAYER_COVERAGE
        
FROM encounters en
INNER JOIN organizations org
    ON 
        en.ORGANIZATION = org.Id_ORGANIZATION
INNER JOIN patients pt
    ON 
        en.PATIENT = pt.Id_PATIENTS
INNER JOIN payers py
    ON 
        en.PAYER = py.PAYER_Id
)
SELECT *
FROM new_table;


-- STEP 1: Data Staging - the process of preparing and organizing data before it's moved to its final destination

CREATE TABLE staged_final_encounter
LIKE final_encounter;

-- Query testing
SELECT *
FROM staged_final_encounter;

INSERT staged_final_encounter
SELECT *
FROM final_encounter;

-- Query testing
SELECT *
FROM staged_final_encounter;


-------------------------------------------------------------------------------------------------

-- Data Cleaning:
-- 1. Check and remove duplicates
-- 2. Data type conversion
-- 3. Data integrity/incosistency
-- 4. Data standardization

-------------------------------------------------------------------------------------------------

-- 1. Check and remove duplicates if any
-- Using Windows Function Row_number()

SELECT *,
    ROW_NUMBER() OVER(PARTITION BY id_encounter, Id_PATIENTS, FIRST_NAME, LAST_NAME,
        BIRTHDATE, DEATHDATE, RACE, GENDER, STATE, COUNTY, ORG_NAME, PAY_NAME, START, STOP, BASE_ENCOUNTER_COST, TOTAL_CLAIM_COST, PAYER_COVERAGE) row_num
FROM staged_final_encounter;

-- To filter the newly created column 'row_num', we need to pass it into a CTE

WITH new_row AS(
    SELECT *,
    ROW_NUMBER() OVER(PARTITION BY id_encounter, Id_PATIENTS, FIRST_NAME, LAST_NAME,
        BIRTHDATE, DEATHDATE, RACE, GENDER, STATE, COUNTY, ORG_NAME, PAY_NAME, START, STOP, BASE_ENCOUNTER_COST, TOTAL_CLAIM_COST, PAYER_COVERAGE) row_num
FROM staged_final_encounter
)
SELECT *
FROM new_row
WHERE row_num > 2;

-- 2. Data Inconsistency
SELECT *
FROM staged_final_encounter;

-- We could have used this method of data cleaning to delete the last three letters but we noticed some of the
-- texts have 3 and 2 digits at the end of each strings e.g joe123 -> joe, joe12 -> jo
-- LEFT(FIRST_NAME, LENGTH(FIRST_NAME)-3), LEFT(LAST_NAME, LENGTH(LAST_NAME)-3)

-- The best method is to use a REGEXP_REPLACE function

SELECT REGEXP_REPLACE(FIRST_NAME, '[0-9]', ''), REGEXP_REPLACE(LAST_NAME, '[0-9]', '')
FROM staged_final_encounter;

-- Update -> we need to save our results by updating the columns

UPDATE staged_final_encounter
SET FIRST_NAME = REGEXP_REPLACE(FIRST_NAME, '[0-9]', ''), LAST_NAME = REGEXP_REPLACE(LAST_NAME, '[0-9]', '');

-- 3. Data type conversion

SELECT STR_TO_DATE(BIRTHDATE,'%Y-%m-%d'), STR_TO_DATE(DEATHDATE,'%Y-%m-%d')
FROM staged_final_encounter -- This query works but it gives an error when trying to update it because the columns contains empty strings/null values.

-- Update column
-- This gives us an error because we have NULL or empty strings in our column.
-- UPDATE staged_final_encounter
--SET BIRTHDATE = STR_TO_DATE(BIRTHDATE,'%Y-%m-%d'), DEATHDATE= STR_TO_DATE(DEATHDATE,'%Y-%m-%d');

SELECT BIRTHDATE,DEATHDATE
FROM staged_final_encounter;

START TRANSACTION
UPDATE staged_final_encounter
SET 
    BIRTHDATE = CASE 
                  WHEN BIRTHDATE != '' THEN STR_TO_DATE(BIRTHDATE, '%Y-%m-%d') 
                  ELSE NULL 
                END, 
    DEATHDATE = CASE 
                  WHEN DEATHDATE != '' THEN STR_TO_DATE(DEATHDATE, '%Y-%m-%d') 
                  ELSE NULL 
                END;
ROLLBACK;

UPDATE staged_final_encounter
SET 
    BIRTHDATE = CASE 
                  WHEN BIRTHDATE != '' THEN STR_TO_DATE(BIRTHDATE, '%Y-%m-%d') 
                  ELSE 'NOT GIVEN' 
                END, 
    DEATHDATE = CASE 
                  WHEN DEATHDATE != '' THEN STR_TO_DATE(DEATHDATE, '%Y-%m-%d') 
                  ELSE 'NOT GIVEN' 
                END;

-- The next thing to do is change the data type from text to data.



UPDATE staged_final_encounter
SET 
    DEATHDATE = CASE 
                  WHEN DEATHDATE != '' THEN STR_TO_DATE(DEATHDATE, '%Y-%m-%d') 
                  WHEN DEATHDATE = '' THEN 'NOT GIVEN'
                END;


ALTER TABLE staged_final_encounter
MODIFY BIRTHDATE DATE;

SELECT *
FROM staged_final_encounter
;

-- Moving to the next columns 'START' and 'STOP', the column are in text but actually they need to be in datetime format

SELECT *
FROM staged_final_encounter;

-- This sets of query give an error because the str_to_date function does not recognise the 'Z' time zone
-- UPDATE staged_final_encounter
-- SET START = STR_TO_DATE(START, '%Y-%m-%dT%H:%i:%s'), STOP = STR_TO_DATE(STOP, '%Y-%m-%dT%H:%i:%s');


-- T fix this, we need to remove the timezone for this to work properly
UPDATE staged_final_encounter
SET 
    START = STR_TO_DATE(REPLACE(START, 'Z', ''), '%Y-%m-%dT%H:%i:%s'),
    STOP = STR_TO_DATE(REPLACE(STOP, 'Z', ''), '%Y-%m-%dT%H:%i:%s');

ALTER TABLE staged_final_encounter
MODIFY START DATETIME,
MODIFY STOP DATETIME;

--------------------------------------------------------------------

-- We now have to link the procedures table with patients and encounter table

CREATE TABLE final_procedures
WITH new_pro AS(
    SELECT pt.FIRST_NAME, pt.LAST_NAME,pt.GENDER,pt.COUNTY, en.id_encounter, pro.PATIENT, pro.PRO_START, pro.PRO_STOP, pro.BASE_COST
    FROM procedures pro
    INNER JOIN patients pt 
        ON
            pro.PATIENT = pt.Id_PATIENTS
    INNER JOIN encounters en
        ON
            pro.ENCOUNTER = en.id_encounter
)
SELECT *
FROM new_pro;

SELECT *
FROM final_procedures;

-- Data Cleaning process
-- Data Staging

CREATE TABLE staged_final_procedures
LIKE final_procedures;

INSERT staged_final_procedures
SELECT *
FROM final_procedures;

SELECT *
FROM staged_final_procedures;

-- Data Cleaning: Remove all digits from text string
UPDATE staged_final_procedures
SET FIRST_NAME = REGEXP_REPLACE(FIRST_NAME, '[0-9]', ''), LAST_NAME = REGEXP_REPLACE(LAST_NAME, '[0-9]', '');


-- Data type conversion: Text to datetime

UPDATE staged_final_procedures
SET PRO_START = STR_TO_DATE(REPLACE(`PRO_START`, 'Z', ''), '%Y-%m-%dT%H:%i:%s'),
    `PRO_STOP` = STR_TO_DATE(REPLACE(`PRO_STOP`, 'Z', ''), '%Y-%m-%dT%H:%i:%s');

ALTER TABLE staged_final_procedures
MODIFY PRO_START DATETIME,
MODIFY PRO_STOP DATETIME;


SELECT *
FROM staged_final_procedures