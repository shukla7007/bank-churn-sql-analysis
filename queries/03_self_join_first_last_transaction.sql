-- ============================================================
-- First vs. Last Transaction per Customer
-- Technique: self-joins (not aggregate MIN/MAX) to find each customer's
-- earliest and latest transaction, then compare them
--
-- Business question: "How long has each customer been active, and how
-- long has it been since we last saw them?" This is the recency half of
-- an RFM analysis, and directly flags churn-risk accounts (customers who
-- haven't transacted recently but aren't formally marked 'Exited' yet).
--
-- Why a self-join instead of just MIN()/MAX(): this is the classic
-- interview version of the problem — join the transactions table to
-- itself and keep only rows with no earlier/later match, i.e. no
-- "b" row beats "a" on date. Worth knowing both ways; MIN/MAX + GROUP BY
-- is simpler and normally what you'd ship, but self-joins are asked
-- about directly in a lot of SQL interview rounds.
-- ============================================================
USE bank_churn_analysis;

-- The dataset was extracted as of 2026-06-30 (all transactions stop by
-- then) — use that as the "today" anchor instead of CURDATE() so results
-- are reproducible regardless of when you actually run this.
SET @snapshot_date = '2026-06-30';

WITH first_txn AS (
    SELECT DISTINCT a.customer_id, a.transaction_date AS first_transaction_date
    FROM transactions a
    LEFT JOIN transactions b
        ON a.customer_id = b.customer_id
       AND b.transaction_date < a.transaction_date
    WHERE b.transaction_id IS NULL   -- no earlier transaction exists => a is the first
),
last_txn AS (
    SELECT DISTINCT a.customer_id, a.transaction_date AS last_transaction_date
    FROM transactions a
    LEFT JOIN transactions b
        ON a.customer_id = b.customer_id
       AND b.transaction_date > a.transaction_date
    WHERE b.transaction_id IS NULL   -- no later transaction exists => a is the last
)
SELECT
    c.customer_id,
    c.exited,
    c.signup_date,
    f.first_transaction_date,
    l.last_transaction_date,
    DATEDIFF(l.last_transaction_date, f.first_transaction_date) AS active_lifespan_days,
    DATEDIFF(@snapshot_date, l.last_transaction_date)                AS days_since_last_transaction,
    CASE
        WHEN c.exited = 1 THEN 'Churned'
        WHEN DATEDIFF(@snapshot_date, l.last_transaction_date) > 90 THEN 'At risk (inactive 90+ days)'
        ELSE 'Active'
    END AS churn_risk_flag
FROM customers c
JOIN first_txn f ON f.customer_id = c.customer_id
JOIN last_txn  l ON l.customer_id = c.customer_id
ORDER BY active_lifespan_days DESC;


-- ---------------------------------------------------------------
-- Equivalent, simpler MIN()/MAX() version — same result, worth having
-- in your back pocket to show you know both approaches and when to
-- prefer the aggregate one (better performance on large tables, since
-- the self-join above is an O(n^2)-ish comparison without a tight index).
-- ---------------------------------------------------------------
WITH bounds AS (
    SELECT customer_id,
           MIN(transaction_date) AS first_transaction_date,
           MAX(transaction_date) AS last_transaction_date
    FROM transactions
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.exited,
    b.first_transaction_date,
    b.last_transaction_date,
    DATEDIFF(b.last_transaction_date, b.first_transaction_date) AS active_lifespan_days,
    DATEDIFF(@snapshot_date, b.last_transaction_date)                AS days_since_last_transaction
FROM customers c
JOIN bounds b ON b.customer_id = c.customer_id
ORDER BY active_lifespan_days DESC;
