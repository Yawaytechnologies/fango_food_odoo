#!/bin/bash
set -euo pipefail

DB_HOST_VALUE="${DB_HOST:-${HOST:-}}"
DB_PORT_VALUE="${DB_PORT:-5432}"
DB_USER_VALUE="${DB_USER:-${USER:-}}"
DB_PASSWORD_VALUE="${DB_PASSWORD:-${PASSWORD:-}}"
DB_NAME_VALUE="${DB_NAME:-fango_food}"
DB_SSLMODE_VALUE="${DB_SSLMODE:-require}"
HTTP_PORT_VALUE="${PORT:-8069}"
DATA_DIR_VALUE="${DATA_DIR:-/var/lib/odoo/.local/share/Odoo}"

if [ -z "${DB_HOST_VALUE}" ] || [ -z "${DB_USER_VALUE}" ] || [ -z "${DB_PASSWORD_VALUE}" ]; then
  echo "Missing required DB env vars. Set DB_HOST/DB_USER/DB_PASSWORD (or HOST/USER/PASSWORD)." >&2
  exit 1
fi

if [ "${CLEAN_WEB_ASSETS_ON_START:-1}" = "1" ]; then
  echo "Cleaning stale /web/assets attachments from database..."
  python3 - <<PY
import psycopg2

conn = psycopg2.connect(
    host="${DB_HOST_VALUE}",
    port="${DB_PORT_VALUE}",
    user="${DB_USER_VALUE}",
    password="${DB_PASSWORD_VALUE}",
    dbname="${DB_NAME_VALUE}",
    sslmode="${DB_SSLMODE_VALUE}",
)
cur = conn.cursor()
cur.execute("DELETE FROM ir_attachment WHERE url LIKE '/web/assets/%'")
print(f"deleted_assets_rows={cur.rowcount}")
conn.commit()
cur.close()
conn.close()
PY
fi

exec odoo \
  --proxy-mode \
  --data-dir="${DATA_DIR_VALUE}" \
  --http-port="${HTTP_PORT_VALUE}" \
  --db_host="${DB_HOST_VALUE}" \
  --db_port="${DB_PORT_VALUE}" \
  --db_user="${DB_USER_VALUE}" \
  --db_password="${DB_PASSWORD_VALUE}" \
  --database="${DB_NAME_VALUE}" \
  --db_sslmode="${DB_SSLMODE_VALUE}"
