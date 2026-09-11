-- ============================================================
-- Load customers.csv / transactions.csv into MySQL
-- Run from the mysql client with --local-infile=1, from inside
-- the project's /data folder (or edit the paths below).
-- ============================================================
USE bank_churn_analysis;

SET GLOBAL local_infile = 1;   -- if you get "Loading local data is disabled", run this first

LOAD DATA LOCAL INFILE 'data/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, surname, credit_score, geography, gender, age, tenure_years,
 balance, num_of_products, has_cr_card, is_active_member, estimated_salary,
 exited, signup_date, @churn_date)
SET churn_date = NULLIF(@churn_date, '');

LOAD DATA LOCAL INFILE 'data/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(transaction_id, customer_id, transaction_date, transaction_type, amount);

-- sanity checks
SELECT COUNT(*) AS customer_rows FROM customers;
SELECT COUNT(*) AS transaction_rows FROM transactions;
