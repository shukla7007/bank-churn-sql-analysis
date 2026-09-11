-- ============================================================
-- Bank Customer Churn Analysis — Schema
-- MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS bank_churn_analysis;
USE bank_churn_analysis;

DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS customers;

-- One row per customer. Sourced from the classic "Churn_Modelling" bank
-- dataset (10,000 customers), extended with signup_date / churn_date
-- (see /data/README in the project root for how those were derived).
CREATE TABLE customers (
    customer_id       BIGINT UNSIGNED PRIMARY KEY,
    surname           VARCHAR(50),
    credit_score      SMALLINT UNSIGNED,
    geography         VARCHAR(50)     NOT NULL,
    gender            VARCHAR(10),
    age               TINYINT UNSIGNED,
    tenure_years      TINYINT UNSIGNED,
    balance           DECIMAL(14,2)   NOT NULL DEFAULT 0,
    num_of_products   TINYINT UNSIGNED,
    has_cr_card       TINYINT(1),
    is_active_member  TINYINT(1),
    estimated_salary  DECIMAL(14,2),
    exited            TINYINT(1)      NOT NULL,   -- 1 = churned, 0 = retained
    signup_date       DATE            NOT NULL,
    churn_date        DATE            NULL,        -- NULL if still active
    INDEX idx_signup_date (signup_date),
    INDEX idx_geography (geography),
    INDEX idx_exited (exited)
) ENGINE = InnoDB;

-- One row per transaction. ~626k rows across ~9,900 customers who have at
-- least one transaction (83 customers churned/signed up with none).
CREATE TABLE transactions (
    transaction_id    BIGINT UNSIGNED PRIMARY KEY,
    customer_id       BIGINT UNSIGNED NOT NULL,
    transaction_date  DATE            NOT NULL,
    transaction_type  VARCHAR(20)     NOT NULL,   -- deposit / withdrawal / transfer / bill_payment
    amount            DECIMAL(10,2)   NOT NULL,
    CONSTRAINT fk_transactions_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_customer_date (customer_id, transaction_date),  -- covers self-joins & window queries
    INDEX idx_transaction_date (transaction_date)
) ENGINE = InnoDB;
