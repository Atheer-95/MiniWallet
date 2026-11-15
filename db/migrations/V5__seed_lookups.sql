-- V5: reference data for lookup tables and default limits

INSERT INTO txn_types VALUES ('TOPUP',        'Top-up from a linked card',             'C');
INSERT INTO txn_types VALUES ('TRANSFER_OUT', 'Transfer sent to another wallet',       'D');
INSERT INTO txn_types VALUES ('TRANSFER_IN',  'Transfer received from another wallet', 'C');
INSERT INTO txn_types VALUES ('REVERSAL',     'Reversal of a previous transaction',    'D');

INSERT INTO txn_statuses VALUES ('PENDING',  'Sent for processing, result not known', 'N');
INSERT INTO txn_statuses VALUES ('SUCCESS',  'Completed and balance updated',         'Y');
INSERT INTO txn_statuses VALUES ('FAILED',   'Declined or error, balance unchanged',  'Y');
INSERT INTO txn_statuses VALUES ('REVERSED', 'Completed then reversed',               'Y');

INSERT INTO response_codes VALUES ('00', 'Approved',                     'Y', NULL);
INSERT INTO response_codes VALUES ('05', 'Do not honour',                'N', 'CARD_DECLINED');
INSERT INTO response_codes VALUES ('14', 'Invalid card number',          'N', 'CARD_DECLINED');
INSERT INTO response_codes VALUES ('51', 'Insufficient funds',           'N', 'CARD_DECLINED');
INSERT INTO response_codes VALUES ('54', 'Expired card',                 'N', 'CARD_EXPIRED');
INSERT INTO response_codes VALUES ('61', 'Exceeds withdrawal limit',     'N', 'CARD_DECLINED');
INSERT INTO response_codes VALUES ('62', 'Restricted card',              'N', 'CARD_DECLINED');
INSERT INTO response_codes VALUES ('91', 'Issuer or switch unavailable', 'N', 'GATEWAY_ERROR');
INSERT INTO response_codes VALUES ('96', 'System malfunction',           'N', 'GATEWAY_ERROR');

INSERT INTO wallet_limits (txn_type, period_type, max_amount, max_count) VALUES ('TOPUP',        'PER_TXN', 5000,  NULL);
INSERT INTO wallet_limits (txn_type, period_type, max_amount, max_count) VALUES ('TOPUP',        'DAILY',   10000, 10);
INSERT INTO wallet_limits (txn_type, period_type, max_amount, max_count) VALUES ('TRANSFER_OUT', 'PER_TXN', 2500,  NULL);
INSERT INTO wallet_limits (txn_type, period_type, max_amount, max_count) VALUES ('TRANSFER_OUT', 'DAILY',   5000,  20);
INSERT INTO wallet_limits (txn_type, period_type, max_amount, max_count) VALUES ('TRANSFER_OUT', 'MONTHLY', 20000, NULL);
