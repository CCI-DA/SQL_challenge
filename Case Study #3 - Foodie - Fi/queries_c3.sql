-- A. DATA ANALYSTIC QUESTIONS

--1. How many customers has Foodie-Fi ever had?

SELECT COUNT(DISTINCT(customer_id)) AS customers
FROM subscriptions
;


--2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value

SELECT 
    DATEFROMPARTS(YEAR(s.start_date), MONTH(s.start_date), 1) AS month_start,
    COUNT(*) AS number_trials
FROM subscriptions AS s
INNER JOIN plans AS p ON s.plan_id = p.plan_id 
WHERE p.plan_name = 'trial'
GROUP BY DATEFROMPARTS(YEAR(s.start_date), MONTH(s.start_date), 1)
ORDER BY month_start
;


--3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

SELECT p.plan_name, COUNT(*) AS plans_after_2020
FROM subscriptions AS s
INNER JOIN plans AS p ON s.plan_id = p.plan_id
WHERE s.start_date >= '2021-01-01'
GROUP BY  p.plan_name
ORDER BY plans_after_2020 DESC
;


--4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

WITH customers_churned AS(
        SELECT DISTINCT s.customer_id 
        FROM subscriptions AS s
        INNER JOIN plans AS p ON s.plan_id = p.plan_id
        WHERE p.plan_name = 'churn'
)

SELECT 
    COUNT(customer_id) AS total_churned,
    CAST(ROUND(COUNT(customer_id) * 100.0 / 
          (SELECT COUNT(DISTINCT customer_id) FROM subscriptions), 1) AS DECIMAL(5,1)) AS churn_percentage
FROM customers_churned 
;


--5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?

WITH ranked_plans AS (
    SELECT 
        s.customer_id,
        p.plan_name,
        s.start_date,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.start_date) AS rn
    FROM subscriptions AS s
    INNER JOIN plans AS p ON s.plan_id = p.plan_id
),

first_and_second_plan AS (
    SELECT 
        customer_id,
        MAX(CASE WHEN rn = 1 THEN plan_name END) AS first_plan,
        MAX(CASE WHEN rn = 2 THEN plan_name END) AS second_plan
    FROM ranked_plans
    GROUP BY customer_id
)

SELECT 
    COUNT(*) AS churn_after_trial,
    CAST(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions), 0) AS DECIMAL(3,0)) AS churn_percentage
FROM first_and_second_plan
WHERE first_plan = 'trial' AND second_plan = 'churn';
;


--6. What is the number and percentage of customer plans after their initial free trial?

WITH ranked_plans AS (
    SELECT 
        s.customer_id,
        p.plan_name,
        s.start_date,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.start_date) AS rn
    FROM subscriptions AS s
    INNER JOIN plans AS p ON s.plan_id = p.plan_id
),

first_and_second_plan AS (
    SELECT 
        customer_id,
        MAX(CASE WHEN rn = 1 THEN plan_name END) AS first_plan,
        MAX(CASE WHEN rn = 2 THEN plan_name END) AS second_plan
    FROM ranked_plans
    GROUP BY customer_id
),
customers_with_trial AS (
    SELECT *
    FROM first_and_second_plan
    WHERE first_plan = 'trial' AND second_plan IS NOT NULL
)

SELECT second_plan, 
    COUNT(*) AS scnd,
    CAST(ROUND(COUNT(*)*100 / 
                (SELECT COUNT(*) FROM customers_with_trial) ,1) AS DECIMAL(4,0)) AS percentage_
    FROM first_and_second_plan
    GROUP BY second_plan
    ORDER BY scnd DESC
;


--7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

WITH ranked_subscriptions AS (
    SELECT 
        s.customer_id,
        p.plan_name,
        s.start_date,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.start_date DESC) AS rn
    FROM subscriptions AS s
    INNER JOIN plans AS p ON s.plan_id = p.plan_id
    WHERE s.start_date <= '2020-12-31'
)

SELECT 
    plan_name,
    COUNT(*) AS customer_count,
    CAST(ROUND(COUNT(*) * 100.0 / 
          (SELECT COUNT(DISTINCT customer_id) 
           FROM subscriptions 
           WHERE start_date <= '2020-12-31'), 1) AS DECIMAL(3,1)) AS percentage
FROM ranked_subscriptions
WHERE rn = 1
GROUP BY plan_name
ORDER BY customer_count DESC;
;


--8. How many customers have upgraded to an annual plan in 2020?

WITH ordered_plans AS (
  SELECT
    s.customer_id,
    p.plan_name,
    s.start_date,
    ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.start_date) AS rn
  FROM subscriptions AS s
  JOIN plans p ON p.plan_id = s.plan_id
),

first_annual AS (
  SELECT
    customer_id,
    plan_name,
    start_date
  FROM ordered_plans
  WHERE plan_name = 'pro annual'
    AND start_date BETWEEN '2020-01-01' AND '2020-12-31'
)

SELECT COUNT(DISTINCT fa.customer_id) AS upgraded_to_annual_2020
FROM first_annual AS fa
WHERE EXISTS (
    SELECT 1
    FROM ordered_plans AS op
    WHERE op.customer_id = fa.customer_id
      AND op.start_date < fa.start_date
      AND op.plan_name <> 'pro annual'
);


--9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

WITH first_dates AS (
    SELECT 
        s.customer_id,
        MIN(s.start_date) AS first_subscription_date
    FROM subscriptions s
    GROUP BY s.customer_id
),

first_annual_dates AS (
    SELECT 
        s.customer_id,
        MIN(s.start_date) AS first_annual_date
    FROM subscriptions s
    INNER JOIN plans p ON s.plan_id = p.plan_id
    WHERE p.plan_name = 'pro annual'
    GROUP BY s.customer_id
)

SELECT 
    AVG(DATEDIFF(day, fd.first_subscription_date, fad.first_annual_date)) AS avg_days_to_annual
FROM first_dates fd
INNER JOIN first_annual_dates fad ON fd.customer_id = fad.customer_id
;


--10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

WITH first_day AS (
    SELECT 
        s.customer_id,
        s.start_date AS first_date,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.start_date) AS r_1
    FROM subscriptions s
),
anual_plan_day AS (
    SELECT 
        s.customer_id,
        s.start_date AS annual_date,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.start_date) AS r_2
    FROM subscriptions s
    JOIN plans p ON s.plan_id = p.plan_id
    WHERE p.plan_name = 'pro annual'
),
diffs AS (
    SELECT 
        apd.customer_id,
        DATEDIFF(DAY, fd.first_date, apd.annual_date) AS days_diff
    FROM anual_plan_day apd
    JOIN first_day fd ON apd.customer_id = fd.customer_id
    WHERE fd.r_1 = 1 AND apd.r_2 = 1
),
bucketed AS (
    SELECT 
        customer_id,
        days_diff,
        FLOOR(days_diff / 30) AS bucket
    FROM diffs
)

SELECT 
    CONCAT(bucket * 30 + 1, '-', (bucket + 1) * 30, ' days') AS day_range,
    COUNT(*) AS customers
FROM bucketed
GROUP BY bucket
ORDER BY bucket
;


--11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

WITH pro_monthly AS(
    SELECT 
    s.customer_id ,
    s.start_date AS pro_start
    FROM plans AS p
    INNER JOIN subscriptions AS s ON p.plan_id = s.plan_id
    WHERE p.plan_name = 'pro monthly' AND s.start_date BETWEEN '2021-01-01' AND '2021-12-31'
),
    basic_monthly AS(
    SELECT 
    s.customer_id , 
    s.start_date AS basic_start
    FROM plans AS p
    INNER JOIN subscriptions AS s ON p.plan_id = s.plan_id
    WHERE p.plan_name = 'basic monthly' AND s.start_date BETWEEN '2021-01-01' AND '2021-12-31'
)

SELECT COUNT(DISTINCT pro.customer_id) AS downgraded_customers
FROM pro_monthly AS pro
INNER JOIN basic_monthly AS basic ON pro.customer_id = basic.customer_id
  AND basic.basic_start > pro.pro_start
;


-- B. CHALLENGE PAYMENT QUESTION

--The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

--  monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
--  upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
--  upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
--  once a customer churns they will no longer make payments

-- Example outputs for this table might look like the following:



-- C. OUTSIDE THE BOX QUESTIONS

--The following are open ended questions which might be asked during a technical interview for this case study - there are no right or wrong answers, but answers that make sense from both a technical and a business perspective make an amazing impression!

--1. How would you calculate the rate of growth for Foodie-Fi?
--2. What key metrics would you recommend Foodie-Fi management to track over time to assess performance of their overall business?
--3. What are some key customer journeys or experiences that you would analyse further to improve customer retention?
--4. If the Foodie-Fi team were to create an exit survey shown to customers who wish to cancel their subscription, what questions would you include in the survey?
--5. What business levers could the Foodie-Fi team use to reduce the customer churn rate? How would you validate the effectiveness of your ideas?
