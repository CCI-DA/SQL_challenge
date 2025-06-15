
CREATE TABLE runners (
  "runner_id" INTEGER,
  "registration_date" DATE
);


CREATE TABLE customer_orders (
  "order_id" INTEGER,
  "customer_id" INTEGER,
  "pizza_id" INTEGER,
  "exclusions" VARCHAR(4),
  "extras" VARCHAR(4),
  "order_time" DATETIME
);

CREATE TABLE runner_orders (
  "order_id" INTEGER,
  "runner_id" INTEGER,
  "pickup_time" VARCHAR(19),
  "distance" VARCHAR(7),
  "duration" VARCHAR(10),
  "cancellation" VARCHAR(23)
);


CREATE TABLE pizza_names (
  "pizza_id" INTEGER,
  "pizza_name" TEXT
);


CREATE TABLE pizza_recipes (
  "pizza_id" INTEGER,
  "toppings" TEXT
);


CREATE TABLE pizza_toppings (
  "topping_id" INTEGER,
  "topping_name" TEXT
);