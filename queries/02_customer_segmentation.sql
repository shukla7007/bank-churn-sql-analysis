-- ============================================================
-- Customer Value Segmentation
-- Technique: RANK() and NTILE() window functions
--
-- Business question: "Who are our highest-value customers overall, and who
-- are the top customers within each market (geography)?" This is what a
-- retention/marketing team uses to prioritize outreach — e.g. white-glove
-- treatment for churn-risk customers in the top quartile.
-- ============================================================
USE bank_churn_analysis;

WITH customer_value AS (
    SELECT
        c.customer_id,
        c.geography,
        c.balance,
        c.exited,
        COALESCE(SUM(t.amount), 0) AS total_txn_value,
        COUNT(t.transaction_id)    AS txn_count
    FROM customers c
    LEFT JOIN transactions t ON t.customer_id = c.customer_id
    GROUP BY c.customer_id, c.geography, c.balance, c.exited
),
ranked AS (
    SELECT
        customer_id, geography, balance, total_txn_value, txn_count, exited,
        -- overall value quartile across the whole customer base (1 = top spenders)
        NTILE(4) OVER (ORDER BY total_txn_value DESC)                      AS value_quartile,
        -- rank within each customer's own market — RANK() leaves gaps on ties,
        -- which is what you want here (ties share a rank, next rank skips)
        RANK() OVER (PARTITION BY geography ORDER BY total_txn_value DESC) AS rank_in_geography
    FROM customer_value
)
SELECT
    customer_id, geography, balance, total_txn_value, txn_count, exited,
    value_quartile,
    CASE value_quartile
        WHEN 1 THEN 'Platinum'
        WHEN 2 THEN 'Gold'
        WHEN 3 THEN 'Silver'
        ELSE 'Bronze'
    END AS value_tier,
    rank_in_geography
FROM ranked
ORDER BY value_quartile, rank_in_geography;


-- ---------------------------------------------------------------
-- Follow-up: are top-value (Platinum) customers actually more or less
-- likely to churn? A one-query gut check that's usually the first thing
-- asked back in a "walk me through this project" interview.
-- ---------------------------------------------------------------
WITH customer_value AS (
    SELECT
        c.customer_id,
        c.exited,
        COALESCE(SUM(t.amount), 0) AS total_txn_value
    FROM customers c
    LEFT JOIN transactions t ON t.customer_id = c.customer_id
    GROUP BY c.customer_id, c.exited
),
tiered AS (
    SELECT
        customer_id,
        exited,
        CASE NTILE(4) OVER (ORDER BY total_txn_value DESC)
            WHEN 1 THEN 'Platinum'
            WHEN 2 THEN 'Gold'
            WHEN 3 THEN 'Silver'
            ELSE 'Bronze'
        END AS value_tier
    FROM customer_value
)
SELECT
    value_tier,
    COUNT(*)                                            AS customers,
    SUM(exited)                                         AS churned,
    ROUND(100 * SUM(exited) / COUNT(*), 1)               AS churn_rate_pct
FROM tiered
GROUP BY value_tier
ORDER BY FIELD(value_tier, 'Platinum', 'Gold', 'Silver', 'Bronze');
