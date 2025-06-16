-- Alter tables TEXT to VARCHAR(25)

ALTER TABLE pizza_names
ALTER COLUMN pizza_name VARCHAR(25)

ALTER TABLE pizza_recipes
ALTER COLUMN toppings VARCHAR(25)

ALTER TABLE pizza_toppings
ALTER COLUMN topping_name VARCHAR(25)