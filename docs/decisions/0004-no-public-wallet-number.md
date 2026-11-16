# 0004. No public wallet number in version 1

- Status: Accepted
- Date: 2026-11-16

## Context
`wallet_id` is a sequential internal key. Showing it to customers would make accounts easy to guess and reveal how many customers exist. Version 1 transfers use the receiver's mobile number.

## Decision
Do not add a public account number in version 1. Never show `wallet_id` to customers.

## Consequences
- Fewer columns and less logic now.
- Customers cannot share an account number.

## Revisit when
A feature needs a shareable account number, such as statements, QR payments or transfers without a mobile number. Add `wallet_number` (random, unique, never changes) in a new migration.
