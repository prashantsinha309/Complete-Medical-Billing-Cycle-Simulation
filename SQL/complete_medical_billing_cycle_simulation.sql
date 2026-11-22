-- create database complete_medical_billing_cycle_simulation;
-- use complete_medical_billing_cycle_simulation;
-- Here, table name is project3_billed_data

-- 1. Unique Patient Count
SELECT
    COUNT(DISTINCT `Patient_Id`) AS Unique_Patients
FROM project3_billed_data;

-- 2. Unique Encounter Count
SELECT
    COUNT(DISTINCT `Encounter Id`) AS Unique_Encounters
FROM project3_billed_data;


-- 3. Unique Claim Count
SELECT
    COUNT(DISTINCT `Claim Id`) AS Unique_Claims
FROM project3_billed_data;


-- 4. Claims by Payer
SELECT
    `Payer`,
    COUNT(DISTINCT `Claim Id`) AS Total_Claims
FROM project3_billed_data
GROUP BY `Payer`
ORDER BY Total_Claims DESC;


-- 5. Charges by Department
SELECT
    `Department`,
    SUM(`Charge Amount`) AS Total_Charges
FROM project3_billed_data
GROUP BY `Department`
ORDER BY Total_Charges DESC;


-- 6. Payments by Payer
SELECT
    `Payer`,
    SUM(`Payment Amount`) AS Total_Payments
FROM project3_billed_data
GROUP BY `Payer`
ORDER BY Total_Payments DESC;


-- 7. Denial Rate
SELECT
    ROUND(
	COUNT(DISTINCT CASE
		WHEN `Denial Indicator` = 'Yes'
		THEN `Claim Id`
        END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE
		WHEN `Adjudication Date` IS NOT NULL
		AND `Adjudication Date` <> ''
		THEN `Claim Id`
        END), 0),
        2
    ) AS Denial_Rate_Percentage
FROM project3_billed_data;


-- 8. Total Denial Amount
SELECT
    SUM(`Denied Amount`) AS Total_Denied_Amount
FROM project3_billed_data;


-- 9. Denials by Category
SELECT
    `Denial Category`,
    COUNT(DISTINCT `Claim Id`) AS Total_Denials,
    SUM(`Denied Amount`) AS Total_Denied_Amount
FROM project3_billed_data
WHERE `Denial Indicator` = 'Yes'
GROUP BY `Denial Category`
ORDER BY Total_Denied_Amount DESC;


-- 10. Open Denials
SELECT
    `Claim Id`,
    `Patient Name`,
    `Payer`,
    `Denial Category`,
    `Denial Reason`,
    `Denied Amount`,
    `Denial Date`
FROM project3_billed_data
WHERE `Denial Indicator` = 'Yes'
  AND (`Resolution Date` IS NULL
       OR `Resolution Date` = '');


-- 11. Average Denial Resolution Time
SELECT
    ROUND(
	AVG(
	DATEDIFF(
	DATE_ADD('1899-12-30', INTERVAL CAST(`Resolution Date` AS UNSIGNED) DAY),
	DATE_ADD('1899-12-30', INTERVAL CAST(`Denial Date` AS UNSIGNED) DAY)
	)
	),
	2
    ) AS Avg_Denial_Resolution_Days
FROM project3_billed_data
WHERE `Denial Date` IS NOT NULL
  AND `Denial Date` <> ''
  AND `Resolution Date` IS NOT NULL
  AND `Resolution Date` <> '';

-- 12. Average Payment Posting Turnaround
SELECT
    ROUND(
	AVG(
	CAST(`Payment Posting Turnaround (Days)` AS DECIMAL(10,2))
	),
	2
    ) AS Avg_Payment_Posting_Days
FROM project3_billed_data
WHERE `Payment Posting Turnaround (Days)` IS NOT NULL
  AND `Payment Posting Turnaround (Days)` <> '';


-- 13. AR Aging
SELECT
    `AR Aging Bucket`,
    COUNT(DISTINCT `Acount ID`) AS Total_Accounts,
    SUM(`Patient Balance`) AS Total_Patient_Balance
FROM project3_billed_data
WHERE `Patient Balance` > 0
GROUP BY `AR Aging Bucket`
ORDER BY
    CASE `AR Aging Bucket`
        WHEN '0-30 Days' THEN 1
        WHEN '31-60 Days' THEN 2
        WHEN '61-90 Days' THEN 3
        WHEN 'Over 90 Days' THEN 4
        ELSE 5
    END;


-- 14. Patient Balances
SELECT
    `Patient_Id`,
    `Patient Name`,
    `Acount ID`,
    SUM(`Patient Responsibility`) AS Total_Responsibility,
    SUM(`Patient Payment`) AS Total_Patient_Payments,
    SUM(`Patient Balance`) AS Outstanding_Balance
FROM project3_billed_data
GROUP BY
    `Patient_Id`,
    `Patient Name`,
    `Acount ID`
HAVING SUM(`Patient Balance`) > 0
ORDER BY Outstanding_Balance DESC;


-- 15. High-Value Accounts
SELECT
    `Acount ID`,
    `Patient Name`,
    SUM(`Charge Amount`) AS Total_Charges,
    SUM(`Payment Amount`) AS Total_Payments,
    SUM(`Patient Balance`) AS Outstanding_Balance
FROM project3_billed_data
GROUP BY
    `Acount ID`,
    `Patient Name`
HAVING SUM(`Charge Amount`) > 3000
ORDER BY Total_Charges DESC;


-- 16. Reconciliation Differences
-- Assumes Allowed = Payment + Adjustment + Patient Responsibility
SELECT
    `Claim Id`,
    SUM(`Allowed Amount`) AS Total_Allowed,
    SUM(`Payment Amount`) AS Total_Payer_Payment,
    SUM(`Adjustment Amount`) AS Total_Adjustment,
    SUM(`Patient Responsibility`) AS Total_Patient_Responsibility,
    SUM(`Allowed Amount`)
      - SUM(`Payment Amount`)
      - SUM(`Adjustment Amount`)
      - SUM(`Patient Responsibility`) AS Reconciliation_Difference
FROM project3_billed_data
GROUP BY `Claim Id`
HAVING ABS(Reconciliation_Difference) > 0.01
ORDER BY ABS(Reconciliation_Difference) DESC;


-- 17. Potential Duplicate Claims
SELECT
    `Patient_Id`,
    `Encounter Id`,
    `Payer`,
    `Service Date`,
    COUNT(DISTINCT `Claim Id`) AS Claim_Count
FROM project3_billed_data
GROUP BY
    `Patient_Id`,
    `Encounter Id`,
    `Payer`,
    `Service Date`
HAVING COUNT(DISTINCT `Claim Id`) > 1;


-- 18. Accounts with Unresolved Balances
SELECT
    `Acount ID`,
    `Patient Name`,
    `Account Status`,
    SUM(`Patient Balance`) AS Outstanding_Balance
FROM project3_billed_data
GROUP BY
    `Acount ID`,
    `Patient Name`,
    `Account Status`
HAVING SUM(`Patient Balance`) > 0
   AND `Account Status` <> 'Closed'
ORDER BY Outstanding_Balance DESC;

      
-- 19. Accounts Closed During Reporting Period
SELECT
    `Acount ID`,
    `Patient Name`,
    `Account Status`
FROM project3_billed_data
WHERE TRIM(LOWER(`Account Status`)) = 'closed'
ORDER BY `Acount ID`;


-- 20. Monthly Revenue-Cycle Trends
SELECT
    Revenue_Month,
    SUM(Total_Charges) AS Monthly_Charges,
    SUM(Total_Payments) AS Monthly_Payments
FROM (
      SELECT
	  DATE_FORMAT(
	  DATE_ADD(
	  '1899-12-30',
	  INTERVAL CAST(`Service Date` AS UNSIGNED) DAY
	  ),
	  '%Y-%m'
	  ) AS Revenue_Month,
	  SUM(`Charge Amount`) AS Total_Charges,
	  0 AS Total_Payments
FROM project3_billed_data
WHERE `Service Date` IS NOT NULL
GROUP BY Revenue_Month

    UNION ALL

    SELECT
	DATE_FORMAT(
	STR_TO_DATE(`Payment Date`, '%Y-%m-%d'),
	'%Y-%m'
	) AS Revenue_Month,
	0 AS Total_Charges,
	SUM(`Payment Amount`) AS Total_Payments
    FROM project3_billed_data
    WHERE `Payment Date` IS NOT NULL
	AND `Payment Date` <> ''
    GROUP BY Revenue_Month
) AS Monthly_Data
GROUP BY Revenue_Month
ORDER BY Revenue_Month;

