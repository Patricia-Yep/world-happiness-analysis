/* =========================================================
   WORLD HAPPINESS ANALYSIS, 2015-2019
   01 - DATA PROFILING  (SQL Server)

   Purpose:
   Examine the five raw annual tables before cleaning.
   The raw tables use different column names, so they are
   first lined up in one temporary table (#RawData) so every
   check below can run once across all five years.
   The original raw tables are not changed.
   ========================================================= */

USE Happiness;
GO

/* ---------------------------------------------------------
   0. COMPARE COLUMN NAMES AND DATA TYPES ACROSS YEARS
   --------------------------------------------------------- */

SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('Happiness_2015', 'Happiness_2016', 'Happiness_2017',
                     'Happiness_2018', 'Happiness_2019')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

/* ---------------------------------------------------------
   Stack the raw tables into one temporary table for profiling
   --------------------------------------------------------- */

DROP TABLE IF EXISTS #RawData;

SELECT 2015 AS [Year], Country, Happiness_Score,
       Economy_GDP_per_Capita AS GDP_Per_Capita, Family AS Social_Support,
       Health_Life_Expectancy AS Life_Expectancy, Freedom,
       Trust_Government_Corruption AS Trust, Generosity
INTO #RawData
FROM dbo.Happiness_2015
UNION ALL
SELECT 2016, Country, Happiness_Score, Economy_GDP_per_Capita, Family,
       Health_Life_Expectancy, Freedom, Trust_Government_Corruption, Generosity
FROM dbo.Happiness_2016
UNION ALL
SELECT 2017, Country, Happiness_Score, Economy_GDP_per_Capita, Family,
       Health_Life_Expectancy, Freedom, Trust_Government_Corruption, Generosity
FROM dbo.Happiness_2017
UNION ALL
SELECT 2018, Country_or_region, Score, GDP_per_capita, Social_support,
       Healthy_life_expectancy, Freedom_to_make_life_choices,
       Perceptions_of_corruption, Generosity
FROM dbo.Happiness_2018
UNION ALL
SELECT 2019, Country_or_region, Score, GDP_per_capita, Social_support,
       Healthy_life_expectancy, Freedom_to_make_life_choices,
       Perceptions_of_corruption, Generosity
FROM dbo.Happiness_2019;

/* ---------------------------------------------------------
   1. ROW COUNTS BY YEAR
   --------------------------------------------------------- */

SELECT [Year], COUNT(*) AS Row_Count
FROM #RawData
GROUP BY [Year]
ORDER BY [Year];

/* ---------------------------------------------------------
   2. DUPLICATE CHECK
   A country should appear only once per year.
   No rows returned = no duplicates.
   --------------------------------------------------------- */

SELECT [Year], Country, COUNT(*) AS Record_Count
FROM #RawData
GROUP BY [Year], Country
HAVING COUNT(*) > 1;

/* ---------------------------------------------------------
   3. MISSING VALUE CHECK
   COUNT(column) skips NULLs, so COUNT(*) - COUNT(column)
   gives the number of NULLs in that column.
   --------------------------------------------------------- */

SELECT
    [Year],
    COUNT(*) - COUNT(Country)         AS Country_Nulls,
    COUNT(*) - COUNT(Happiness_Score) AS Happiness_Score_Nulls,
    COUNT(*) - COUNT(GDP_Per_Capita)  AS GDP_Nulls,
    COUNT(*) - COUNT(Social_Support)  AS Social_Support_Nulls,
    COUNT(*) - COUNT(Life_Expectancy) AS Life_Expectancy_Nulls,
    COUNT(*) - COUNT(Freedom)         AS Freedom_Nulls,
    COUNT(*) - COUNT(Trust)           AS Trust_Nulls,
    COUNT(*) - COUNT(Generosity)      AS Generosity_Nulls
FROM #RawData
GROUP BY [Year]
ORDER BY [Year];

SELECT *
FROM #RawData
WHERE Trust IS NULL;

/* Finding: one NULL - United Arab Emirates, 2018, Trust.
   It is kept as NULL rather than replaced with zero, because
   a missing value is not a measured value of zero. */

/* ---------------------------------------------------------
   4. NUMERIC RANGE CHECK
   Look for impossible or suspicious values.
   --------------------------------------------------------- */

SELECT
    [Year],
    MIN(Happiness_Score) AS Min_Happiness,  MAX(Happiness_Score) AS Max_Happiness,
    MIN(GDP_Per_Capita)  AS Min_GDP,        MAX(GDP_Per_Capita)  AS Max_GDP,
    MIN(Social_Support)  AS Min_Social,     MAX(Social_Support)  AS Max_Social,
    MIN(Life_Expectancy) AS Min_Life,       MAX(Life_Expectancy) AS Max_Life,
    MIN(Freedom)         AS Min_Freedom,    MAX(Freedom)         AS Max_Freedom,
    MIN(Trust)           AS Min_Trust,      MAX(Trust)           AS Max_Trust,
    MIN(Generosity)      AS Min_Generosity, MAX(Generosity)      AS Max_Generosity
FROM #RawData
GROUP BY [Year]
ORDER BY [Year];

/* ---------------------------------------------------------
   5. COUNTRY COVERAGE
   Which countries are missing from one or more years?
   --------------------------------------------------------- */

SELECT
    Country,
    COUNT(*) AS Years_Present,
    STRING_AGG(CAST([Year] AS varchar(4)), ', ')
        WITHIN GROUP (ORDER BY [Year]) AS Years
FROM #RawData
GROUP BY Country
HAVING COUNT(*) < 5
ORDER BY Years_Present, Country;

/* =========================================================
   PROFILING SUMMARY

   - 782 records across 2015-2019; no duplicate country-years.
   - One missing value: United Arab Emirates, 2018, Trust.
   - No obvious import or data-entry errors in value ranges.
   - Column names differ between years.
   - Region exists in 2015-2016 only.
   - Country names spelled differently in some years:
       Macedonia / North Macedonia
       Hong Kong / Hong Kong S.A.R., China
       Taiwan / Taiwan Province of China
       North Cyprus / Northern Cyprus
       Trinidad and Tobago / Trinidad & Tobago
   - Other coverage gaps are countries not surveyed every year.

   Cleaning plan (see 02_data_cleaning.sql):
   1. Standardize column names.      4. Add Region for 2017-2019.
   2. Standardize country names.     5. Keep the UAE Trust NULL.
   3. Add a Year column.             6. Leave raw tables unchanged.
   ========================================================= */
