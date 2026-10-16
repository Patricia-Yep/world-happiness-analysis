/* =========================================================
   WORLD HAPPINESS ANALYSIS, 2015-2019
   03 - DATA ANALYSIS  (SQL Server)

   Questions:
   1. How has global happiness changed over time?
   2. Which regions are happiest, and which changed most?
   3. Which countries are happiest, and which changed most?
   4. Which socioeconomic factors are most closely related
      to happiness?

   Source: dbo.vw_Happiness_Clean (see 02_data_cleaning.sql)
   ========================================================= */

USE Happiness;
GO

/* ---------------------------------------------------------
   1. GLOBAL TREND
   Finding: the global average was stable, 5.35 to 5.41.
   --------------------------------------------------------- */

SELECT [Year], ROUND(AVG(Happiness_Score), 3) AS Avg_Happiness
FROM dbo.vw_Happiness_Clean
GROUP BY [Year]
ORDER BY [Year];

/* ---------------------------------------------------------
   2. REGIONAL DIFFERENCES
   Finding: Australia and New Zealand had the highest average
   (7.30) and Sub-Saharan Africa the lowest (4.19).
   From 2015 to 2019, Central and Eastern Europe gained the
   most (+0.229) and Latin America lost the most (-0.190).
   --------------------------------------------------------- */

-- Average by region, all years
SELECT Region, ROUND(AVG(Happiness_Score), 3) AS Avg_Happiness
FROM dbo.vw_Happiness_Clean
GROUP BY Region
ORDER BY Avg_Happiness DESC;

-- Change by region, 2015 to 2019
SELECT
    Region,
    ROUND(AVG(CASE WHEN [Year] = 2019 THEN Happiness_Score END)
        - AVG(CASE WHEN [Year] = 2015 THEN Happiness_Score END), 3) AS Change_2015_to_2019
FROM dbo.vw_Happiness_Clean
GROUP BY Region
ORDER BY Change_2015_to_2019 DESC;

/* ---------------------------------------------------------
   3. COUNTRY PERFORMANCE
   Only countries present in all five years are compared,
   so every country's average covers the same period.
   Finding: Denmark had the highest average (7.546) and
   Burundi the lowest (3.079). Benin gained the most (+1.543)
   and Venezuela fell the most (-2.103).
   --------------------------------------------------------- */

-- Top and bottom 5 by average score
SELECT TOP 5 Country, ROUND(AVG(Happiness_Score), 3) AS Avg_Happiness
FROM dbo.vw_Happiness_Clean
GROUP BY Country
HAVING COUNT([Year]) = 5
ORDER BY Avg_Happiness DESC;

SELECT TOP 5 Country, ROUND(AVG(Happiness_Score), 3) AS Avg_Happiness
FROM dbo.vw_Happiness_Clean
GROUP BY Country
HAVING COUNT([Year]) = 5
ORDER BY Avg_Happiness ASC;

-- Change from 2015 to 2019 for every full-coverage country
-- (sort DESC for biggest gains, ASC for biggest drops)
SELECT
    Country,
    ROUND(AVG(CASE WHEN [Year] = 2015 THEN Happiness_Score END), 3) AS Happiness_2015,
    ROUND(AVG(CASE WHEN [Year] = 2019 THEN Happiness_Score END), 3) AS Happiness_2019,
    ROUND(AVG(CASE WHEN [Year] = 2019 THEN Happiness_Score END)
        - AVG(CASE WHEN [Year] = 2015 THEN Happiness_Score END), 3) AS Change_2015_to_2019
FROM dbo.vw_Happiness_Clean
GROUP BY Country
HAVING COUNT([Year]) = 5
ORDER BY Change_2015_to_2019 DESC;

/* ---------------------------------------------------------
   4. SOCIOECONOMIC FACTORS
   Pearson correlation (r) and R-squared between Happiness
   Score and each factor, calculated directly in SQL:

   r = [n*SUM(XY) - SUM(X)*SUM(Y)]
       / SQRT([n*SUM(X^2) - SUM(X)^2] * [n*SUM(Y^2) - SUM(Y)^2])

   First, reshape the six factor columns into rows
   (one row per country, year and factor) so the formula
   only has to be written once per question.
   The one NULL (UAE 2018 Trust) is left out here so that
   n, SUM(X) and SUM(Y) all use the same rows.
   --------------------------------------------------------- */

DROP TABLE IF EXISTS #FactorValues;

SELECT
    h.Country,
    h.[Year],
    f.Factor,
    f.Value,
    h.Happiness_Score,
    CASE WHEN fc.Country IS NOT NULL THEN 1 ELSE 0 END AS All_Five_Years
INTO #FactorValues
FROM dbo.vw_Happiness_Clean AS h
LEFT JOIN (
    SELECT Country
    FROM dbo.vw_Happiness_Clean
    GROUP BY Country
    HAVING COUNT(DISTINCT [Year]) = 5
) AS fc
    ON h.Country = fc.Country
CROSS APPLY (VALUES
    ('GDP_Per_Capita',  h.GDP_Per_Capita),
    ('Social_Support',  h.Social_Support),
    ('Life_Expectancy', h.Life_Expectancy),
    ('Freedom',         h.Freedom),
    ('Trust',           h.Trust),
    ('Generosity',      h.Generosity)
) AS f (Factor, Value)
WHERE f.Value IS NOT NULL;

/* 4a. Each year separately (used in the Tableau dashboard)
   Finding: GDP per capita has the strongest relationship in
   every year (R-squared 0.61-0.66) and Generosity the weakest
   (below 0.04). */

WITH r_values AS (
    SELECT
        [Year],
        Factor,
        (COUNT(*) * SUM(Value * Happiness_Score) - SUM(Value) * SUM(Happiness_Score))
        / SQRT(
            (COUNT(*) * SUM(POWER(Value, 2)) - POWER(SUM(Value), 2))
          * (COUNT(*) * SUM(POWER(Happiness_Score, 2)) - POWER(SUM(Happiness_Score), 2))
        ) AS r
    FROM #FactorValues
    GROUP BY [Year], Factor
)
SELECT [Year], Factor,
       ROUND(r, 3)           AS Correlation,
       ROUND(POWER(r, 2), 3) AS R_Squared
FROM r_values
ORDER BY [Year], R_Squared DESC;

/* 4b. All five years pooled together
   Finding: GDP per capita accounts for 62.3% of the variation
   in happiness scores; Generosity for 1.9%. All six
   relationships are positive. */

WITH r_values AS (
    SELECT
        Factor,
        (COUNT(*) * SUM(Value * Happiness_Score) - SUM(Value) * SUM(Happiness_Score))
        / SQRT(
            (COUNT(*) * SUM(POWER(Value, 2)) - POWER(SUM(Value), 2))
          * (COUNT(*) * SUM(POWER(Happiness_Score, 2)) - POWER(SUM(Happiness_Score), 2))
        ) AS r
    FROM #FactorValues
    GROUP BY Factor
)
SELECT Factor,
       ROUND(r, 3)           AS Correlation,
       ROUND(POWER(r, 2), 3) AS R_Squared
FROM r_values
ORDER BY R_Squared DESC;

/* 4c. Robustness check: only the 146 countries present in all
   five years (instead of all 164).
   Finding: no factor's R-squared moved by more than 2 percentage
   points (Trust moved most, 15.9% to 17.5%), and the ranking
   did not change. */

WITH r_values AS (
    SELECT
        Factor,
        (COUNT(*) * SUM(Value * Happiness_Score) - SUM(Value) * SUM(Happiness_Score))
        / SQRT(
            (COUNT(*) * SUM(POWER(Value, 2)) - POWER(SUM(Value), 2))
          * (COUNT(*) * SUM(POWER(Happiness_Score, 2)) - POWER(SUM(Happiness_Score), 2))
        ) AS r
    FROM #FactorValues
    WHERE All_Five_Years = 1
    GROUP BY Factor
)
SELECT Factor,
       ROUND(r, 3)           AS Correlation,
       ROUND(POWER(r, 2), 3) AS R_Squared
FROM r_values
ORDER BY R_Squared DESC;

/* Notes on interpretation
   - These results show which factors move together with
     happiness, not which ones cause it.
   - The factors overlap (wealthier countries also tend to
     have longer life expectancy), so the R-squared values
     cannot be added together.
   - Social Support is lower when years are pooled (0.42) than
     in any single year (0.55-0.60). Its average value shifts
     between report years (about 0.79 in 2016 vs 1.21 in 2019),
     which suggests the measurement scale changed. This is why
     the dashboard uses year-by-year results (4a). */
