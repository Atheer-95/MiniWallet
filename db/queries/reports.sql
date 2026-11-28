-- ============================================================
-- MiniWallet business reports
-- ============================================================

-- R1. Daily top-up totals, last 30 days, with day-over-day change
SELECT txn_day, topups, total_sar,
       total_sar - LAG(total_sar) OVER (ORDER BY txn_day) AS change_sar
FROM  (SELECT TRUNC(created_at) AS txn_day,
              COUNT(*)          AS topups,
              SUM(amount)       AS total_sar
       FROM   transactions
       WHERE  txn_type = 'TOPUP' AND status = 'SUCCESS'
       AND    created_at >= TRUNC(SYSDATE) - 30
       GROUP  BY TRUNC(created_at))
ORDER BY txn_day;

-- R2. Daily transfers, last 30 days
SELECT TRUNC(created_at)     AS txn_day,
       COUNT(*)              AS transfers,
       SUM(amount)           AS total_sar,
       ROUND(AVG(amount), 2) AS avg_sar
FROM   transactions
WHERE  txn_type = 'TRANSFER_OUT' AND status = 'SUCCESS'
AND    created_at >= TRUNC(SYSDATE) - 30
GROUP  BY TRUNC(created_at)
ORDER  BY txn_day;

-- R3. Top 10 wallets by balance (mobile masked)
SELECT SUBSTR(c.mobile_no, 1, 4) || '****' || SUBSTR(c.mobile_no, -4) AS mobile,
       c.full_name, w.balance
FROM   wallets w
JOIN   customers c ON c.customer_id = w.customer_id
ORDER  BY w.balance DESC
FETCH  FIRST 10 ROWS ONLY;

-- R4. Active customers with no transaction in the last 30 days
SELECT c.customer_id, c.full_name, MAX(t.created_at) AS last_activity
FROM   customers c
JOIN   wallets w           ON w.customer_id = c.customer_id
LEFT   JOIN transactions t ON t.wallet_id   = w.wallet_id
WHERE  c.status = 'ACTIVE'
GROUP  BY c.customer_id, c.full_name
HAVING MAX(t.created_at) < SYSDATE - 30
    OR MAX(t.created_at) IS NULL
ORDER  BY last_activity NULLS FIRST;

-- R5. Top-up success rate by card brand
SELECT cd.brand,
       COUNT(*) AS attempts,
       ROUND(100 * AVG(CASE WHEN t.status = 'SUCCESS' THEN 1 ELSE 0 END), 1) AS success_pct
FROM   transactions t
JOIN   cards cd ON cd.card_id = t.card_id
WHERE  t.txn_type = 'TOPUP'
GROUP  BY cd.brand
ORDER  BY success_pct;

-- R6. Busiest hours of the day (Riyadh time)
SELECT EXTRACT(HOUR FROM (FROM_TZ(created_at, 'UTC') AT TIME ZONE 'Asia/Riyadh')) AS hour_riyadh,
       COUNT(*) AS transactions
FROM   transactions
GROUP  BY EXTRACT(HOUR FROM (FROM_TZ(created_at, 'UTC') AT TIME ZONE 'Asia/Riyadh'))
ORDER  BY hour_riyadh;

-- R7. Today's transfer usage against the daily limit, for one wallet
SELECT NVL(SUM(t.amount), 0) AS used_today, l.max_amount,
       COUNT(t.txn_id)       AS count_today, l.max_count
FROM   wallet_limits l
LEFT   JOIN transactions t
       ON  t.txn_type   = l.txn_type
       AND t.wallet_id  = :wallet_id
       AND t.status     IN ('SUCCESS', 'PENDING')
       AND t.created_at >= TRUNC(SYSDATE)
WHERE  l.txn_type    = 'TRANSFER_OUT'
AND    l.period_type = 'DAILY'
AND    l.is_active   = 'Y'
GROUP  BY l.max_amount, l.max_count;
