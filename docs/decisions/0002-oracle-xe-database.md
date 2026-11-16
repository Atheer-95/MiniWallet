# 0002. Use Oracle XE as the database

- Status: Accepted
- Date: 2026-11-17

## Context
Oracle matches the systems used at work and the 1Z0-071 exam. Oracle XE is free but limited to 2 CPU threads, 2 GB of memory and 12 GB of user data. Commercial Oracle editions are costly. The project may become a commercial product later.

## Decision
Build on Oracle XE 21c. Keep database-specific SQL inside migrations and reporting queries; application code uses JPA so that most of it does not depend on Oracle.

## Consequences
- Direct practice with the same database used at work.
- Moving to another database later means rewriting migrations and some queries, not the whole API.

## Revisit when
- The project moves toward production use, or
- Data or load approaches the XE limits.
Main alternative: PostgreSQL.
