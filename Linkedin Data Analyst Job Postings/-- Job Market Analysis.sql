-- Active: 1734606262624@@localhost@3306@linkedin_jobs
-- Job Market Analysis

--1. Which companies receive the most applications?
--→ Helps identify the most attractive employers.

--2. Which job locations have the highest number of job postings?
--→ Reveals where data analyst jobs are most available.

--3. What percentage of jobs are remote vs. on-site?
--→ Indicates the trend in remote work opportunities.

--4. What are the most in-demand skills for data analyst roles?
--→ Helps job seekers focus on the right skill development.


---------------------------------------------------------------------------------------------

-- 1. Which companies receive the most applications?

SELECT Company, SUM(Applicants) AS cpr
FROM staged_jobs
GROUP BY Company
ORDER BY cpr DESC;

-- 2. Which job locations have the highest number of job postings?

SELECT Location,COUNT(*) AS No_postings
FROM staged_jobs
GROUP BY Location
ORDER BY No_postings DESC;

--3. What percentage of jobs are remote vs. on-site?

WITH remote_jobs AS (
    SELECT COUNT(*) AS Remote_jobs
    FROM staged_jobs
    WHERE Remote = 'Yes'
),
onsite_jobs AS (
    SELECT COUNT(*) AS Onsite_jobs
    FROM staged_jobs
    WHERE `Remote` = 'No'
),
Total_postings AS (
    SELECT COUNT(*) postings
    FROM staged_jobs
)
SELECT ROUND(Remote_jobs/postings*100) percent_remote, ROUND(Onsite_jobs/postings*100) percent_onsite
FROM remote_jobs,onsite_jobs,`Total_postings`;


-- 4. What are the most in-demand skills for data analyst roles?
WITH skills_extracted AS (
    SELECT TRIM(value) AS skill
    FROM staged_jobs,
    JSON_TABLE(
        CONCAT('["', REPLACE(`Required Skills`, ', ', '","'), '"]'),
        "$[*]" COLUMNS (value VARCHAR(255) PATH "$")
    ) AS skills
)
SELECT skill, COUNT(*) AS demand_count
FROM skills_extracted
GROUP BY skill
ORDER BY demand_count DESC
LIMIT 10;


--------------------------------------------------------------------------------------------------------------------------
-- Salary Insights

-- 1. What is the average salary for data analyst jobs?
-- → Gives insight into industry pay standards.

-- 2. How does salary vary by location?
-- → Helps understand regional differences in compensation.

-- 3. Do remote jobs offer higher or lower salaries than on-site jobs?
-- → Analyzes the trade-off between remote flexibility and pay.


-------------------------------------------------------------------------------------------------------------

-- 1. How does salary vary by location?

WITH salary_extracted AS (
    SELECT TRIM(value) AS salary_range, `Location`
    FROM staged_jobs,
    JSON_TABLE(
        CONCAT('["', REPLACE(`Salary`, '- ', '","'), '"]'),
        "$[*]" COLUMNS (value VARCHAR(255) PATH "$")
    ) AS new_salary
)
SELECT salary_range, COUNT(*) AS salary_count, `Location`
FROM salary_extracted
GROUP BY salary_range, `Location`
ORDER BY salary_count DESC;


-- 2. Do remote jobs offer higher or lower salaries than on-site jobs?

WITH salary_extracted AS (
    SELECT TRIM(value) AS salary_range, `Remote`
    FROM staged_jobs,
    JSON_TABLE(
        CONCAT('["', REPLACE(`Salary`, '- ', '","'), '"]'),
        "$[*]" COLUMNS (value VARCHAR(255) PATH "$")
    ) AS new_salary
)
SELECT 
    `Remote`, 
    AVG(salary_count) AS average_salary_count
FROM (
    SELECT salary_range, COUNT(*) AS salary_count, `Remote`
    FROM salary_extracted
    -- WHERE `Remote` IN ('Yes', 'No')
    GROUP BY salary_range, `Remote`
) AS salary_counts
GROUP BY `Remote`;

----------------------------------------------------------------------------------------------
-- Candidate Behavior

-- 1. Which job postings receive the most applications?
-- → Determines what attracts applicants (e.g., salary, remote work, top companies).

-- 2.Is there a correlation between required skills and number of applications?
-- → Reveals if certain skills make jobs more competitive.

-- 3. How do experience levels affect job postings and applications?
-- → Checks if more experienced roles receive fewer applications.

-- /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\


-- 1. Which job postings receive the most applications?
SELECT `Company`,Location,SUM(`Applicants`) cpr, COUNT(*) AS No_postings, `Salary`,`Remote`
FROM staged_jobs
GROUP BY Location, `Company`, `Salary`,`Remote`
ORDER BY  cpr DESC;


-- 2.Is there a correlation between required skills and number of applications?
WITH skills_extracted AS (
    SELECT TRIM(value) AS skill,`Applicants`
    FROM staged_jobs,
    JSON_TABLE(
        CONCAT('["', REPLACE(`Required Skills`, ', ', '","'), '"]'),
        "$[*]" COLUMNS (value VARCHAR(255) PATH "$")
    ) AS skills
)
SELECT skill, COUNT(*) AS demand_count, SUM(`Applicants`)
FROM skills_extracted
GROUP BY skill
ORDER BY demand_count DESC;



-- 3. How do experience levels affect job postings and applications?
SELECT DISTINCT`Experience Level`, SUM(`Applicants`) Total_Applicants
FROM staged_jobs
GROUP BY `Experience Level`
ORDER BY Total_Applicants DESC;


WITH weekend_weekday AS(
    SELECT DAYNAME(`Date Posted`) AS day_name,
    CASE 
    WHEN DAYNAME(`Date Posted`) IN ('Monday','Tuesday','Wednesday','Thursday','Friday')  THEN 'WEEKDAY'  
    ELSE  'WEEKEND'
    END AS Day_of_week, SUM(`Applicants`) AS Total_Applied
    FROM staged_jobs
    GROUP BY Day_of_week, day_name
),

when_weekend AS (
    SELECT (Total_Applied - Day_of_week) AS Total_weekend
    FROM weekend_weekday
    WHERE Day_of_week = 'WEEKEND'
)
SELECT Total_weekend
FROM when_weekend 
;


WITH weekend_weekday AS(
    SELECT
    CASE 
    WHEN DAYNAME(`Date Posted`) IN ('Monday','Tuesday','Wednesday','Thursday','Friday')  THEN 'WEEKDAY'  
    ELSE  'WEEKEND'
    END AS Day_of_week, SUM(`Applicants`) Total_week
    FROM staged_jobs
    GROUP BY Day_of_week

)
SELECT Day_of_week, Total_week
FROM weekend_weekday 
;