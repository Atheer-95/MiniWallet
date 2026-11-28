-- ============================================================
-- MiniWallet investigation queries
-- For support cases. Bind variables are asked for when run.
-- ============================================================

-- I1. Customer overview by mobile number
SELECT c.customer_id, c.full_name, c.status AS customer_status,
       c.failed_login_count, c.last_login_at,
       w.wallet_id, w.balance, w.status AS wallet_status,
       (SELECT COUNT(*) FROM cards cd
        WHERE cd.customer_id = c.customer_id AND cd.status = 'ACTIVE') AS active_cards
FROM   customers c
JOIN   wallets w ON w.customer_id = c.customer_id
WHERE  c.mobile_no = :mobile_no;

-- I2. Last 20 transactions of a customer
SELECT t.txn_id, t.created_at, t.txn_type, t.status, t.amount,
       t.balance_after, t.response_code, t.rrn, t.description
FROM   customers c
JOIN   wallets w      ON w.customer_id = c.customer_id
JOIN   transactions t ON t.wallet_id   = w.wallet_id
WHERE  c.mobile_no = :mobile_no
ORDER  BY t.txn_id DESC
FETCH  FIRST 20 ROWS ONLY;

-- I3. Find a transaction by RRN
SELECT t.*, r.description AS response_text
FROM   transactions t
LEFT   JOIN response_codes r ON r.response_code = t.response_code
WHERE  t.rrn = :rrn;

-- I4. Both legs of a transfer, from either transaction ID
SELECT o.txn_id    AS out_txn_id, o.wallet_id AS sender_wallet,
       i.txn_id    AS in_txn_id,  i.wallet_id AS receiver_wallet,
       o.amount, o.created_at
FROM   transactions o
JOIN   transactions i ON i.txn_id = o.related_txn_id
WHERE  o.txn_type = 'TRANSFER_OUT'
AND    (o.txn_id = :txn_id OR i.txn_id = :txn_id);

-- I5. Full trace of one request by correlation ID
SELECT 'TXN' AS source, TO_CHAR(txn_id) AS ref, status AS info, created_at
FROM   transactions WHERE correlation_id = :correlation_id
UNION ALL
SELECT 'GATEWAY', endpoint || ' ' || direction, TO_CHAR(http_status), created_at
FROM   gateway_log  WHERE correlation_id = :correlation_id
UNION ALL
SELECT 'AUDIT', action, details, created_at
FROM   audit_log    WHERE correlation_id = :correlation_id
ORDER  BY created_at;

-- I6. Balance reconciliation: wallets whose balance does not match their transactions
-- Must return no rows; any row is an incident
SELECT w.wallet_id, w.balance,
       NVL(SUM(CASE WHEN tt.direction = 'C' THEN t.amount ELSE -t.amount END), 0) AS ledger_balance
FROM   wallets w
LEFT   JOIN transactions t  ON t.wallet_id  = w.wallet_id AND t.status = 'SUCCESS'
LEFT   JOIN txn_types    tt ON tt.type_code = t.txn_type
GROUP  BY w.wallet_id, w.balance
HAVING w.balance <> NVL(SUM(CASE WHEN tt.direction = 'C' THEN t.amount ELSE -t.amount END), 0);
