#!/bin/bash
set -euo pipefail
psql --username "$POSTGRES_USER" --dbname postgres -v ON_ERROR_STOP=1 \
  -v canvas_password="$CANVAS_DB_PASSWORD" -v pkbm_password="$PKBM_DB_PASSWORD" <<'SQL'
CREATE ROLE canvas LOGIN PASSWORD :'canvas_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE canvas_readonly_user NOLOGIN;
CREATE ROLE pkbm LOGIN PASSWORD :'pkbm_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE DATABASE canvas_development OWNER canvas;
CREATE DATABASE pkbm_development OWNER pkbm;
REVOKE CONNECT ON DATABASE canvas_development FROM PUBLIC;
REVOKE CONNECT ON DATABASE pkbm_development FROM PUBLIC;
GRANT CONNECT ON DATABASE canvas_development TO canvas;
GRANT CONNECT ON DATABASE pkbm_development TO pkbm;
SQL
psql --username "$POSTGRES_USER" --dbname canvas_development -v ON_ERROR_STOP=1 -c 'CREATE EXTENSION IF NOT EXISTS vector;'
