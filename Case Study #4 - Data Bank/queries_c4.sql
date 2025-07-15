--A. Customer Nodes Exploration

-- 1.How many unique nodes are there on the Data Bank system?

SELECT COUNT(DISTINCT(node_id)) AS nodes
FROM customer_nodes
;

-- 2.What is the number of nodes per region?

SELECT r.region_name, COUNT(cn.node_id) AS nmbr_nodes
FROM customer_nodes AS cn
INNER JOIN regions AS r ON cn.region_id = r.region_id 
GROUP BY r.region_name
ORDER BY nmbr_nodes DESC
;

-- 3.How many customers are allocated to each region?

SELECT r.region_name, COUNT(DISTINCT(cn.customer_id)) AS customers
FROM customer_nodes AS cn
INNER JOIN regions AS r ON cn.region_id = r.region_id 
GROUP BY r.region_name
ORDER BY customers DESC
;

-- 4.How many days on average are customers reallocated to a different node?

SELECT AVG(DATEDIFF(DAY,start_date,end_date)) AS average
FROM customer_nodes
WHERE end_date < '9999-12-31'
;


-- 5.What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

SELECT DISTINCT
        r.region_name,
        PERCENTILE_CONT(0.5) 
            WITHIN GROUP (ORDER BY DATEDIFF(DAY,cn.start_date,cn.end_date)) OVER(PARTITION BY r.region_name) AS median,
        PERCENTILE_CONT(0.80) 
            WITHIN GROUP (ORDER BY DATEDIFF(DAY,cn.start_date,cn.end_date)) OVER(PARTITION BY r.region_name) AS eightieth_percentile,
        PERCENTILE_CONT(0.95) 
            WITHIN GROUP (ORDER BY DATEDIFF(DAY,cn.start_date,cn.end_date)) OVER(PARTITION BY r.region_name) AS ninety_fifth_percentile
FROM customer_nodes AS cn
INNER JOIN regions AS r ON cn.region_id = r.region_id 
WHERE cn.end_date < '9999-12-31'
;



-- B. Customer Transactions

-- 1.What is the unique count and total amount for each transaction type?

SELECT 
    txn_type, 
    COUNT(DISTINCT(txn_date)) AS total_transactions , 
    SUM(txn_amount) AS total_amount
FROM customer_transactions
GROUP BY txn_type
;


-- 2.What is the average total historical deposit counts and amounts for all customers?

WITH calculation_total_historical AS(
    SELECT 
      customer_id , 
      SUM(txn_amount) AS total_amount , 
      COUNT(*) AS total_deposits
    FROM customer_transactions
    WHERE txn_type = 'deposit'
    GROUP BY customer_id
)

SELECT  
  AVG(total_deposits) avg_total_deposits , 
  AVG(total_amount) AS avg_total_amount
FROM calculation_total_historical
;


-- 3.For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

WITH more_than_one_deposit AS(
    SELECT 
        customer_id, 
        FORMAT(txn_date, 'yyyy-MM') AS month_ ,
        COUNT(txn_type) AS count_customers
    FROM customer_transactions
    WHERE txn_type = 'deposit'
    GROUP BY FORMAT(txn_date, 'yyyy-MM'), customer_id
    HAVING COUNT(txn_type) > 1
),

purchase_or_withdrawal AS(
    SELECT 
      customer_id, 
      FORMAT(txn_date, 'yyyy-MM') AS month_ , 
      COUNT(txn_type) AS count_customers
    FROM customer_transactions
    WHERE txn_type IN  ('purchase','withdrawal')
    GROUP BY FORMAT(txn_date, 'yyyy-MM'), customer_id
)

SELECT prw.month_ , COUNT(DISTINCT(prw.count_customers)) AS total_customers
FROM purchase_or_withdrawal AS prw
INNER JOIN more_than_one_deposit AS mtod ON prw.customer_id = mtod.customer_id AND prw.month_ = mtod.month_
GROUP BY prw.month_
ORDER BY prw.month_
;


-- 4.What is the closing balance for each customer at the end of the month?

WITH running_balance AS (
  SELECT
    customer_id,
    txn_date,
    FORMAT(txn_date, 'yyyy-MM') AS month,
    SUM(txn_amount) OVER ( PARTITION BY customer_id ORDER BY txn_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS balance
  FROM customer_transactions
),

month_end AS (
  SELECT customer_id, month, MAX(txn_date) AS last_txn_date
  FROM running_balance
  GROUP BY customer_id, month
)

SELECT rb.customer_id, rb.month, rb.balance AS closing_balance
FROM running_balance AS rb
INNER JOIN month_end AS me ON rb.customer_id = me.customer_id AND rb.month = me.month AND rb.txn_date = me.last_txn_date
ORDER BY rb.customer_id, rb.month
;


-- 5.What is the percentage of customers who increase their closing balance by more than 5%?

WITH closing_balances AS (
  SELECT
    customer_id,
    month,
    balance AS closing_balance,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY month) AS rn
  FROM (
    SELECT rb.customer_id, rb.month, rb.balance
    FROM (
      SELECT
        customer_id,
        txn_date,
        FORMAT(txn_date, 'yyyy-MM') AS month,
        SUM(txn_amount) OVER (PARTITION BY customer_id ORDER BY txn_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS balance
      FROM customer_transactions
    ) AS rb
    INNER JOIN (
      SELECT 
        customer_id, 
        FORMAT(txn_date, 'yyyy-MM') AS month, 
        MAX(txn_date) AS last_txn_date
      FROM customer_transactions
      GROUP BY customer_id, FORMAT(txn_date, 'yyyy-MM')
    ) AS me
      ON rb.customer_id = me.customer_id AND rb.month = me.month AND rb.txn_date = me.last_txn_date
    )AS x
),

max_rn_per_customer AS (
  SELECT customer_id, MAX(rn) AS max_rn
  FROM closing_balances
  GROUP BY customer_id

),

first_last_balance AS (
  SELECT
    cb1.customer_id,
    MIN(CASE WHEN cb1.rn = 1 THEN cb1.closing_balance END) AS first_balance,
    MIN(CASE WHEN cb1.rn = mrc.max_rn THEN cb1.closing_balance END) AS last_balance
  FROM closing_balances cb1
  INNER JOIN max_rn_per_customer mrc ON cb1.customer_id = mrc.customer_id
  GROUP BY cb1.customer_id
),

increased_customers AS (
  SELECT customer_id
  FROM first_last_balance
  WHERE last_balance > first_balance * 1.05

)
SELECT CAST(COUNT(ic.customer_id) AS FLOAT) / COUNT(flb.customer_id) * 100 AS percentage_increased
FROM first_last_balance flb
LEFT JOIN increased_customers ic ON flb.customer_id = ic.customer_id
;



--C. Data Allocation Challenge

--To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:

--    Option 1: data is allocated based off the amount of money at the end of the previous month
--    Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
--    Option 3: data is updated real-time

--For this multi-part challenge question - you have been requested to generate the following data elements to help the Data Bank team estimate how much data will need to be provisioned for each option:
-- Using all of the data available - how much data would have been required for each option on a monthly basis?


--    running customer balance column that includes the impact each transaction

SELECT 
  customer_id , 
  SUM(txn_amount) OVER (PARTITION BY customer_id ORDER BY txn_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_balance
FROM customer_transactions
GROUP BY customer_id, txn_date, txn_amount
;

--    customer balance at the end of each month

WITH monthly_balance AS (
  SELECT
    customer_id,
    FORMAT(txn_date, 'yyyy-MM') AS month,
    SUM(txn_amount) AS monthly_amount
  FROM customer_transactions
  GROUP BY customer_id, FORMAT(txn_date, 'yyyy-MM')
)

SELECT
  customer_id,
  month,
  monthly_amount,
  SUM(monthly_amount) OVER ( PARTITION BY customer_id ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS cumulative_balance
FROM monthly_balance
ORDER BY customer_id, month;


--    minimum, average and maximum values of the running balance for each customer

SELECT 
  customer_id, 
  SUM(txn_amount) AS total_balance , 
  AVG(txn_amount) AS average , 
  MAX(txn_amount) AS maximun , 
  MIN(txn_amount) AS minimun
FROM customer_transactions
GROUP BY customer_id
ORDER BY customer_id
;


--D. Extra Challenge

-- Data Bank wants to try another option which is a bit more difficult to implement - they want to calculate data growth using an interest calculation, just like in a traditional savings account you might have with a bank.

-- If the annual interest rate is set at 6% and the Data Bank team wants to reward its customers by increasing their data allocation based off the interest calculated on a daily basis at the end of each day.
-- How much data would be required for this option on a monthly basis?

WITH interest_daily AS (
  SELECT
    customer_id,
    FORMAT(txn_date, 'yyyy-MM') AS month,
    txn_amount * 0.06 / 365 AS daily_interest
  FROM customer_transactions
),
interest_monthly AS (
  SELECT
    customer_id,
    month,
    SUM(daily_interest) AS total_monthly_interest
  FROM interest_daily
  GROUP BY customer_id, month
)
SELECT * FROM interest_monthly;

