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
WHERE end_date < '9999-12-31' AND customer_id = 1
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
    SELECT customer_id , SUM(txn_amount) AS total_amount , COUNT(*) AS total_deposits
    FROM customer_transactions
    WHERE txn_type = 'deposit'
    GROUP BY customer_id
)

SELECT  AVG(total_deposits) avg_total_deposits , AVG(total_amount) AS avg_total_amount
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
    SELECT customer_id, 
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

WITH closing_balance AS(
SELECT
  customer_id,
  FORMAT(txn_date, 'yyyy-MM') AS month,
  SUM(txn_amount) OVER (PARTITION BY customer_id  ORDER BY FORMAT(txn_date, 'yyyy-MM')
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS closing_balance
FROM customer_transactions
GROUP BY customer_id, FORMAT(txn_date, 'yyyy-MM'), txn_amount
)

SELECT customer_id , month, SUM( closing_balance)
FROM closing_balance
GROUP BY month,customer_id
;

SELECT *
FROM customer_transactions
WHERE customer_id = 2
;



-- 5.What is the percentage of customers who increase their closing balance by more than 5%?














--C. Data Allocation Challenge

--To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:

--    Option 1: data is allocated based off the amount of money at the end of the previous month
--    Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
--    Option 3: data is updated real-time

--For this multi-part challenge question - you have been requested to generate the following data elements to help the Data Bank team estimate how much data will need to be provisioned for each option:

--    running customer balance column that includes the impact each transaction
--    customer balance at the end of each month
--    minimum, average and maximum values of the running balance for each customer

-- Using all of the data available - how much data would have been required for each option on a monthly basis?


--D. Extra Challenge

-- Data Bank wants to try another option which is a bit more difficult to implement - they want to calculate data growth using an interest calculation, just like in a traditional savings account you might have with a bank.

-- If the annual interest rate is set at 6% and the Data Bank team wants to reward its customers by increasing their data allocation based off the interest calculated on a daily basis at the end of each day, how much data would be required for this option on a monthly basis?

-- Special notes:

--  Data Bank wants an initial calculation which does not allow for compounding interest, however they may also be interested in a daily compounding interest calculation so you can try to perform this calculation if you have the stamina!


-- Extension Request

-- The Data Bank team wants you to use the outputs generated from the above sections to create a quick Powerpoint presentation which will be used as marketing materials for both external investors who might want to buy Data Bank shares and new prospective customers who might want to bank with Data Bank.

--  Using the outputs generated from the customer node questions, generate a few headline insights which Data Bank might use to market it’s world-leading security features to potential investors and customers.

--  With the transaction analysis - prepare a 1 page presentation slide which contains all the relevant information about the various options for the data provisioning so the Data Bank management team can make an informed decision.
