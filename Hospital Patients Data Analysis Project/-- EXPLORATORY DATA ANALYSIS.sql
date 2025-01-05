-- Active: 1734606262624@@localhost@3306@healthcare_data
-- Active: 1734606262624@@localhost@3306@health
-- EXPLORATORY DATA ANALYSIS
-- Data Driven Questions

-----------------------------------------------------------------------------
-- 1. How many patients have been admitted or readmitted over time?
-- 2. How long are patients staying in the hospital, on average?
-- 3. How much is the average cost per visit?
-- 4. How many procedures are covered by insurance?

SELECT *
FROM staged_final_encounter
;
------------------------------------------------------------------------------------------------------------
-- 1. How many patients have been admitted or readmitted over time?

-- Explanation
--Step 1: Sort Encounters by Patient and Date
--The LAG() function retrieves the previous encounter's Start (admission date) for the same Patient.

--Step 2: Calculate Days Between Encounters
--Use DATEDIFF() to calculate the difference in days between the current and previous admission.

--Step 3: Filter for Readmissions
--Filter rows where DaysBetween is ≤ 30 (or any threshold for readmission).

--Step 4: Aggregate Results
--Count the number of readmissions for each patient.

WITH SortedEncounters AS (
    SELECT
        Id_PATIENTS,
        id_encounter,
        START,
        ENCOUNTERCLASS,
        LAG(START) OVER (PARTITION BY Id_PATIENTS ORDER BY START) AS PreviousAdmissionDate
    FROM
        staged_final_encounter
),
Readmissions AS (
    SELECT
        Id_PATIENTS,
        id_encounter,
        START,
        PreviousAdmissionDate,
        ENCOUNTERCLASS,
        DATEDIFF(START, PreviousAdmissionDate) AS DaysBetween
    FROM
        SortedEncounters
    WHERE
        PreviousAdmissionDate IS NOT NULL
        AND DATEDIFF(START, PreviousAdmissionDate) <= 30
)
SELECT
    ENCOUNTERCLASS,
    COUNT(*) AS ReadmissionCount
FROM
    Readmissions
GROUP BY
    ENCOUNTERCLASS;

------------------------------------------------------------------------------------------
-- 2. How long are patients staying in the hospital, on average?

--Calculate the Length of Stay:

--Find the difference between Stop and Start for each encounter to calculate the duration (e.g., in days or hours).

--Compute the Average:

--Take the average of all calculated lengths of stay.

SELECT
    EncounterClass,
    AVG(TIMESTAMPDIFF(HOUR, START, STOP) / 24) AS AverageLengthOfStay_Days
FROM
    staged_final_encounter
GROUP BY
    EncounterClass;


-------------------------------------------------------------------------------------------------------
-- 3. How much is the average cost per visit?

SELECT 
    ENCOUNTERCLASS,
    AVG(TOTAL_CLAIM_COST) AS AverageCost
FROM staged_final_encounter
GROUP BY
    ENCOUNTERCLASS;


-------------------------------------------------------------------------------------------------------
-- 4. How many procedures are covered by insurance?
WITH total_insurance AS (
    SELECT
    SUM(PAYER_COVERAGE) Total_insurance
FROM
    staged_final_procedures

),
percent_coverage AS(
    SELECT
        (Total_insurance/PAYER_COVERAGE)*100
    FROM
        total_insurance
    WHERE
        PAYER_COVERAGE > 0
)
SELECT
    e.ENCOUNTERCLASS,
    (Total_insurance/PAYER_COVERAGE)*100
FROM 
    staged_final_encounter e, staged_final_procedures p;

WITH total_insurance AS (
    SELECT
        SUM(PAYER_COVERAGE) AS Total_insurance
    FROM
        staged_final_procedures
),
percent_coverage AS (
    SELECT
        (ti.Total_insurance / p.PAYER_COVERAGE) * 100 AS Percent_paid
    FROM
        staged_final_procedures p, total_insurance ti
    WHERE
        p.PAYER_COVERAGE > 0
),
not_paid AS(
    SELECT 
    (ti.Total_insurance / p.PAYER_COVERAGE) * 100 AS Percent_NOT_paid
    FROM
        staged_final_procedures p, total_insurance ti,percent_coverage pc
    WHERE
        p.PAYER_COVERAGE = 0
)
SELECT
    e.ENCOUNTERCLASS,
    pc.Percent_paid,
    np.percent_NOT_paid
FROM
    staged_final_encounter e, percent_coverage pc, not_paid np;



SELECT
    
    SUM(PAYER_COVERAGE)
FROM
    staged_final_procedures
WHERE
    PAYER_COVERAGE>0
;


SELECT enc
FROM final_procedures