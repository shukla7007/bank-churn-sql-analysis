"""
Generate the project dataset for the Bank Customer Churn SQL analysis project.

Source: real Kaggle-style "Churn_Modelling.csv" (10,000 bank customers, columns:
CustomerId, Surname, CreditScore, Geography, Gender, Age, Tenure, Balance,
NumOfProducts, HasCrCard, IsActiveMember, EstimatedSalary, Exited).

That dataset has no transaction-level dates, which are needed for cohort
retention and first-vs-last-transaction self-join analysis. So this script
derives, per customer, from their real Tenure/Exited/IsActiveMember values:

  - signup_date   : when they opened their account (Tenure years before the
                     snapshot date, jittered within the year so cohorts spread
                     naturally across months instead of landing on one day).
  - churn_date     : for Exited customers, when they stopped transacting
                     (a random point in the back portion of their tenure).
  - transactions   : a monthly transaction log from signup_date to either
                     churn_date (if exited) or the snapshot date (if active),
                     with realistic gaps (not every customer transacts every
                     month) and amounts scaled off their real Balance/Salary.

Output: customers.csv, transactions.csv
"""
import pandas as pd
import numpy as np
from datetime import date, timedelta

RNG = np.random.default_rng(42)
SNAPSHOT_DATE = date(2026, 6, 30)  # the "as of" date for this dataset extract

src = pd.read_csv("Churn_Modelling.csv")
src = src.rename(columns={"CustomerId": "customer_id"})

customers = []
transactions = []
txn_id = 1

for row in src.itertuples(index=False):
    tenure_years = max(int(row.Tenure), 0)
    # jitter the signup day within the year so cohorts aren't all on Jan 1
    jitter_days = int(RNG.integers(0, 365))
    signup_date = SNAPSHOT_DATE - timedelta(days=tenure_years * 365 + jitter_days)
    # guard against signup landing after snapshot for Tenure=0 customers
    if signup_date >= SNAPSHOT_DATE:
        signup_date = SNAPSHOT_DATE - timedelta(days=30)

    tenure_months = max(1, (SNAPSHOT_DATE.year - signup_date.year) * 12 + (SNAPSHOT_DATE.month - signup_date.month))

    churn_date = None
    if row.Exited == 1:
        # churn happens sometime after at least 1 month of tenure, before snapshot
        min_month = 1
        max_month = max(min_month, tenure_months - 1)
        churn_month_offset = int(RNG.integers(min_month, max_month + 1))
        churn_date = signup_date + pd.DateOffset(months=churn_month_offset)
        churn_date = churn_date.date()
        active_until_month_offset = churn_month_offset
    else:
        active_until_month_offset = tenure_months

    customers.append({
        "customer_id": row.customer_id,
        "surname": row.Surname,
        "credit_score": row.CreditScore,
        "geography": row.Geography,
        "gender": row.Gender,
        "age": row.Age,
        "tenure_years": tenure_years,
        "balance": round(float(row.Balance), 2),
        "num_of_products": row.NumOfProducts,
        "has_cr_card": row.HasCrCard,
        "is_active_member": row.IsActiveMember,
        "estimated_salary": round(float(row.EstimatedSalary), 2),
        "exited": row.Exited,
        "signup_date": signup_date.isoformat(),
        "churn_date": churn_date.isoformat() if churn_date else None,
    })

    # base monthly transaction likelihood: active members transact more often
    base_prob = 0.85 if row.IsActiveMember == 1 else 0.55
    # scale a typical transaction amount off balance/salary so it's not pure noise
    amount_scale = max(row.Balance, row.EstimatedSalary / 12, 500)

    for m in range(active_until_month_offset):
        txn_month_date = signup_date + pd.DateOffset(months=m)
        if RNG.random() > base_prob:
            continue  # skipped month, mirrors real dormant-account behaviour
        n_txns = int(RNG.integers(1, 3))  # 1-2 transactions in an active month
        for _ in range(n_txns):
            day_offset = int(RNG.integers(0, 28))
            txn_date = (txn_month_date + pd.DateOffset(days=day_offset)).date()
            if txn_date >= SNAPSHOT_DATE:
                continue
            if churn_date and txn_date >= churn_date:
                continue
            txn_type = RNG.choice(
                ["deposit", "withdrawal", "transfer", "bill_payment"],
                p=[0.35, 0.30, 0.20, 0.15],
            )
            amount = round(float(RNG.lognormal(mean=np.log(max(amount_scale, 100)) - 3, sigma=0.9)), 2)
            amount = min(amount, amount_scale)  # keep amounts plausible
            transactions.append({
                "transaction_id": txn_id,
                "customer_id": row.customer_id,
                "transaction_date": txn_date.isoformat(),
                "transaction_type": txn_type,
                "amount": max(amount, 5.00),
            })
            txn_id += 1

customers_df = pd.DataFrame(customers)
transactions_df = pd.DataFrame(transactions)

customers_df.to_csv("customers.csv", index=False)
transactions_df.to_csv("transactions.csv", index=False)

print("customers:", customers_df.shape)
print("transactions:", transactions_df.shape)
print(customers_df.head(3).to_string())
print(transactions_df.head(5).to_string())
print("exited breakdown:\n", customers_df["exited"].value_counts())
print("customers with zero transactions:", (~customers_df.customer_id.isin(transactions_df.customer_id)).sum())
