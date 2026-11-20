#!/usr/bin/env bash
# Runs the database tests on a local Postgres (no Supabase needed).
#   PGHOST=/tmp PGPORT=54329 PGUSER=postgres supabase/tests/run_local.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${TEST_DB:-diamond_test}
psql -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
psql -v ON_ERROR_STOP=1 -q -d "$DB" -f tests/local/00_supabase_stub.sql 2>&1 | grep -v wal_level | grep -v 'HINT:' || true
for f in migrations/*.sql; do
  psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$f"
done
psql -v ON_ERROR_STOP=1 -q -o /dev/null -d "$DB" -f tests/local/10_rules_and_security_test.sql
