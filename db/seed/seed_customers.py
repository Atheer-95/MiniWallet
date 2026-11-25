"""
Seed MiniWallet with test customers, wallets and cards.

- 20 manual test users: 966500000001 to 966500000020, password Test@1234
- 1,000 generated customers with Saudi-style names and mobile numbers

All data is fictional. Run from db/seed with the virtual environment active:
    python seed_customers.py
"""

import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

import bcrypt
import oracledb
from dotenv import dotenv_values
from faker import Faker

GENERATED_CUSTOMERS = 1000
MANUAL_USERS = 20
TEST_PASSWORD = "Test@1234"

# Test card ranges: (brand, first 6 digits, last 4 digits)
TEST_CARDS = [
    ("VISA", "411111", "1111"),
    ("VISA", "424242", "4242"),
    ("MASTERCARD", "555555", "4444"),
    ("MASTERCARD", "510510", "5100"),
]

NICKNAMES = [None, None, "Salary card", "Personal", "Travel card"]

# Fixed seeds: the same data is generated every time
random.seed(42)
Faker.seed(42)
fake_ar = Faker("ar_SA")   # names
fake_en = Faker("en_US")   # emails

# Database timestamps are stored in UTC without a time zone
NOW = datetime.now(timezone.utc).replace(tzinfo=None)


def connect():
    env = dotenv_values(Path(__file__).resolve().parents[2] / ".env")
    return oracledb.connect(
        user="miniwallet",
        password=env["DB_OWNER_PASSWORD"],
        dsn="localhost:1521/XEPDB1",
    )


def random_mobile(used):
    """A unique 9665XXXXXXXX number outside the manual test range."""
    while True:
        mobile = "9665" + "".join(random.choices("0123456789", k=8))
        if mobile not in used and not mobile.startswith("96650000"):
            used.add(mobile)
            return mobile


def build_customers(password_hash):
    rows = []

    for n in range(1, MANUAL_USERS + 1):
        rows.append((
            f"9665000000{n:02d}",
            f"test{n:02d}@miniwallet.test",
            f"Test User {n:02d}",
            password_hash,
            "ACTIVE",
            NOW - timedelta(days=120),
        ))

    used = set()
    for _ in range(GENERATED_CUSTOMERS):
        rows.append((
            random_mobile(used),
            fake_en.unique.email(),
            fake_ar.name(),
            password_hash,
            "LOCKED" if random.random() < 0.02 else "ACTIVE",
            NOW - timedelta(days=random.randint(91, 180), minutes=random.randint(0, 1439)),
        ))

    return rows


def build_cards(customers):
    """customers: list of (customer_id, mobile_no, created_at)."""
    rows = []

    for customer_id, mobile, created_at in customers:
        if mobile.startswith("96650000"):
            # Manual user: one known card
            rows.append((
                customer_id, f"tok_manual_{mobile[-2:]}", "411111******1111", "VISA",
                12, 2029, "Test card", "ACTIVE", created_at, None,
            ))
            continue

        for _ in range(1 if random.random() < 0.7 else 2):
            brand, first6, last4 = random.choice(TEST_CARDS)
            card_created = created_at + timedelta(days=random.randint(0, 5))
            removed = random.random() < 0.05
            rows.append((
                customer_id,
                f"tok_{random.getrandbits(64):016x}",
                f"{first6}******{last4}",
                brand,
                random.randint(1, 12),
                random.randint(2027, 2030),
                random.choice(NICKNAMES),
                "REMOVED" if removed else "ACTIVE",
                card_created,
                card_created + timedelta(days=random.randint(10, 60)) if removed else None,
            ))

    return rows


def main():
    # Hash once: every test user shares the same password
    password_hash = bcrypt.hashpw(TEST_PASSWORD.encode(), bcrypt.gensalt(rounds=12)).decode()

    with connect() as conn:
        cur = conn.cursor()

        cur.execute("SELECT COUNT(*) FROM customers")
        if cur.fetchone()[0] > 0:
            print("Customers already exist. Seed data is loaded once on an empty schema.")
            return

        # 1. Customers
        cur.executemany(
            """INSERT INTO customers (mobile_no, email, full_name, password_hash, status, created_at)
               VALUES (:1, :2, :3, :4, :5, :6)""",
            build_customers(password_hash),
        )

        # 2. One wallet per customer, in a single SQL statement
        cur.execute(
            """INSERT INTO wallets (customer_id, status, created_at)
               SELECT customer_id,
                      CASE WHEN MOD(customer_id, 100) = 0
                            AND mobile_no NOT LIKE '96650000%'
                           THEN 'FROZEN' ELSE 'ACTIVE' END,
                      created_at
               FROM customers"""
        )

        # 3. Cards, using the IDs Oracle just generated
        cur.execute("SELECT customer_id, mobile_no, created_at FROM customers ORDER BY customer_id")
        cur.executemany(
            """INSERT INTO cards (customer_id, card_token, masked_pan, brand, expiry_month,
                                  expiry_year, nickname, status, created_at, removed_at)
               VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10)""",
            build_cards(cur.fetchall()),
        )

        conn.commit()

        for table in ("customers", "wallets", "cards"):
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            print(f"{table:10} {cur.fetchone()[0]:>6}")


if __name__ == "__main__":
    main()
