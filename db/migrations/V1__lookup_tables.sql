-- V1: lookup tables for transaction types, statuses and gateway response codes

CREATE TABLE txn_types (
  type_code    VARCHAR2(20)  CONSTRAINT pk_txn_types PRIMARY KEY,
  description  VARCHAR2(100) NOT NULL,
  direction    CHAR(1)       NOT NULL
               CONSTRAINT ck_txn_types_direction CHECK (direction IN ('C','D'))
);

CREATE TABLE txn_statuses (
  status_code  VARCHAR2(10)  CONSTRAINT pk_txn_statuses PRIMARY KEY,
  description  VARCHAR2(100) NOT NULL,
  is_final     CHAR(1)       NOT NULL
               CONSTRAINT ck_txn_statuses_final CHECK (is_final IN ('Y','N'))
);

CREATE TABLE response_codes (
  response_code   VARCHAR2(3)   CONSTRAINT pk_response_codes PRIMARY KEY,
  description     VARCHAR2(100) NOT NULL,
  is_approved     CHAR(1)       NOT NULL
                  CONSTRAINT ck_resp_codes_approved CHECK (is_approved IN ('Y','N')),
  api_error_code  VARCHAR2(30)
);
