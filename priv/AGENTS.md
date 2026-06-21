# priv — Private Application Assets

This directory contains database migration files used to set up and evolve the test database schema.

## Contents

- `repo/migrations/` — Ecto migration files. Each migration creates or modifies a database table used by the test schemas in `test/support/schema/`.

## When to add a migration

Add a new migration when you add a new test schema that requires a database table, or when you modify an existing test schema in a way that changes its columns.

Run `mix ecto.migrate` to apply pending migrations to the test database.
