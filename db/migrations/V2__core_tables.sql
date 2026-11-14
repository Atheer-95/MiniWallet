-- V2: core tables for customers, wallets, cards, transactions and logs

CREATE TABLE customers (
  customer_id         NUMBER GENERATED ALWAYS AS IDENTITY
                      CONSTRAINT pk_customers PRIMARY KEY,
  mobile_no           VARCHAR2(15)  NOT NULL
                      CONSTRAINT uq_customers_mobile_no UNIQUE,
  email               VARCHAR2(100)
                      CONSTRAINT uq_customers_email UNIQUE,
  full_name           VARCHAR2(100) NOT NULL,
  password_hash       VARCHAR2(100) NOT NULL,
  status              VARCHAR2(10)  DEFAULT 'ACTIVE' NOT NULL
                      CONSTRAINT ck_customers_status CHECK (status IN ('ACTIVE','LOCKED','CLOSED')),
  failed_login_count  NUMBER(2)     DEFAULT 0 NOT NULL
                      CONSTRAINT ck_customers_failed CHECK (failed_login_count >= 0),
  last_login_at       TIMESTAMP,
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at          TIMESTAMP
);

CREATE TABLE wallets (
  wallet_id    NUMBER GENERATED ALWAYS AS IDENTITY
               CONSTRAINT pk_wallets PRIMARY KEY,
  customer_id  NUMBER        NOT NULL
               CONSTRAINT fk_wallets_customers REFERENCES customers (customer_id)
               CONSTRAINT uq_wallets_customer_id UNIQUE,
  balance      NUMBER(15,2)  DEFAULT 0 NOT NULL
               CONSTRAINT ck_wallets_balance CHECK (balance >= 0),
  currency     CHAR(3)       DEFAULT 'SAR' NOT NULL,
  status       VARCHAR2(10)  DEFAULT 'ACTIVE' NOT NULL
               CONSTRAINT ck_wallets_status CHECK (status IN ('ACTIVE','FROZEN','CLOSED')),
  version      NUMBER        DEFAULT 0 NOT NULL,
  created_at   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at   TIMESTAMP
);

CREATE TABLE cards (
  card_id       NUMBER GENERATED ALWAYS AS IDENTITY
                CONSTRAINT pk_cards PRIMARY KEY,
  customer_id   NUMBER        NOT NULL
                CONSTRAINT fk_cards_customers REFERENCES customers (customer_id),
  card_token    VARCHAR2(64)  NOT NULL
                CONSTRAINT uq_cards_card_token UNIQUE,
  masked_pan    VARCHAR2(19)  NOT NULL,
  brand         VARCHAR2(10)  NOT NULL
                CONSTRAINT ck_cards_brand CHECK (brand IN ('VISA','MASTERCARD','MADA')),
  expiry_month  NUMBER(2)     NOT NULL
                CONSTRAINT ck_cards_exp_month CHECK (expiry_month BETWEEN 1 AND 12),
  expiry_year   NUMBER(4)     NOT NULL
                CONSTRAINT ck_cards_exp_year CHECK (expiry_year >= 2024),
  nickname      VARCHAR2(30),
  status        VARCHAR2(10)  DEFAULT 'ACTIVE' NOT NULL
                CONSTRAINT ck_cards_status CHECK (status IN ('ACTIVE','REMOVED')),
  created_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  removed_at    TIMESTAMP
);

CREATE TABLE transactions (
  txn_id                  NUMBER GENERATED ALWAYS AS IDENTITY
                          CONSTRAINT pk_transactions PRIMARY KEY,
  wallet_id               NUMBER        NOT NULL
                          CONSTRAINT fk_transactions_wallets REFERENCES wallets (wallet_id),
  txn_type                VARCHAR2(20)  NOT NULL
                          CONSTRAINT fk_transactions_types REFERENCES txn_types (type_code),
  status                  VARCHAR2(10)  DEFAULT 'PENDING' NOT NULL
                          CONSTRAINT fk_transactions_statuses REFERENCES txn_statuses (status_code),
  amount                  NUMBER(15,2)  NOT NULL
                          CONSTRAINT ck_transactions_amount CHECK (amount > 0),
  currency                CHAR(3)       DEFAULT 'SAR' NOT NULL,
  balance_after           NUMBER(15,2),
  card_id                 NUMBER
                          CONSTRAINT fk_transactions_cards REFERENCES cards (card_id),
  counterparty_wallet_id  NUMBER
                          CONSTRAINT fk_transactions_counterparty REFERENCES wallets (wallet_id),
  related_txn_id          NUMBER
                          CONSTRAINT fk_transactions_related REFERENCES transactions (txn_id),
  idempotency_key         VARCHAR2(64)  NOT NULL,
  rrn                     VARCHAR2(12),
  auth_code               VARCHAR2(6),
  response_code           VARCHAR2(3)
                          CONSTRAINT fk_transactions_resp_codes REFERENCES response_codes (response_code),
  description             VARCHAR2(140),
  correlation_id          VARCHAR2(64)  NOT NULL,
  created_at              TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at              TIMESTAMP,
  CONSTRAINT uq_transactions_wallet_idem UNIQUE (wallet_id, idempotency_key),
  CONSTRAINT ck_transactions_topup_card
    CHECK (txn_type <> 'TOPUP' OR card_id IS NOT NULL),
  CONSTRAINT ck_transactions_transfer_cp
    CHECK (txn_type NOT IN ('TRANSFER_OUT','TRANSFER_IN') OR counterparty_wallet_id IS NOT NULL),
  CONSTRAINT ck_transactions_not_self
    CHECK (counterparty_wallet_id IS NULL OR counterparty_wallet_id <> wallet_id)
);

CREATE TABLE gateway_log (
  log_id          NUMBER GENERATED ALWAYS AS IDENTITY
                  CONSTRAINT pk_gateway_log PRIMARY KEY,
  txn_id          NUMBER
                  CONSTRAINT fk_gateway_log_transactions REFERENCES transactions (txn_id),
  correlation_id  VARCHAR2(64)  NOT NULL,
  endpoint        VARCHAR2(50)  NOT NULL,
  direction       VARCHAR2(8)   NOT NULL
                  CONSTRAINT ck_gateway_log_direction CHECK (direction IN ('REQUEST','RESPONSE')),
  http_status     NUMBER(3),
  payload         CLOB,
  latency_ms      NUMBER(6),
  created_at      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE TABLE audit_log (
  audit_id        NUMBER GENERATED ALWAYS AS IDENTITY
                  CONSTRAINT pk_audit_log PRIMARY KEY,
  customer_id     NUMBER
                  CONSTRAINT fk_audit_log_customers REFERENCES customers (customer_id),
  action          VARCHAR2(40)  NOT NULL,
  entity_type     VARCHAR2(30),
  entity_id       NUMBER,
  ip_address      VARCHAR2(45),
  user_agent      VARCHAR2(200),
  correlation_id  VARCHAR2(64),
  details         VARCHAR2(1000),
  created_at      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);
