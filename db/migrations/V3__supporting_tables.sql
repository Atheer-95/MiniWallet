-- V3: supporting tables for login sessions and transaction limits

CREATE TABLE refresh_tokens (
  token_id     NUMBER GENERATED ALWAYS AS IDENTITY
               CONSTRAINT pk_refresh_tokens PRIMARY KEY,
  customer_id  NUMBER        NOT NULL
               CONSTRAINT fk_refresh_tokens_customers REFERENCES customers (customer_id),
  token_hash   VARCHAR2(100) NOT NULL
               CONSTRAINT uq_refresh_tokens_hash UNIQUE,
  device_name  VARCHAR2(60),
  expires_at   TIMESTAMP     NOT NULL,
  revoked_at   TIMESTAMP,
  created_at   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE TABLE wallet_limits (
  limit_id     NUMBER GENERATED ALWAYS AS IDENTITY
               CONSTRAINT pk_wallet_limits PRIMARY KEY,
  txn_type     VARCHAR2(20)  NOT NULL
               CONSTRAINT fk_wallet_limits_types REFERENCES txn_types (type_code),
  period_type  VARCHAR2(10)  NOT NULL
               CONSTRAINT ck_wallet_limits_period CHECK (period_type IN ('PER_TXN','DAILY','MONTHLY')),
  max_amount   NUMBER(15,2)  NOT NULL
               CONSTRAINT ck_wallet_limits_amount CHECK (max_amount > 0),
  max_count    NUMBER(5),
  is_active    CHAR(1)       DEFAULT 'Y' NOT NULL
               CONSTRAINT ck_wallet_limits_active CHECK (is_active IN ('Y','N')),
  updated_at   TIMESTAMP,
  CONSTRAINT uq_wallet_limits_type_period UNIQUE (txn_type, period_type)
);
