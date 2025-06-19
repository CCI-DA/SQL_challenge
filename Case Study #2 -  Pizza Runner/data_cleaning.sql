-- Alter tables TEXT to VARCHAR(25)
ALTER TABLE pizza_names
ALTER COLUMN pizza_name VARCHAR(25)

ALTER TABLE pizza_recipes
ALTER COLUMN toppings VARCHAR(25)

ALTER TABLE pizza_toppings
ALTER COLUMN topping_name VARCHAR(25)


-- Runner_orders has to be cleaned
UPDATE runner_orders
SET distance = REPLACE(REPLACE(distance,'km',''), ' km', '')
;

UPDATE runner_orders
SET duration = REPLACE(REPLACE(REPLACE(duration, 'mins',''), 'minutes',''),'minute','')
;

UPDATE runner_orders
SET cancellation = NULL
WHERE cancellation = ''
;

UPDATE runner_orders
SET cancellation = NULL
WHERE cancellation = 'null'
;
-- Rename columns names 
EXEC sp_rename 'runner_orders.distance', 'distance_km', 'COLUMN';
EXEC sp_rename 'runner_orders.duration', 'duration_min', 'COLUMN';



-- Customer_orders has to be cleaned

UPDATE customer_orders
SET exclusions = NULL
WHERE exclusions = ''
;

UPDATE customer_orders
SET extras = NULL
WHERE extras = ''
;

UPDATE customer_orders
SET exclusions = NULL
WHERE exclusions = 'null'
;

UPDATE customer_orders
SET extras = NULL
WHERE extras = 'null'
;