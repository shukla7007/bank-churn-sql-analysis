-- ============================================================
-- Cohort Retention Analysis
-- Technique: CTEs + conditional aggregation (CASE WHEN)
--
-- Business question: "Of customers who signed up in a given month, what
-- share are still transacting 1, 3, 6, 12 months later?" This is the
-- standard cohort-retention view product/growth teams use to judge whether
-- onboarding or product changes are improving stickiness over time.
-- ============================================================
USE bank_churn_analysis;

-- ---------------------------------------------------------------
-- 1a. Long-format retention table (one row per cohort x month)
--     — easiest shape to hand to a BI tool / chart as a line-per-cohort
-- ---------------------------------------------------------------
WITH cohort AS (
    -- each customer's signup month = their cohort
    SELECT customer_id, DATE_FORMAT(signup_date, '%Y-%m-01') AS cohort_month
    FROM customers
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_customers
    FROM cohort
    GROUP BY cohort_month
),
activity AS (
    -- how many months after signup did each transaction happen
    SELECT
        t.customer_id,
        c.cohort_month,
        TIMESTAMPDIFF(
            MONTH, c.cohort_month, DATE_FORMAT(t.transaction_date, '%Y-%m-01')
        ) AS month_number
    FROM transactions t
    JOIN cohort c ON c.customer_id = t.customer_id
)
SELECT
    a.cohort_month,
    cs.cohort_customers,
    a.month_number,
    COUNT(DISTINCT a.customer_id)                                        AS active_customers,
    ROUND(100 * COUNT(DISTINCT a.customer_id) / cs.cohort_customers, 1)  AS retention_pct
FROM activity a
JOIN cohort_size cs ON cs.cohort_month = a.cohort_month
WHERE a.month_number BETWEEN 0 AND 12
GROUP BY a.cohort_month, cs.cohort_customers, a.month_number
ORDER BY a.cohort_month, a.month_number;


-- ---------------------------------------------------------------
-- 1b. Classic pivoted retention MATRIX (cohort rows x month-0..month-6
--     columns), built with conditional aggregation — the format most
--     recruiters mean by "cohort retention table"
-- ---------------------------------------------------------------
WITH cohort AS (
    SELECT customer_id, DATE_FORMAT(signup_date, '%Y-%m-01') AS cohort_month
    FROM customers
),
activity AS (
    SELECT
        t.customer_id,
        c.cohort_month,
        TIMESTAMPDIFF(
            MONTH, c.cohort_month, DATE_FORMAT(t.transaction_date, '%Y-%m-01')
        ) AS month_number
    FROM transactions t
    JOIN cohort c ON c.customer_id = t.customer_id
)
SELECT
    c.cohort_month,
    COUNT(DISTINCT c.customer_id)                                                             AS cohort_customers,
    COUNT(DISTINCT CASE WHEN a.month_number = 0 THEN a.customer_id END)                        AS m0,
    COUNT(DISTINCT CASE WHEN a.month_number = 1 THEN a.customer_id END)                        AS m1,
    COUNT(DISTINCT CASE WHEN a.month_number = 3 THEN a.customer_id END)                        AS m3,
    COUNT(DISTINCT CASE WHEN a.month_number = 6 THEN a.customer_id END)                        AS m6,
    COUNT(DISTINCT CASE WHEN a.month_number = 12 THEN a.customer_id END)                       AS m12,
    ROUND(100 * COUNT(DISTINCT CASE WHEN a.month_number = 1  THEN a.customer_id END)
                / COUNT(DISTINCT c.customer_id), 1)                                            AS retention_m1_pct,
    ROUND(100 * COUNT(DISTINCT CASE WHEN a.month_number = 6  THEN a.customer_id END)
                / COUNT(DISTINCT c.customer_id), 1)                                            AS retention_m6_pct,
    ROUND(100 * COUNT(DISTINCT CASE WHEN a.month_number = 12 THEN a.customer_id END)
                / COUNT(DISTINCT c.customer_id), 1)                                            AS retention_m12_pct
FROM cohort c
LEFT JOIN activity a ON a.customer_id = c.customer_id AND a.cohort_month = c.cohort_month
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
