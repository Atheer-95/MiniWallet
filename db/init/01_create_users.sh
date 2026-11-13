#!/bin/bash
# Runs once, on the first start of the database.
# Creates the MiniWallet users inside the pluggable database XEPDB1.

set -e

sqlplus -s / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SESSION SET CONTAINER = XEPDB1;

CREATE USER miniwallet IDENTIFIED BY "${DB_OWNER_PASSWORD}"
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE,
      CREATE VIEW, CREATE PROCEDURE TO miniwallet;

CREATE USER miniwallet_app IDENTIFIED BY "${DB_APP_PASSWORD}";
GRANT CREATE SESSION TO miniwallet_app;

EXIT;
EOF
