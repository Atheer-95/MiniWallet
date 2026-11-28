"""
Seed MiniWallet with 90 days of transactions.

- Top-ups: about 90% approved, 7% declined, 3% timed out
- Transfers: wallet to wallet, only when the sender has enough balance
- Wallet balances are recalculated from the successful transactions

Run after seed_customers.py, from db/seed with the virtual environment active:
    python seed_transactions.py
"""

import itertools
import random
import string
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

import oracledb
from dotenv import dotenv_values

DAYS = 90
TOPUPS_PER_DAY = 400
TRANSFERS_PER_DAY = 100
BATCH_SIZE = 5000

TOPUP_AMOUNTS = [Decimal(a) for a in (50, 100, 100, 150, 200, 200, 250, 300, 500, 500, 1000)]
DECLINE_CODES = ["51"] * 4 + ["05"] * 3 + ["61", "62", "54"]
TRANSFER_NOTES = [None, None, None, "Lunch", "Rent share", "Gift", "Thanks", "Coffee", "Groceries"]

# One weight per hour (UTC), busier in the afternoon and evening
HOUR_WEIGHTS = [2, 2, 1, 1, 1, 1, 2, 3, 4, 5, 6, 6, 6, 7, 8, 9, 10, 9, 8, 6, 4, 3, 2, 2]

random.seed(43)
NOW = datetime.now(timezone.utc).replace(tzinfo=None)

rrn_counter = itertools.count(1)
event_counter = itertools.count(1)

INSERT_SQL = """
INSERT INTO transactions (wallet_id, txn_type, status, amount, balance_after, card_id,
                          counterparty_wallet_id, idempotency_key, rrn, auth_code,
                          response_code, description, correlation_id, created_at, updated_at)
VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14, :15)
"""

# Link the two legs of every transfer through related_txn_id
LINK_OUT_SQL = """
UPDATE transactions o
SET related_txn_id = (SELECT i.txn_id FROM transactions i
                      WHERE i.correlation_id = o.correlation_id
                        AND i.txn_type = 'TRANSFER_IN')
WHERE o.txn_type = 'TRANSFER_OUT'
  AND o.correlation_id LIKE 'seed-%'
"""

LINK_IN_SQL = """
UPDATE transactions i
SET related_txn_id = (SELECT o.txn_id FROM transactions o
                      WHERE o.correlation_id = i.correlation_id
                        AND o.txn_type = 'TRANSFER_OUT')
WHERE i.txn_type = 'TRANSFER_IN'
  AND i.correlation_id LIKE 'seed-%'
"""

# Every balance is the sum of its successful transactions
BALANCE_SQL = """
UPDATE wallets w
SET balance = (SELECT NVL(SUM(CASE WHEN tt.direction = 'C' THEN t.amount ELSE -t.amount END), 0)
               FROM transactions t
               JOIN txn_types tt ON tt.type_code = t.txn_type
               WHERE t.wallet_id = w.wallet_id
                 AND t.status = 'SUCCESS'),
    version = version + 1,
    updated_at = SYSTIMESTAMP
WHERE EXISTS (SELECT 1 FROM transactions t WHERE t.wallet_id = w.wallet_id)
"""


def connect():
    env = dotenv_values(Path(__file__).resolve().parents[2] / ".env")
    return oracledb.connect(
        user="miniwallet",
        password=env["DB_OWNER_PASSWORD"],
        dsn="localhost:1521/XEPDB1",
    )


def random_time(day_start):
    hour = random.choices(range(24), weights=HOUR_WEIGHTS)[0]
    return day_start + timedelta(hours=hour, minutes=random.randint(0, 59),
                                 seconds=random.randint(0, 59))


def new_key():
    h = f"{random.getrandbits(128):032x}"
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"


def new_rrn(t):
    """12 digits: last digit of the year + day of the year + sequence."""
    return f"{t.year % 10}{t.timetuple().tm_yday:03d}{next(rrn_counter):08d}"


def new_auth_code():
    return "".join(random.choices(string.ascii_uppercase + string.digits, k=6))


def usable_card(cards, t):
    """A card that was linked and not removed at time t."""
    usable = [card_id for card_id, created, removed in cards
              if created <= t and (removed is None or removed > t)]
    return random.choice(usable) if usable else None


def txn(wallet, txn_type, status, amount, created, updated, corr, key,
        balance_after=None, card=None, counterparty=None,
        rrn=None, auth_code=None, response_code=None, description=None):
    """One row in the column order of INSERT_SQL."""
    return (wallet, txn_type, status, amount, balance_after, card, counterparty,
            key, rrn, auth_code, response_code, description, corr, created, updated)


def build_events(wallet_ids):
    start = (NOW - timedelta(days=DAYS)).replace(hour=0, minute=0, second=0, microsecond=0)
    events = []

    for d in range(DAYS):
        day = start + timedelta(days=d)
        for _ in range(TOPUPS_PER_DAY):
            events.append((random_time(day), "TOPUP", random.choice(wallet_ids), None))
        for _ in range(TRANSFERS_PER_DAY):
            sender, receiver = random.sample(wallet_ids, 2)
            events.append((random_time(day), "TRANSFER", sender, receiver))

    events = [e for e in events if e[0] < NOW]
    events.sort(key=lambda e: e[0])
    return events


def simulate(events, wallet_customer, customer_cards):
    balances = {w: Decimal("0") for w in wallet_customer}
    rows = []

    for t, kind, wallet, receiver in events:
        corr = f"seed-{next(event_counter):06d}"
        done = t + timedelta(milliseconds=random.randint(200, 3000))

        if kind == "TOPUP":
            card = usable_card(customer_cards.get(wallet_customer[wallet], []), t)
            if card is None:
                continue
            amount = random.choice(TOPUP_AMOUNTS)
            r = random.random()

            if r < 0.90:
                balances[wallet] += amount
                rows.append(txn(wallet, "TOPUP", "SUCCESS", amount, t, done, corr, new_key(),
                                balance_after=balances[wallet], card=card, rrn=new_rrn(t),
                                auth_code=new_auth_code(), response_code="00"))
            elif r < 0.97:
                rows.append(txn(wallet, "TOPUP", "FAILED", amount, t, done, corr, new_key(),
                                card=card, rrn=new_rrn(t),
                                response_code=random.choice(DECLINE_CODES)))
            else:
                rows.append(txn(wallet, "TOPUP", "FAILED", amount, t,
                                t + timedelta(minutes=random.randint(2, 5)), corr, new_key(),
                                card=card, description="Timed out, not charged"))

        else:
            amount = Decimal(random.randint(1000, 30000)) / 100   # 10.00 to 300.00
            if balances[wallet] < amount:
                continue   # the API would reject it with no rows written
            balances[wallet] -= amount
            balances[receiver] += amount
            key = new_key()
            note = random.choice(TRANSFER_NOTES)
            rows.append(txn(wallet, "TRANSFER_OUT", "SUCCESS", amount, t, done, corr, key,
                            balance_after=balances[wallet], counterparty=receiver,
                            description=note))
            rows.append(txn(receiver, "TRANSFER_IN", "SUCCESS", amount, t, done, corr, key + "-in",
                            balance_after=balances[receiver], counterparty=wallet,
                            description=note))

    return rows


def main():
    with connect() as conn:
        cur = conn.cursor()

        cur.execute("SELECT COUNT(*) FROM transactions")
        if cur.fetchone()[0] > 0:
            print("Transactions already exist. Seed data is loaded once.")
            return

        # Only active customers with active wallets make transactions
        cur.execute("""SELECT w.wallet_id, w.customer_id
                       FROM wallets w JOIN customers c ON c.customer_id = w.customer_id
                       WHERE w.status = 'ACTIVE' AND c.status = 'ACTIVE'""")
        wallet_customer = dict(cur.fetchall())

        cur.execute("SELECT customer_id, card_id, created_at, removed_at FROM cards")
        customer_cards = {}
        for customer_id, card_id, created, removed in cur.fetchall():
            customer_cards.setdefault(customer_id, []).append((card_id, created, removed))

        rows = simulate(build_events(list(wallet_customer)), wallet_customer, customer_cards)

        for i in range(0, len(rows), BATCH_SIZE):
            cur.executemany(INSERT_SQL, rows[i:i + BATCH_SIZE])
            print(f"inserted {min(i + BATCH_SIZE, len(rows)):>6} / {len(rows)}")

        cur.execute(LINK_OUT_SQL)
        cur.execute(LINK_IN_SQL)
        cur.execute(BALANCE_SQL)
        conn.commit()

        cur.execute("""SELECT txn_type, status, COUNT(*) FROM transactions
                       GROUP BY txn_type, status ORDER BY txn_type, status""")
        for txn_type, status, count in cur.fetchall():
            print(f"{txn_type:13} {status:8} {count:>6}")


if __name__ == "__main__":
    main()
