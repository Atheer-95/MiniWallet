-- ============================================================
-- MiniWallet monitoring queries
-- Real-time health checks. All timestamps are stored in UTC.
-- ============================================================

-- M1. Top-up success rate, last 60 minutes
-- Alert when below 90% with at least 10 attempts
SELECT COUNT(*)                                                   AS attempts,
       SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END)        AS success,
       ROUND(100 * SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0), 2)                            AS success_pct
FROM   transactions
WHERE  txn_type   = 'TOPUP'
AND    created_at >= SYSTIMESTAMP - INTERVAL '60' MINUTE;

-- M2. Top-up success rate per hour, last 24 hours
-- Shows when a drop started
SELECT TRUNC(created_at, 'HH24')                                     AS hour_utc,
       COUNT(*)                                                      AS attempts,
       ROUND(100 * AVG(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END), 1) AS success_pct
FROM   transactions
WHERE  txn_type   = 'TOPUP'
AND    created_at >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP  BY TRUNC(created_at, 'HH24')
ORDER  BY hour_utc;

-- M3. Declines by response code, today
SELECT t.response_code, r.description, COUNT(*) AS declines
FROM   transactions t
JOIN   response_codes r ON r.response_code = t.response_code
WHERE  t.status     = 'FAILED'
AND    t.created_at >= TRUNC(SYSDATE)
GROUP  BY t.response_code, r.description
ORDER  BY declines DESC;

-- M4. Gateway timeouts, last 60 minutes
SELECT COUNT(*) AS timeouts
FROM   transactions
WHERE  txn_type      = 'TOPUP'
AND    status        = 'FAILED'
AND    response_code IS NULL
AND    created_at    >= SYSTIMESTAMP - INTERVAL '60' MINUTE;

-- M5. Stuck PENDING transactions (older than 2 minutes)
-- Must normally return no rows
SELECT txn_id, wallet_id, txn_type, amount, correlation_id, created_at,
       ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(created_at AS DATE)) * 1440, 1) AS age_minutes
FROM   transactions
WHERE  status     = 'PENDING'
AND    created_at < SYSTIMESTAMP - INTERVAL '2' MINUTE
ORDER  BY created_at;

-- M6. Top-up volume today so far vs the same time last week
SELECT 'Today'               AS period, COUNT(*) AS topups, NVL(SUM(amount), 0) AS total_sar
FROM   transactions
WHERE  txn_type = 'TOPUP' AND status = 'SUCCESS'
AND    created_at >= TRUNC(SYSDATE)
UNION ALL
SELECT 'Same time last week', COUNT(*), NVL(SUM(amount), 0)
FROM   transactions
WHERE  txn_type = 'TOPUP' AND status = 'SUCCESS'
AND    created_at >= TRUNC(SYSDATE) - 7
AND    created_at <  SYSTIMESTAMP - INTERVAL '7' DAY;
