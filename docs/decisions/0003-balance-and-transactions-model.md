# 0003. Balance + transactions instead of a double-entry ledger

- Status: Accepted
- Date: 2026-11-17

## Context
Banking systems usually record money with a double-entry ledger, where every movement is a debit and a credit that sum to zero. It is harder to build and learn. Version 1 is a learning project.

## Decision
Store the current balance in `wallets` and every movement as a row in `transactions`. All balance changes go through one service in the API. A reconciliation query checks that each balance equals its transaction history.

## Consequences
- Simpler schema and code.
- Auditors and regulators of a real product would expect a ledger.
- Because all money movement passes through one service, a ledger can replace it without touching the rest of the code.

## Revisit when
- The project moves toward a commercial version, or
- Fees, multiple currencies or settlement accounts are added.
