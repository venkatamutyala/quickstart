-- Bootstrap only — runs ONCE on first DB init (docker-entrypoint-initdb.d).
-- This is NOT for migrations: your app's ORM owns the schema (migrate on startup).
-- Put only things the ORM can't do here (extensions, extra roles/databases).
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
