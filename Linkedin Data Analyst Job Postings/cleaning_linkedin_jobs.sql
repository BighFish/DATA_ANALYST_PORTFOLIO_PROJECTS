SELECT *
FROM data_analyst_jobs;


SELECT DISTINCT `Job Title`, `Required Skills`
FROM data_analyst_jobs
WHERE `Job Title` = "Online Data Analyst";


--- Data Cleaning Process--

-- Step 1: Data Staging


SELECT *
FROM data_analyst_jobs;

CREATE TABLE staged_jobs
LIKE data_analyst_jobs;


INSERT staged_jobs
SELECT *
FROM data_analyst_jobs;

-- Query Testing

SELECT *
FROM staged_jobs;

-- Step 2: Check for data inconsistencies e.g 'Salary Column'

SELECT REPLACE(REPLACE(Salary, 'â‚¬', '£'), 'Â', '') AS fixed_salary
FROM staged_jobs;

-- UPDATE the Salary column
UPDATE staged_jobs
SET `Salary`= REPLACE(REPLACE(Salary, 'â‚¬', '£'), 'Â', '');

-- Data type conversion: The "Date Posted" column has a TEXT data type instead of DATE. To fix this;
-- 1. We first of all use the STR_TO_DATE Function to check if the "Date Posted" column has the same date format, running this query helps satisfy our curiosity.
SELECT STR_TO_DATE(`Date Posted`, '%Y-%m-%d')
FROM staged_jobs;

-- 2. The "Date Posted column" has the same date format all through the data meaning it's in the format YMD. All we have to do is modify the "Date Posted" column from TEXT to DATE data type

ALTER TABLE staged_jobs
MODIFY `Date Posted` DATE;


-- Step 3: Diplicate values
-- For curiosity, we have to check if we have values that existed more than once in the dataset.
-- To do this, we use WINDOW FUNCTION (ROW_NUMBER) and a CTE.

-- This query partitions each column by giving a unique identifier to each rows, if a row exists more than once it shows how many times the row exists in the dataset.
-- We use the WHERE clause to filter dup_rows > 1 to detect duplicate job postings.
WITH duplicate_jobs AS(

    SELECT *,
    ROW_NUMBER() OVER(PARTITION BY Company, Applicants, `Date Posted`, `Easy Apply`, `Experience Level`, `Job Title`, Location, Remote, `Required Skills`, Salary) dup_rows
    FROM staged_jobs
) 
SELECT *
FROM duplicate_jobs
WHERE dup_rows > 1;
-- Query Testing

SELECT *
FROM staged_jobs;

