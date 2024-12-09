-- First, we need to merge all 12 sales data for the year 2019
-- To achieve this we use UNION instead of JOIN because all 12 sales data have the same number of column names, same data type etc.
-- We then save the merged data into a new table in our schema.

CREATE TABLE amazon_sales_data.cleaned_data AS
WITH sales_data AS (
SELECT *
FROM amazon_sales_data.sales_january_2019
UNION
SELECT *
FROM amazon_sales_data.sales_february_2019
UNION
SELECT *
FROM amazon_sales_data.sales_march_2019
UNION
SELECT *
FROM amazon_sales_data.sales_april_2019
UNION
SELECT *
FROM amazon_sales_data.sales_may_2019
UNION
SELECT *
FROM amazon_sales_data.sales_june_2019
UNION
SELECT *
FROM amazon_sales_data.sales_july_2019
UNION
SELECT *
FROM amazon_sales_data.sales_august_2019
UNION
SELECT *
FROM amazon_sales_data.sales_september_2019
UNION
SELECT *
FROM amazon_sales_data.sales_october_2019
UNION
SELECT *
FROM amazon_sales_data.sales_november_2019
UNION
SELECT *
FROM amazon_sales_data.sales_december_2019
)

SELECT *
FROM sales_data;


-- 2 Data Staging: Data staging is the process of preparing and organizing data before it's moved to its final destination. The goal is to ensure that the data is clean, consistent, and ready for analysis.

SELECT *
FROM amazon_sales_data.cleaned_data;

SET GLOBAL max_allowed_packet = 268435456; -- 256MB, Increase the packet size of the MySQL Workbench
SET SESSION group_concat_max_len = 1000000;

CREATE TABLE amazon_sales_data.staged_cleaned_data  -- Storing the cleaned data into our newly created staged table
LIKE amazon_sales_data.cleaned_data;

SELECT *
FROM amazon_sales_data.staged_cleaned_data;

INSERT amazon_sales_data.staged_cleaned_data
SELECT *
FROM amazon_sales_data.cleaned_data;

-- Staged Data
SELECT *
FROM amazon_sales_data.staged_cleaned_data  -- Final result
;

-- We do not have duplicates in our data but just for curiosity lets use a CTE and a Window Function

WITH dup_rows AS(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY `Order ID`, Product, `Quantity Ordered`, `Price Each`, `Order Date`, `Purchase Address`) AS num_rows
FROM amazon_sales_data.staged_cleaned_data
)

SELECT *
FROM dup_rows
WHERE num_rows > 1;


-- Delete empty and null rows

DELETE FROM amazon_sales_data.staged_cleaned_data
WHERE (`Order ID` IS NULL OR `Order ID` = '')
	AND (Product IS NULL OR Product = '')
    AND (`Quantity Ordered` IS NULL OR `Quantity Ordered` = '')
    AND (`Price Each` IS NULL OR `Price Each`= '')
    AND (`Order Date` IS NULL OR `Order Date`= '')
    AND (`Purchase Address` IS NULL OR `Purchase Address`='');



-- 3 STANDARDIZATION (TRIMMING, TEXT TO DATETIME, MEDIUMTEXT TO APPROPRIATE DATATYPES)
-- We noticed we have the same column names as the last row of our data, we need to remove this for easy standardization

-- SELECT *
-- FROM amazon_sales_data.staged_cleaned_data
-- ORDER BY `Order Date` DESC
-- LIMIT 1;

-- DELETE FROM amazon_sales_data.staged_cleaned_data
-- ORDER BY `Order Date` DESC
-- LIMIT 1;

-- UPDATE amazon_sales_data.staged_cleaned_data
-- SET `Order ID` = TRIM(`Order ID`), Product = TRIM(Product), `Quantity Ordered` = TRIM(`Quantity Ordered`), `Price Each` = TRIM(`Price Each`), `Purchase Address` = TRIM(`Purchase Address`);

-- Data type conversion using CAST()


-- SELECT `Order ID`
-- FROM `amazon_sales_data`.`staged_cleaned_data`
-- WHERE `Order ID` NOT REGEXP '^[0-9]+$';

-- UPDATE `amazon_sales_data`.`staged_cleaned_data`
-- SET `Order ID` = NULL
-- WHERE `Order ID` NOT REGEXP '^[0-9]+$';

-- ALTER TABLE `amazon_sales_data`.`staged_cleaned_data`
-- CHANGE COLUMN `Order ID` `Order ID` INT NULL;

-- UPDATE `amazon_sales_data`.`staged_cleaned_data`
-- SET `Quantity Ordered` = NULL, `Price Each` = NULL
-- WHERE `Quantity Ordered` NOT REGEXP '^[0-9]+$' OR `Price Each` NOT REGEXP '^-?[0-9]+(\.[0-9]+)?$';

-- ALTER TABLE `amazon_sales_data`.`staged_cleaned_data`
-- CHANGE COLUMN `Quantity Ordered` `Quantity Ordered` INT NULL,
-- CHANGE COLUMN `Price Each` `Price Each` FLOAT NULL;


-- The Order Date column is in a wrong datetime format dd-mm-yy
SELECT *
FROM amazon_sales_data.staged_cleaned_data
WHERE MONTH(`Order Date`)= 12
;     -- Query testing

-- This query helps filter out irregular exxpressions/text in the 'Order Date' column
SELECT `Order Date`
FROM amazon_sales_data.staged_cleaned_data
WHERE `Order Date` NOT REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}$';


-- Delete irregular expressions which may affect the conversion of the 'Order Date' column from dd-mm-yy to 'm-d-y'
DELETE FROM amazon_sales_data.staged_cleaned_data
WHERE `Order Date` NOT REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}$';


-- This conversion query helps satisfy the targeted task using string to date function (STR_TO_DATE)
SELECT `Order Date`,
STR_TO_DATE(`Order Date`, '%m/%d/%Y %H:%i')
FROM amazon_sales_data.staged_cleaned_data;



DELETE FROM amazon_sales_data.staged_cleaned_data
WHERE `Order Date`= '01/28/19 14:15';


-- We then finally have to update the converted column
UPDATE amazon_sales_data.staged_cleaned_data
SET `Order Date` = STR_TO_DATE(`Order Date`, '%m/%d/%Y %H:%i');

SELECT *
FROM amazon_sales_data.staged_cleaned_data
WHERE DAY(`Order Date`) < 10; -- Query testing



-- The data type of the 'Order Date' column was 'MEDIUMTEXT', So we need to change the data type to 'DATETIME' conversion
ALTER TABLE amazon_sales_data.staged_cleaned_data
MODIFY `Order Date` DATETIME;

----------------------------------------------------------------
SELECT `Order Date`, `Purchase Address`,COUNT(`Order ID`)
FROM amazon_sales_data.staged_cleaned_data
GROUP BY `Order Date`, `Purchase Address`; -- Query testing

-- Then Create a new column to store the city data

ALTER TABLE amazon_sales_data.staged_cleaned_data
ADD COLUMN City TEXT;

-- Use SUBSTRING_INDEX to split the Purchase Address column to get the city names

UPDATE amazon_sales_data.staged_cleaned_data
SET City = SUBSTRING_INDEX(SUBSTRING_INDEX(`Purchase Address`, ',', 2), ',', -1);

SELECT *
FROM amazon_sales_data.staged_cleaned_data;

-- Drop the Purchase Address column
ALTER TABLE amazon_sales_data.staged_cleaned_data
DROP `Purchase Address`;


-- We use SUBSTRING to query the Product column to extract product categories to create a new column
SELECT Product,
-- DISTINCT(SUBSTRING_INDEX(Product, ' ',-1)),
CASE
	WHEN Product LIKE '%Headphones%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%Monitor%' THEN SUBSTRING_INDEX(Product, ' ',-1)
	-- WHEN Product LIKE '%Batteries%' THEN SUBSTRING_INDEX(SUBSTRING_INDEX(Product, '', 2), '', -1)
    WHEN LOCATE('Batteries', Product) > 0 THEN 'Batteries'
    WHEN Product LIKE '%Cable%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%Laptop%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%TV%' THEN SUBSTRING_INDEX(Product, ' ',-1)
	WHEN Product LIKE '%Phone%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%iPhone%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%Dryer%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%Machine%' THEN SUBSTRING_INDEX(Product, ' ',-1)
END AS new_p
FROM amazon_sales_data.staged_cleaned_data
;

-- Update the Product column
UPDATE amazon_sales_data.staged_cleaned_data
SET Product = CASE
	WHEN Product LIKE '%Headphones%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%Monitor%' THEN SUBSTRING_INDEX(Product, ' ',-1)
	-- WHEN Product LIKE '%Batteries%' THEN SUBSTRING_INDEX(SUBSTRING_INDEX(Product, '', 2), '', -1)
    WHEN LOCATE('Batteries', Product) > 0 THEN 'Batteries'
    WHEN Product LIKE '%Cable%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%Laptop%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%TV%' THEN SUBSTRING_INDEX(Product, ' ',-1)
	WHEN Product LIKE '%Phone%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%iPhone%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%Dryer%' THEN SUBSTRING_INDEX(Product, ' ',-1)
    WHEN Product LIKE '%Machine%' THEN SUBSTRING_INDEX(Product, ' ',-1)
END;
