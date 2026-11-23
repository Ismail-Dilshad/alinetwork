#!/usr/bin/env bash
# Runs once, the first time the Postgres data folder is created.
# Creates one database + one login role per environment.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
  CREATE ROLE alinetwork_prod    LOGIN PASSWORD '${PROD_DB_PASSWORD}';
  CREATE ROLE alinetwork_staging LOGIN PASSWORD '${STAGING_DB_PASSWORD}';

  CREATE DATABASE alinetwork_prod    OWNER alinetwork_prod;
  CREATE DATABASE alinetwork_staging OWNER alinetwork_staging;

  REVOKE ALL ON DATABASE alinetwork_prod    FROM PUBLIC;
  REVOKE ALL ON DATABASE alinetwork_staging FROM PUBLIC;
SQL

# Extensions the app relies on
for db in alinetwork_prod alinetwork_staging; do
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<-SQL
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS citext;
SQL
done
