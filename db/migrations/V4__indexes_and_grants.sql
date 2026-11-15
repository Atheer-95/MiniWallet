-- V4: indexes for frequent queries and grants for the application user

CREATE INDEX ix_cards_customer          ON cards (customer_id, status);
CREATE INDEX ix_txn_wallet_created      ON transactions (wallet_id, created_at DESC);
CREATE INDEX ix_txn_status_created      ON transactions (status, created_at);
CREATE INDEX ix_txn_type_created        ON transactions (txn_type, created_at);
CREATE INDEX ix_txn_counterparty        ON transactions (counterparty_wallet_id);
CREATE INDEX ix_txn_card                ON transactions (card_id);
CREATE INDEX ix_txn_related             ON transactions (related_txn_id);
CREATE INDEX ix_txn_rrn                 ON transactions (rrn);
CREATE INDEX ix_txn_correlation         ON transactions (correlation_id);
CREATE INDEX ix_gwlog_txn               ON gateway_log (txn_id);
CREATE INDEX ix_gwlog_created           ON gateway_log (created_at);
CREATE INDEX ix_audit_customer_created  ON audit_log (customer_id, created_at);
CREATE INDEX ix_rtokens_customer        ON refresh_tokens (customer_id);

-- Application user: read and write, no deletes on money or history tables
GRANT SELECT, INSERT, UPDATE ON customers      TO miniwallet_app;
GRANT SELECT, INSERT, UPDATE ON wallets        TO miniwallet_app;
GRANT SELECT, INSERT, UPDATE ON cards          TO miniwallet_app;
GRANT SELECT, INSERT, UPDATE ON transactions   TO miniwallet_app;
GRANT SELECT, INSERT         ON gateway_log    TO miniwallet_app;
GRANT SELECT, INSERT         ON audit_log      TO miniwallet_app;
GRANT SELECT, INSERT, UPDATE ON refresh_tokens TO miniwallet_app;
GRANT SELECT                 ON wallet_limits  TO miniwallet_app;
GRANT SELECT                 ON txn_types      TO miniwallet_app;
GRANT SELECT                 ON txn_statuses   TO miniwallet_app;
GRANT SELECT                 ON response_codes TO miniwallet_app;
