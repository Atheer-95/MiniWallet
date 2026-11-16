# 0001. Use Flyway for all schema changes

- Status: Accepted
- Date: 2026-11-14

## Context
The schema will change many times during the project and must be rebuilt the same way on any machine and in CI.

## Decision
Every change to tables, indexes, grants or reference data is a versioned Flyway migration in `db/migrations`. A migration that has run is never edited; fixes go in a new migration. SQL Developer is used for queries only.

## Consequences
- The database can be rebuilt from scratch with one command.
- Every change is reviewed and kept in Git.
- Small mistakes need a new migration instead of a quick edit.

## Revisit when
Never expected to change.
