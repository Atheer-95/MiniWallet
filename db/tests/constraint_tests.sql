-- Constraint tests for the MiniWallet schema.
-- Run as miniwallet in SQL Developer with F5 (Run Script).
-- Every change is rolled back at the end.

-- ============================================================
-- PART 1: valid data (every statement must succeed)
-- ============================================================

INSERT INTO customers (mobile_no, full_name, password_hash)
VALUES ('966500000001', 'Test One', 'hash1');

INSERT INTO customers (mobile_no, full_name, password_hash)
VALUES ('966500000002', 'Test Two', 'hash2');

INSERT INTO wallets (customer_id)
SELECT customer_id FROM customers WHERE mobile_no = '966500000001';

INSERT INTO wallets (customer_id)
SELECT customer_id FROM customers WHERE mobile_no = '966500000002';

INSERT INTO cards (customer_id, card_token, masked_pan, brand, expiry_month, expiry_year)
SELECT customer_id, 'tok_test_1', '411111******1111', 'VISA', 12, 2028
FROM customers WHERE mobile_no = '966500000001';

-- Successful top-up on wallet 1 with key-1
INSERT INTO transactions (wallet_id, txn_type, status, amount, card_id, idempotency_key, correlation_id)
SELECT w.wallet_id, 'TOPUP', 'SUCCESS', 150, c.card_id, 'key-1', 'c-test-1'
FROM customers cu
JOIN wallets w ON w.customer_id = cu.customer_id
JOIN cards   c ON c.customer_id = cu.customer_id
WHERE cu.mobile_no = '966500000001';

-- Same key-1 on a DIFFERENT wallet: allowed (the key is unique per wallet)
INSERT INTO transactions (wallet_id, txn_type, status, amount, counterparty_wallet_id, idempotency_key, correlation_id)
SELECT w2.wallet_id, 'TRANSFER_IN', 'SUCCESS', 50, w1.wallet_id, 'key-1', 'c-test-2'
FROM wallets w1, wallets w2, customers c1, customers c2
WHERE c1.mobile_no = '966500000001' AND w1.customer_id = c1.customer_id
  AND c2.mobile_no = '966500000002' AND w2.customer_id = c2.customer_id;

-- ============================================================
-- PART 2: invalid data (every statement must FAIL)
-- ============================================================

-- T01 EXPECT: ORA-00001 UQ_CUSTOMERS_MOBILE_NO
INSERT INTO customers (mobile_no, full_name, password_hash)
VALUES ('966500000001', 'Duplicate', 'hash');

-- T02 EXPECT: ORA-02290 CK_CUSTOMERS_STATUS
INSERT INTO customers (mobile_no, full_name, password_hash, status)
VALUES ('966500000003', 'Bad Status', 'hash', 'BLOCKED');

-- T03 EXPECT: ORA-32795 identity column
INSERT INTO customers (customer_id, mobile_no, full_name, password_hash)
VALUES (999, '966500000004', 'Manual ID', 'hash');

-- T04 EXPECT: ORA-00001 UQ_WALLETS_CUSTOMER_ID (second wallet)
INSERT INTO wallets (customer_id)
SELECT customer_id FROM customers WHERE mobile_no = '966500000001';

-- T05 EXPECT: ORA-02291 FK_WALLETS_CUSTOMERS
INSERT INTO wallets (customer_id) VALUES (999999);

-- T06 EXPECT: ORA-02290 CK_WALLETS_BALANCE
UPDATE wallets SET balance = -1
WHERE customer_id = (SELECT customer_id FROM customers WHERE mobile_no = '966500000001');

-- T07 EXPECT: ORA-02290 CK_CARDS_BRAND
INSERT INTO cards (customer_id, card_token, masked_pan, brand, expiry_month, expiry_year)
SELECT customer_id, 'tok_test_2', '371449*****8431', 'AMEX', 12, 2028
FROM customers WHERE mobile_no = '966500000001';

-- T08 EXPECT: ORA-02290 CK_CARDS_EXP_MONTH
INSERT INTO cards (customer_id, card_token, masked_pan, brand, expiry_month, expiry_year)
SELECT customer_id, 'tok_test_3', '411111******1111', 'VISA', 13, 2028
FROM customers WHERE mobile_no = '966500000001';

-- T09 EXPECT: ORA-02290 CK_TRANSACTIONS_AMOUNT
INSERT INTO transactions (wallet_id, txn_type, amount, card_id, idempotency_key, correlation_id)
SELECT w.wallet_id, 'TOPUP', 0, c.card_id, 'key-9', 'c-test-9'
FROM customers cu
JOIN wallets w ON w.customer_id = cu.customer_id
JOIN cards   c ON c.customer_id = cu.customer_id
WHERE cu.mobile_no = '966500000001';

-- T10 EXPECT: ORA-02290 CK_TRANSACTIONS_TOPUP_CARD (top-up without a card)
INSERT INTO transactions (wallet_id, txn_type, amount, idempotency_key, correlation_id)
SELECT w.wallet_id, 'TOPUP', 100, 'key-10', 'c-test-10'
FROM customers cu JOIN wallets w ON w.customer_id = cu.customer_id
WHERE cu.mobile_no = '966500000001';

-- T11 EXPECT: ORA-02291 FK_TRANSACTIONS_TYPES (unknown type)
INSERT INTO transactions (wallet_id, txn_type, amount, idempotency_key, correlation_id)
SELECT w.wallet_id, 'REFUND', 100, 'key-11', 'c-test-11'
FROM customers cu JOIN wallets w ON w.customer_id = cu.customer_id
WHERE cu.mobile_no = '966500000001';

-- T12 EXPECT: ORA-00001 UQ_TRANSACTIONS_WALLET_IDEM (key-1 again on wallet 1)
INSERT INTO transactions (wallet_id, txn_type, status, amount, card_id, idempotency_key, correlation_id)
SELECT w.wallet_id, 'TOPUP', 'SUCCESS', 150, c.card_id, 'key-1', 'c-test-12'
FROM customers cu
JOIN wallets w ON w.customer_id = cu.customer_id
JOIN cards   c ON c.customer_id = cu.customer_id
WHERE cu.mobile_no = '966500000001';

-- T13 EXPECT: ORA-02290 CK_TRANSACTIONS_TRANSFER_CP (transfer without counterparty)
INSERT INTO transactions (wallet_id, txn_type, amount, idempotency_key, correlation_id)
SELECT w.wallet_id, 'TRANSFER_OUT', 20, 'key-13', 'c-test-13'
FROM customers cu JOIN wallets w ON w.customer_id = cu.customer_id
WHERE cu.mobile_no = '966500000001';

-- T14 EXPECT: ORA-02290 CK_TRANSACTIONS_NOT_SELF (transfer to own wallet)
INSERT INTO transactions (wallet_id, txn_type, amount, counterparty_wallet_id, idempotency_key, correlation_id)
SELECT w.wallet_id, 'TRANSFER_OUT', 20, w.wallet_id, 'key-14', 'c-test-14'
FROM customers cu JOIN wallets w ON w.customer_id = cu.customer_id
WHERE cu.mobile_no = '966500000001';

-- T15 EXPECT: ORA-00001 UQ_WALLET_LIMITS_TYPE_PERIOD (second DAILY limit for TOPUP)
INSERT INTO wallet_limits (txn_type, period_type, max_amount)
VALUES ('TOPUP', 'DAILY', 999);

-- T16 EXPECT: ORA-02292 child record found (customer has a wallet)
DELETE FROM customers WHERE mobile_no = '966500000001';

-- ============================================================
-- PART 3: check what was kept, then undo everything
-- ============================================================

SELECT cu.mobile_no, w.wallet_id, w.balance, t.txn_type, t.amount, t.idempotency_key
FROM customers cu
JOIN wallets w           ON w.customer_id = cu.customer_id
LEFT JOIN transactions t ON t.wallet_id   = w.wallet_id
WHERE cu.mobile_no LIKE '96650000000%'
ORDER BY cu.mobile_no;

ROLLBACK;
