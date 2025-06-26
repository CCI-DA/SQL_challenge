-- A. Pizza Metrics

-- 1. How many pizzas were ordered?

SELECT COUNT(pizza_id) AS total_pizzas_ordered
FROM customer_orders
;


-- 2. How many unique customer orders were made?

SELECT COUNT(DISTINCT(customer_id)) AS total_customers
FROM customer_orders
;


-- 3. How many successful orders were delivered by each runner?

SELECT runner_id, COUNT(order_id) AS successful_orders_delivered
FROM runner_orders
WHERE cancellation IS NULL 
GROUP BY runner_id
; 


-- 4. How many of each type of pizza was delivered?

SELECT co.pizza_id , COUNT(co.pizza_id) AS total_per_type
FROM customer_orders AS co 
INNER JOIN runner_orders AS ro ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY co.pizza_id
;


-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT co.customer_id, pn.pizza_name , COUNT(*) AS times_ordered
FROM customer_orders AS co 
INNER JOIN runner_orders AS ro ON co.order_id = ro.order_id
INNER JOIN pizza_names as pn ON co.pizza_id = pn.pizza_id
WHERE ro.cancellation IS NULL
GROUP BY co.customer_id, pn.pizza_name
;


-- 6. What was the maximum number of pizzas delivered in a single order?

SELECT TOP 1
        co.order_id , COUNT(*) AS max_number_pizzas_delivered
FROM customer_orders AS co 
INNER JOIN runner_orders AS ro ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY co.order_id
ORDER BY max_number_pizzas_delivered DESC
;


-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

WITH pizza_delivered_changes AS(
     SELECT co.customer_id ,
        (CASE
            WHEN co.exclusions IS NULL AND co.extras IS NULL THEN 'No changes'
            ELSE 'At least 1 change'
        END) AS changes
    FROM customer_orders AS co
    INNER JOIN runner_orders AS ro ON co.order_id = ro.order_id
    WHERE ro.cancellation IS NULL
)

SELECT customer_id , changes , COUNT(*) AS total_pizzas
FROM pizza_delivered_changes
GROUP BY customer_id, changes
; 


-- 8. How many pizzas were delivered that had both exclusions and extras?

SELECT COUNT(*) AS pizzas_delivered_with_exclusions_extras 
FROM customer_orders AS co
INNER JOIN runner_orders AS ro ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL AND co.exclusions IS NOT NULL AND co.extras IS NOT NULL 
;


-- 9. What was the total volume of pizzas ordered for each hour of the day?

SELECT DATEPART(HOUR,order_time) AS hour_of_day, COUNT(*) AS volume_pizzas_ordered
FROM customer_orders 
GROUP BY DATEPART(HOUR,order_time)
;


-- 10.What was the volume of orders for each day of the week?

SELECT DATENAME(WEEKDAY,order_time) AS day_of_week, COUNT(*) AS volume_orders
FROM customer_orders
GROUP BY DATENAME(WEEKDAY, order_time)
;



-- B. Runner and Customer Experience

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

SELECT 
    DATEADD(DAY, 7 * FLOOR(DATEDIFF(DAY, '2021-01-01', registration_date) / 7), '2021-01-01') AS week_start,
    COUNT(*) AS runners_signed_up
FROM runners
WHERE registration_date >= '2021-01-01'
GROUP BY DATEADD(DAY, 7 * FLOOR(DATEDIFF(DAY, '2021-01-01', registration_date) / 7), '2021-01-01')
ORDER BY week_start
;


-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT ro.runner_id, AVG(DATEDIFF(MINUTE,co.order_time, ro.pickup_time)) AS avg_min
FROM customer_orders AS co
INNER JOIN runner_orders AS ro ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY ro.runner_id
;


-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

WITH time_to_prepare AS(
    SELECT 
        co.order_id,
        co.pizza_id, 
        DATEDIFF(MINUTE,co.order_time, ro.pickup_time) AS time_to_prepare
    FROM customer_orders AS co
    INNER JOIN runner_orders AS ro ON co.order_id = ro.order_id
    WHERE ro.cancellation IS NULL
)

SELECT order_id, COUNT(pizza_id) AS number_of_pizzas ,time_to_prepare
FROM time_to_prepare
GROUP BY order_id, time_to_prepare
;
-- Yes, it usually takes 10 minutes to make one pizza. 
-- But if the quantity increases, the time increases too.


-- 4. What was the average distance travelled for each customer?

WITH distinct_orders AS(
    SELECT DISTINCT co.order_id , co.customer_id, ro.distance_km
    FROM runner_orders AS ro
    INNER JOIN customer_orders AS co ON ro.order_id = co.order_id
    WHERE ro.cancellation IS NULL
)

SELECT customer_id , AVG(CAST(distance_km AS FLOAT)) AS avg_distance_km
FROM distinct_orders
GROUP BY customer_id
;


-- 5. What was the difference between the longest and shortest delivery times for all orders?

SELECT MIN(duration_min) AS min_duration,
       MAX(duration_min) AS max_duration , 
      (MAX(CAST(duration_min AS INT))- MIN(CAST(duration_min AS INT))) AS difference_btw_delivery_times
FROM runner_orders ro
INNER JOIN customer_orders AS co ON ro.order_id = co.order_id
WHERE ro.cancellation IS NULL
;


-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
-- velocity = distance traveled / time taken

SELECT runner_id,
       order_id,
       (CAST(distance_km AS FLOAT)/CAST(duration_min AS FLOAT)*60) AS avg_speed_km_hour
FROM runner_orders
WHERE cancellation IS NULL
;


-- 7. What is the successful delivery percentage for each runner?

WITH count_orders AS(
    SELECT 
        (CASE
            WHEN cancellation IS NULL THEN 1
            ELSE 0
        END) AS clasification_orders ,
        runner_id,
        order_id
    FROM runner_orders
)

SELECT 
    runner_id,
    SUM(clasification_orders)*100/COUNT(order_id) AS successful_delivery_percentage
FROM count_orders
GROUP BY runner_id
;



-- C.Ingredient Optimisation

-- 1.What are the standard ingredients for each pizza? 
WITH toppings_split AS(
    SELECT pizza_id,  CAST(splt.value AS INT) AS toppings_splt
    FROM pizza_recipes 
    CROSS APPLY string_split(toppings, ',') AS splt
)

SELECT pn.pizza_name, toppings_splt
FROM toppings_split AS ts
INNER JOIN pizza_toppings AS pt ON ts.toppings_splt = pt.topping_id
INNER JOIN pizza_names AS pn ON pn.pizza_id = ts.pizza_id
;


-- 2. What was the most commonly added extra?

WITH toppings_split AS(
    SELECT CAST(splt.value AS INT) AS extras_splt
    FROM customer_orders
    CROSS APPLY string_split(extras, ',') AS splt
)

SELECT TOP 1
    pt.topping_name,
    COUNT(extras_splt) as times_added
FROM toppings_split AS ts
INNER JOIN pizza_toppings AS pt ON ts.extras_splt = pt.topping_id
GROUP BY pt.topping_name
ORDER BY times_added DESC
;


-- 3.What was the most common exclusion?

WITH exclusions_split AS(
    SELECT CAST(splt.value AS INT) AS exclusions_splt
    FROM customer_orders
    CROSS APPLY string_split(exclusions, ',') AS splt
)

SELECT TOP 1
    pt.topping_name,
    COUNT(exclusions_splt) as times_added
FROM exclusions_split AS ts
INNER JOIN pizza_toppings AS pt ON ts.exclusions_splt = pt.topping_id
GROUP BY pt.topping_name
ORDER BY times_added DESC
;


-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--      Meat Lovers
--      Meat Lovers - Exclude Beef
--      Meat Lovers - Extra Bacon
--      Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

WITH pizza_type AS (
        SELECT co.order_id, pn.pizza_name
        FROM customer_orders AS co 
        INNER JOIN pizza_names AS pn ON co.pizza_id = pn.pizza_id
        INNER JOIN runner_orders AS ro ON co.order_id = ro.order_id
        WHERE ro.cancellation IS NULL
),
    extras_list AS(
        SELECT co.order_id, pt.topping_name
        FROM customer_orders AS co
        CROSS APPLY string_split(extras , ',') AS extras_splt
        INNER JOIN pizza_toppings AS pt ON TRY_CAST(extras_splt.value AS INT) = pt.topping_id
        WHERE extras IS NOT NULL
),
    exclusion_list AS(
        SELECT  co.order_id, pt.topping_name
        FROM customer_orders AS co
        CROSS APPLY string_split(exclusions , ',') AS exclusions_splt
        INNER JOIN pizza_toppings AS pt ON TRY_CAST(exclusions_splt.value AS INT) = pt.topping_id
        WHERE exclusions IS NOT NULL
),
    combined AS(
        SELECT 
            pt.order_id,
            pt.pizza_name,
            STRING_AGG('Exclude ' + el.topping_name, ', ') AS excludes,
            STRING_AGG( 'Extra ' + ex.topping_name, ', ') AS extras
        FROM pizza_type AS pt
        LEFT JOIN exclusion_list AS el ON pt.order_id = el.order_id
        LEFT JOIN extras_list AS ex ON pt.order_id = ex.order_id
        GROUP BY pt.order_id, pt.pizza_name
        )

SELECT 
    order_id,
    (CASE
        WHEN excludes IS NULL AND extras IS NULL THEN pizza_name
        WHEN excludes IS NOT NULL AND extras IS NULL THEN pizza_name + ' - ' + excludes
        WHEN excludes IS NULL AND extras IS NOT NULL THEN pizza_name + ' - ' + extras
        ELSE pizza_name + ' - ' + excludes + ' - ' + extras
    END) AS order_item
FROM combined
ORDER BY order_id
;


-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--     For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH base_toppings AS (
    SELECT co.order_id, pr.pizza_id, CAST(base_topp_splt.value AS INT) AS topping_id
    FROM customer_orders AS co
    JOIN pizza_recipes AS pr ON co.pizza_id = pr.pizza_id
    CROSS APPLY string_split(pr.toppings, ',') AS base_topp_splt
),
extra_toppings AS (
    SELECT co.order_id, CAST(extra_splt.value AS INT) AS topping_id
    FROM customer_orders AS co
    CROSS APPLY string_split(co.extras, ',') AS extra_splt
),
combined_toppings AS (
    SELECT bt.order_id, bt.topping_id, 'base' AS source
    FROM base_toppings AS bt
    UNION ALL
    SELECT et.order_id, et.topping_id, 'extra' AS source
    FROM extra_toppings AS et
),
tagged_toppings AS (
    SELECT 
        ct.order_id,
        ct.topping_id,
        pt.topping_name,
        COUNT(*) OVER(PARTITION BY ct.order_id, ct.topping_id) AS count_per_topping
    FROM combined_toppings AS ct
    JOIN pizza_toppings AS pt ON ct.topping_id = pt.topping_id
),
formatted_toppings AS (
    SELECT 
        order_id,
        (CASE 
            WHEN count_per_topping = 2 THEN '2x' + topping_name
            ELSE topping_name
        END) AS topping_display
    FROM tagged_toppings
    GROUP BY order_id, topping_name, count_per_topping
),
final_output AS (
    SELECT 
        co.order_id,
        pn.pizza_name,
        STRING_AGG(ft.topping_display, ', ') WITHIN GROUP (ORDER BY ft.topping_display) AS ingredient_list
    FROM customer_orders co
    JOIN pizza_names pn ON co.pizza_id = pn.pizza_id
    JOIN formatted_toppings ft ON co.order_id = ft.order_id
    GROUP BY co.order_id, pn.pizza_name
)
SELECT 
    pizza_name + ': ' + ingredient_list AS order_description
FROM final_output
ORDER BY pizza_name;



-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

WITH delivered_orders AS (
    SELECT 
        co.order_id, 
        co.pizza_id, 
        co.extras, 
        co.exclusions
    FROM customer_orders AS co
    JOIN runner_orders AS ro ON co.order_id = ro.order_id
    WHERE ro.cancellation IS NULL
),
base_toppings AS (
    SELECT pr.pizza_id, TRY_CAST(base_topp_splt.value AS INT) AS topping
    FROM pizza_recipes AS pr
    CROSS APPLY STRING_SPLIT(pr.toppings, ',') AS base_topp_splt
),
base_toppings_per_order AS (
    SELECT do.order_id, bt.topping
    FROM delivered_orders AS do
    JOIN base_toppings AS bt ON do.pizza_id = bt.pizza_id
),
exclusions_per_order AS (
    SELECT do.order_id, TRY_CAST(exclusion_splt.value AS INT) AS exclusion
    FROM delivered_orders AS do
    CROSS APPLY STRING_SPLIT(do.exclusions, ',') AS exclusion_splt
    WHERE do.exclusions IS NOT NULL
),
extras_per_order AS (
    SELECT do.order_id, TRY_CAST(extra_splt.value AS INT) AS extra
    FROM delivered_orders AS do
    CROSS APPLY STRING_SPLIT(do.extras, ',') AS extra_splt
    WHERE do.extras IS NOT NULL
),
final_base_toppings AS (
    SELECT bto.order_id, bto.topping
    FROM base_toppings_per_order AS bto
    LEFT JOIN exclusions_per_order AS epo ON bto.order_id = epo.order_id AND bto.topping = epo.exclusion
    WHERE epo.exclusion IS NULL
),
all_toppings AS (
    SELECT topping FROM final_base_toppings
    UNION ALL
    SELECT extra FROM extras_per_order
)

SELECT topping, COUNT(*) AS total_uses
FROM all_toppings
GROUP BY topping
ORDER BY total_uses DESC
;



-- D. Pricing and Ratings
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

SELECT 
    pn.pizza_name,
    SUM((CASE
            WHEN co.pizza_id = 1 THEN 12
            ELSE 10
        END)) AS total_price_per_pizza 
FROM customer_orders AS co
INNER JOIN runner_orders AS ro ON co.order_id = ro.order_id
INNER JOIN pizza_names AS pn ON co.pizza_id = pn.pizza_id
WHERE ro.cancellation IS NULL
GROUP BY pn.pizza_name
;


-- 2. What if there was an additional $1 charge for any pizza extras?

WITH extras_count AS(
        SELECT co.order_id, co.pizza_id, COUNT(*) AS num_extras
        FROM customer_orders AS co
        CROSS APPLY string_split(extras, ',') AS s
        WHERE extras IS NOT NULL
        GROUP BY co.order_id,co.pizza_id
),
    base_prices AS (
        SELECT
            co.order_id,
            co.pizza_id,
            (CASE
                WHEN co.pizza_id = 1 THEN 12 -- Meat Lovers
                WHEN co.pizza_id = 2 THEN 10 -- Vegetarian
            END) AS base_price
    FROM customer_orders AS co
),
    final_prices AS (
    SELECT bp.order_id, bp.base_price + ISNULL(ec.num_extras, 0) AS total_price
    FROM base_prices AS bp
    LEFT JOIN extras_count AS ec ON bp.order_id = ec.order_id
)

SELECT SUM(fp.total_price) AS total_revenue_with_extras
FROM final_prices AS fp
JOIN runner_orders AS ro ON fp.order_id = ro.order_id
WHERE ro.cancellation IS NULL;
;


--3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

--CREATE TABLE rating_runner(
    --"runner_id" INTEGER,
   -- "order_id" INTEGER,
   -- "customer_id" INTEGER,
   -- "rating" TINYINT NOT NULL CHECK (rating between 1 and 5),
  --  "rating_date" DATETIME DEFAULT GETDATE()
--);

--INSERT INTO rating_runner 
  --  ("runner_id","order_id","customer_id","rating","rating_date")
--VALUES
  -- (1,1,101,3,'2021-01-01'),
   -- (1,2,101,5,'2021-01-01'),
   -- (1,3,102,3,'2021-01-03'),
    --(2,4,103,2,'2021-01-04'),
   -- (3,5,104,5,'2021-01-08'),
   -- (2,7,105,5,'2021-01-08'),
   -- (2,8,102,5,'2021-01-10'),
   -- (1,10,104,5,'2021-01-11');


-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
--  customer_id
--  order_id
--  runner_id
--  rating
--  order_time
--  pickup_time
--  Time between order and pickup
--  Delivery duration
--  Average speed
--  Total number of pizzas

WITH pizza_counts AS (
    SELECT order_id, customer_id, COUNT(*) AS total_pizzas
    FROM customer_orders
    GROUP BY order_id, customer_id 
)

SELECT DISTINCT 
    co.customer_id,
    co.order_id,
    ro.runner_id,
    rr.rating,
    co.order_time,
    ro.pickup_time,
    DATEDIFF(MINUTE, co.order_time, ro.pickup_time) AS time_btw_order_and_pickup,
    ro.duration_min AS delivery_duration,
    TRY_CAST(ro.distance_km AS FLOAT) / TRY_CAST(ro.duration_min AS FLOAT) * 60 AS avg_speed,
    pc.total_pizzas AS total_number_of_pizzas
FROM runner_orders AS ro
INNER JOIN customer_orders AS co ON ro.order_id = co.order_id
INNER JOIN pizza_counts AS pc ON co.order_id = pc.order_id
INNER JOIN rating_runner AS rr ON ro.order_id = rr.order_id 
WHERE ro.cancellation IS NULL;
;


-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
WITH price_per_order AS (
    SELECT 
        co.order_id,
        SUM(CASE 
                WHEN co.pizza_id = 1 THEN 12
                ELSE 10
            END) AS total_revenue,
        CAST(ro.distance_km AS FLOAT) * 0.30 AS total_runner_payment
    FROM customer_orders AS co
    JOIN runner_orders AS ro ON co.order_id = ro.order_id
    WHERE ro.cancellation IS NULL
    GROUP BY co.order_id, ro.distance_km
)

SELECT 
    SUM(total_revenue) AS total_revenue,
    SUM(total_runner_payment) AS total_runner_payment,
    SUM(total_revenue - total_runner_payment) AS profit
FROM price_per_order;


--E. Bonus Questions
--If Danny wants to expand his range of pizzas - how would this impact the existing data design? 
--Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?

--INSERT INTO pizza_names
  --  ("pizza_id","pizza_name")
--VALUES
   -- (3,'Supreme')
-- ;

--INSERT INTO pizza_recipes
   -- ("pizza_id","toppings")
-- VALUES 
  --  (3, '1,2,3,4,5,6,7,8,9,10')
;

-- It has a direct impact on the database design.
