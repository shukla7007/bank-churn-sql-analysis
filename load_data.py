"""
Fallback loader in case LOAD DATA LOCAL INFILE is locked down on your MySQL
instance (common on managed MySQL / some local installs). Loads customers.csv
and transactions.csv with batched executemany() instead.

Usage:
    pip install mysql-connector-python
    python load_data.py --host 127.0.0.1 --user root --password yourpw
"""
import argparse
import csv
import sys

import mysql.connector

parser = argparse.ArgumentParser()
parser.add_argument("--host", default="127.0.0.1")
parser.add_argument("--port", type=int, default=3306)
parser.add_argument("--user", default="root")
parser.add_argument("--password", default="")
parser.add_argument("--database", default="bank_churn_analysis")
parser.add_argument("--batch-size", type=int, default=5000)
args = parser.parse_args()

conn = mysql.connector.connect(
    host=args.host, port=args.port, user=args.user,
    password=args.password, database=args.database,
)
cur = conn.cursor()


def load_csv(path, insert_sql, row_fn, label):
    batch = []
    n = 0
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            batch.append(row_fn(row))
            if len(batch) >= args.batch_size:
                cur.executemany(insert_sql, batch)
                conn.commit()
                n += len(batch)
                print(f"  {label}: {n} rows loaded", end="\r")
                batch = []
        if batch:
            cur.executemany(insert_sql, batch)
            conn.commit()
            n += len(batch)
    print(f"  {label}: {n} rows loaded — done")


print("Loading customers...")
load_csv(
    "data/customers.csv",
    """INSERT INTO customers
       (customer_id, surname, credit_score, geography, gender, age, tenure_years,
        balance, num_of_products, has_cr_card, is_active_member, estimated_salary,
        exited, signup_date, churn_date)
       VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
    lambda r: (
        r["customer_id"], r["surname"], r["credit_score"], r["geography"], r["gender"],
        r["age"], r["tenure_years"], r["balance"], r["num_of_products"], r["has_cr_card"],
        r["is_active_member"], r["estimated_salary"], r["exited"], r["signup_date"],
        r["churn_date"] or None,
    ),
    "customers",
)

print("Loading transactions (this is the big one, ~626k rows)...")
load_csv(
    "data/transactions.csv",
    """INSERT INTO transactions
       (transaction_id, customer_id, transaction_date, transaction_type, amount)
       VALUES (%s,%s,%s,%s,%s)""",
    lambda r: (
        r["transaction_id"], r["customer_id"], r["transaction_date"],
        r["transaction_type"], r["amount"],
    ),
    "transactions",
)

cur.close()
conn.close()
print("Done.")
