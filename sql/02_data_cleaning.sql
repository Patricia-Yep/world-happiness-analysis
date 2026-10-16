/* =========================================================
   WORLD HAPPINESS ANALYSIS, 2015-2019
   02 - DATA CLEANING  (SQL Server)

   Purpose:
   Combine the five annual tables into one consistent view,
   dbo.vw_Happiness_Clean, used for all analysis.

   Steps:
   1. Prepare the Country-to-Region lookup table.
   2. Confirm the lookup agrees with the 2015-2016 Region data.
   3. Create the cleaned view:
        - standardize column names
        - add a Year column
        - standardize country names
        - add Region to 2017-2019 from the lookup
   4. Validate the cleaned view.

   A view is used (rather than a new table) so the raw tables
   stay unchanged. The same cleaning was also done in Excel
   Power Query, producing excel/WorldHappiness_Clean.xlsx.
   ========================================================= */

USE Happiness;
GO

/* ---------------------------------------------------------
   1. PREPARE THE LOOKUP TABLE
   DimHappinessLookup was imported from the Power Query lookup
   (excel/Country_Region_Lookup.xlsx). The import used generic
   column names and brought the header in as a data row.
   Run once.
   --------------------------------------------------------- */

EXEC sp_rename 'dbo.DimHappinessLookup.column1', 'Country', 'COLUMN';
EXEC sp_rename 'dbo.DimHappinessLookup.column2', 'Region',  'COLUMN';

DELETE FROM dbo.DimHappinessLookup
WHERE Country = 'Country' AND Region = 'Region';

SELECT COUNT(*) AS Lookup_Row_Count
FROM dbo.DimHappinessLookup;

/* ---------------------------------------------------------
   2. CHECK THE LOOKUP AGAINST 2015-2016 REGIONS
   No rows returned = the lookup matches the source data.
   --------------------------------------------------------- */

SELECT 2015 AS [Year], h.Country, h.Region AS Source_Region, d.Region AS Lookup_Region
FROM dbo.Happiness_2015 AS h
LEFT JOIN dbo.DimHappinessLookup AS d ON h.Country = d.Country
WHERE d.Country IS NULL OR h.Region <> d.Region
UNION ALL
SELECT 2016, h.Country, h.Region, d.Region
FROM dbo.Happiness_2016 AS h
LEFT JOIN dbo.DimHappinessLookup AS d ON h.Country = d.Country
WHERE d.Country IS NULL OR h.Region <> d.Region;
GO

/* ---------------------------------------------------------
   3. CREATE THE CLEANED VIEW
   Country names are standardized to match the lookup.
   (CREATE VIEW must be the only statement in its batch,
   hence the GO lines around it.)
   --------------------------------------------------------- */

CREATE OR ALTER VIEW dbo.vw_Happiness_Clean
AS
SELECT
    CASE WHEN Country = 'North Cyprus' THEN 'Northern Cyprus' ELSE Country END AS Country,
    Happiness_Rank,
    Happiness_Score,
    Economy_GDP_per_Capita      AS GDP_Per_Capita,
    Family                      AS Social_Support,
    Health_Life_Expectancy      AS Life_Expectancy,
    Freedom,
    Trust_Government_Corruption AS Trust,
    Generosity,
    2015 AS [Year],
    Region
FROM dbo.Happiness_2015

UNION ALL

SELECT
    CASE WHEN Country = 'North Cyprus' THEN 'Northern Cyprus' ELSE Country END,
    Happiness_Rank, Happiness_Score, Economy_GDP_per_Capita, Family,
    Health_Life_Expectancy, Freedom, Trust_Government_Corruption, Generosity,
    2016,
    Region
FROM dbo.Happiness_2016

UNION ALL

SELECT
    c.Country,
    h.Happiness_Rank, h.Happiness_Score, h.Economy_GDP_per_Capita, h.Family,
    h.Health_Life_Expectancy, h.Freedom, h.Trust_Government_Corruption, h.Generosity,
    2017,
    d.Region
FROM dbo.Happiness_2017 AS h
CROSS APPLY (SELECT CASE
        WHEN h.Country = 'North Cyprus'             THEN 'Northern Cyprus'
        WHEN h.Country = 'Hong Kong S.A.R., China'  THEN 'Hong Kong'
        WHEN h.Country = 'Taiwan Province of China' THEN 'Taiwan'
        ELSE h.Country END AS Country) AS c
LEFT JOIN dbo.DimHappinessLookup AS d ON c.Country = d.Country

UNION ALL

SELECT
    c.Country,
    h.Overall_rank, h.Score, h.GDP_per_capita, h.Social_support,
    h.Healthy_life_expectancy, h.Freedom_to_make_life_choices,
    h.Perceptions_of_corruption, h.Generosity,
    2018,
    d.Region
FROM dbo.Happiness_2018 AS h
CROSS APPLY (SELECT CASE
        WHEN h.Country_or_region = 'Trinidad & Tobago' THEN 'Trinidad and Tobago'
        ELSE h.Country_or_region END AS Country) AS c
LEFT JOIN dbo.DimHappinessLookup AS d ON c.Country = d.Country

UNION ALL

SELECT
    c.Country,
    h.Overall_rank, h.Score, h.GDP_per_capita, h.Social_support,
    h.Healthy_life_expectancy, h.Freedom_to_make_life_choices,
    h.Perceptions_of_corruption, h.Generosity,
    2019,
    d.Region
FROM dbo.Happiness_2019 AS h
CROSS APPLY (SELECT CASE
        WHEN h.Country_or_region = 'North Macedonia'   THEN 'Macedonia'
        WHEN h.Country_or_region = 'Trinidad & Tobago' THEN 'Trinidad and Tobago'
        ELSE h.Country_or_region END AS Country) AS c
LEFT JOIN dbo.DimHappinessLookup AS d ON c.Country = d.Country;
GO

/* ---------------------------------------------------------
   4. VALIDATE THE CLEANED VIEW
   --------------------------------------------------------- */

-- Expect 782 rows, 164 countries, 5 years, 10 regions
SELECT
    COUNT(*)                 AS Row_Count,
    COUNT(DISTINCT Country)  AS Country_Count,
    COUNT(DISTINCT [Year])   AS Year_Count,
    COUNT(DISTINCT Region)   AS Region_Count
FROM dbo.vw_Happiness_Clean;

-- Expect no rows: each country appears once per year
SELECT Country, [Year], COUNT(*) AS Record_Count
FROM dbo.vw_Happiness_Clean
GROUP BY Country, [Year]
HAVING COUNT(*) > 1;

-- Expect zero NULLs everywhere except one in Trust (UAE, 2018)
SELECT
    COUNT(*) - COUNT(Country)         AS Country_Nulls,
    COUNT(*) - COUNT(Happiness_Score) AS Happiness_Score_Nulls,
    COUNT(*) - COUNT(GDP_Per_Capita)  AS GDP_Nulls,
    COUNT(*) - COUNT(Social_Support)  AS Social_Support_Nulls,
    COUNT(*) - COUNT(Life_Expectancy) AS Life_Expectancy_Nulls,
    COUNT(*) - COUNT(Freedom)         AS Freedom_Nulls,
    COUNT(*) - COUNT(Trust)           AS Trust_Nulls,
    COUNT(*) - COUNT(Generosity)      AS Generosity_Nulls,
    COUNT(*) - COUNT(Region)          AS Region_Nulls
FROM dbo.vw_Happiness_Clean;

-- Expect no rows: old country spellings should be gone
SELECT DISTINCT Country
FROM dbo.vw_Happiness_Clean
WHERE Country IN ('North Cyprus', 'Hong Kong S.A.R., China', 'Taiwan Province of China',
                  'Trinidad & Tobago', 'North Macedonia');

-- Review zero values (present in the source data; kept as-is)
SELECT *
FROM dbo.vw_Happiness_Clean
WHERE 0 IN (GDP_Per_Capita, Social_Support, Life_Expectancy, Freedom, Trust, Generosity)
ORDER BY [Year], Country;

/* Note: several factors contain zeros in the source data. There
   is no information on whether these are true zeros or missing
   values, so they were kept unchanged. */
