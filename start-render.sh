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
LIMIT_TIME_REAL_VALUE="${LIMIT_TIME_REAL:-600}"
LIMIT_TIME_CPU_VALUE="${LIMIT_TIME_CPU:-300}"
CORE_MODULES_VALUE="${CORE_MODULES:-website_sale,sale_management,stock,account,payment,b2b_ecommerce_suite}"
BOOTSTRAP_MODULES_VALUE="${BOOTSTRAP_MODULES:-base,website_sale,sale_management,stock,account,payment,b2b_ecommerce_suite}"
RUNTIME_CONFIG_PATH="/tmp/odoo-runtime.conf"
DB_CONNECT_RETRIES_VALUE="${DB_CONNECT_RETRIES:-20}"
DB_CONNECT_RETRY_DELAY_VALUE="${DB_CONNECT_RETRY_DELAY:-5}"
AUTO_INSTALL_ON_START_VALUE="${AUTO_INSTALL_ON_START:-1}"
AUTO_UPGRADE_B2B_ON_START_VALUE="${AUTO_UPGRADE_B2B_ON_START:-1}"
WEB_BASE_URL_VALUE="${WEB_BASE_URL:-${PUBLIC_BASE_URL:-}}"

if [ -z "${DB_HOST_VALUE}" ] || [ -z "${DB_USER_VALUE}" ] || [ -z "${DB_PASSWORD_VALUE}" ]; then
  echo "Missing required DB env vars. Set DB_HOST/DB_USER/DB_PASSWORD (or HOST/USER/PASSWORD)." >&2
  exit 1
fi

DB_NAME_REGEX="$(python3 - <<PY
import re
print(re.escape("${DB_NAME_VALUE}"))
PY
)"

python3 - <<PY
from pathlib import Path

source_path = Path("/etc/odoo/odoo.conf")
target_path = Path("${RUNTIME_CONFIG_PATH}")
managed_keys = ("db_name", "dbfilter", "list_db")

lines = []
for line in source_path.read_text(encoding="utf-8").splitlines():
    stripped = line.strip().lower()
    if any(stripped.startswith(f"{key} =") for key in managed_keys):
        continue
    lines.append(line)

lines.extend(
    [
        "db_name = ${DB_NAME_VALUE}",
        "dbfilter = ^${DB_NAME_REGEX}$",
        "list_db = False",
    ]
)
target_path.write_text("\\n".join(lines) + "\\n", encoding="utf-8")
PY

if [ "${CLEAN_WEB_ASSETS_ON_START:-1}" = "1" ]; then
  echo "Cleaning stale /web/assets attachments from database..."
  python3 - <<PY
import psycopg2
import time

last_error = None
for attempt in range(1, int("${DB_CONNECT_RETRIES_VALUE}") + 1):
    try:
        conn = psycopg2.connect(
            host="${DB_HOST_VALUE}",
            port="${DB_PORT_VALUE}",
            user="${DB_USER_VALUE}",
            password="${DB_PASSWORD_VALUE}",
            dbname="${DB_NAME_VALUE}",
            sslmode="${DB_SSLMODE_VALUE}",
        )
        break
    except Exception as exc:
        last_error = exc
        print(f"db_connect_retry={attempt}/{int('${DB_CONNECT_RETRIES_VALUE}')}: {exc}")
        if attempt == int("${DB_CONNECT_RETRIES_VALUE}"):
            raise
        time.sleep(int("${DB_CONNECT_RETRY_DELAY_VALUE}"))

cur = conn.cursor()
cur.execute("DELETE FROM ir_attachment WHERE url LIKE '/web/assets/%'")
print(f"deleted_assets_rows={cur.rowcount}")
conn.commit()
cur.close()
conn.close()
PY
fi

MODULE_STATE="$(python3 - <<PY
import psycopg2
import time

for attempt in range(1, int("${DB_CONNECT_RETRIES_VALUE}") + 1):
    try:
        conn = psycopg2.connect(
            host="${DB_HOST_VALUE}",
            port="${DB_PORT_VALUE}",
            user="${DB_USER_VALUE}",
            password="${DB_PASSWORD_VALUE}",
            dbname="${DB_NAME_VALUE}",
            sslmode="${DB_SSLMODE_VALUE}",
        )
        break
    except Exception as exc:
        print(f"db_connect_retry={attempt}/{int('${DB_CONNECT_RETRIES_VALUE}')}: {exc}")
        if attempt == int("${DB_CONNECT_RETRIES_VALUE}"):
            raise
        time.sleep(int("${DB_CONNECT_RETRY_DELAY_VALUE}"))

cur = conn.cursor()
cur.execute("SELECT to_regclass('public.ir_module_module')")
table_name = cur.fetchone()[0]
if not table_name:
    print("bootstrap")
else:
    cur.execute("SELECT state FROM ir_module_module WHERE name = 'b2b_ecommerce_suite'")
    row = cur.fetchone()
    print(row[0] if row else "missing")
cur.close()
conn.close()
PY
)"

if [ "${AUTO_INSTALL_ON_START_VALUE}" != "1" ]; then
  echo "Skipping bootstrap/install on startup because AUTO_INSTALL_ON_START=${AUTO_INSTALL_ON_START_VALUE}."
elif [ "${MODULE_STATE}" = "bootstrap" ]; then
  echo "Bootstrapping Odoo schema and B2B stack inside database ${DB_NAME_VALUE}..."
  odoo \
    --config="${RUNTIME_CONFIG_PATH}" \
    --proxy-mode \
    --data-dir="${DATA_DIR_VALUE}" \
    --db_host="${DB_HOST_VALUE}" \
    --db_port="${DB_PORT_VALUE}" \
    --db_user="${DB_USER_VALUE}" \
    --db_password="${DB_PASSWORD_VALUE}" \
    --database="${DB_NAME_VALUE}" \
    --db_sslmode="${DB_SSLMODE_VALUE}" \
    --limit-time-real="${LIMIT_TIME_REAL_VALUE}" \
    --limit-time-cpu="${LIMIT_TIME_CPU_VALUE}" \
    -i "${BOOTSTRAP_MODULES_VALUE}" \
    --without-demo=all \
    --stop-after-init
elif [ "${MODULE_STATE}" = "missing" ] || [ "${MODULE_STATE}" = "uninstalled" ] || [ "${MODULE_STATE}" = "to install" ]; then
  echo "Installing B2B stack inside database ${DB_NAME_VALUE}..."
  odoo \
    --config="${RUNTIME_CONFIG_PATH}" \
    --proxy-mode \
    --data-dir="${DATA_DIR_VALUE}" \
    --db_host="${DB_HOST_VALUE}" \
    --db_port="${DB_PORT_VALUE}" \
    --db_user="${DB_USER_VALUE}" \
    --db_password="${DB_PASSWORD_VALUE}" \
    --database="${DB_NAME_VALUE}" \
    --db_sslmode="${DB_SSLMODE_VALUE}" \
    --limit-time-real="${LIMIT_TIME_REAL_VALUE}" \
    --limit-time-cpu="${LIMIT_TIME_CPU_VALUE}" \
    -i "${CORE_MODULES_VALUE}" \
    --without-demo=all \
    --stop-after-init
elif [ "${MODULE_STATE}" = "to upgrade" ]; then
  echo "Upgrading B2B module inside database ${DB_NAME_VALUE}..."
  odoo \
    --config="${RUNTIME_CONFIG_PATH}" \
    --proxy-mode \
    --data-dir="${DATA_DIR_VALUE}" \
    --db_host="${DB_HOST_VALUE}" \
    --db_port="${DB_PORT_VALUE}" \
    --db_user="${DB_USER_VALUE}" \
    --db_password="${DB_PASSWORD_VALUE}" \
    --database="${DB_NAME_VALUE}" \
    --db_sslmode="${DB_SSLMODE_VALUE}" \
    --limit-time-real="${LIMIT_TIME_REAL_VALUE}" \
    --limit-time-cpu="${LIMIT_TIME_CPU_VALUE}" \
    -u b2b_ecommerce_suite \
    --without-demo=all \
    --stop-after-init
elif [ "${MODULE_STATE}" = "installed" ] && [ "${AUTO_UPGRADE_B2B_ON_START_VALUE}" = "1" ]; then
  echo "Refreshing installed B2B module inside database ${DB_NAME_VALUE}..."
  odoo \
    --config="${RUNTIME_CONFIG_PATH}" \
    --proxy-mode \
    --data-dir="${DATA_DIR_VALUE}" \
    --db_host="${DB_HOST_VALUE}" \
    --db_port="${DB_PORT_VALUE}" \
    --db_user="${DB_USER_VALUE}" \
    --db_password="${DB_PASSWORD_VALUE}" \
    --database="${DB_NAME_VALUE}" \
    --db_sslmode="${DB_SSLMODE_VALUE}" \
    --limit-time-real="${LIMIT_TIME_REAL_VALUE}" \
    --limit-time-cpu="${LIMIT_TIME_CPU_VALUE}" \
    -u b2b_ecommerce_suite \
    --without-demo=all \
    --stop-after-init
fi

if [ -n "${WEB_BASE_URL_VALUE}" ]; then
  echo "Ensuring web.base.url=${WEB_BASE_URL_VALUE} in database ${DB_NAME_VALUE}..."
  python3 - <<PY
import psycopg2
import time

for attempt in range(1, int("${DB_CONNECT_RETRIES_VALUE}") + 1):
    try:
        conn = psycopg2.connect(
            host="${DB_HOST_VALUE}",
            port="${DB_PORT_VALUE}",
            user="${DB_USER_VALUE}",
            password="${DB_PASSWORD_VALUE}",
            dbname="${DB_NAME_VALUE}",
            sslmode="${DB_SSLMODE_VALUE}",
        )
        break
    except Exception as exc:
        print(f"db_connect_retry={attempt}/{int('${DB_CONNECT_RETRIES_VALUE}')}: {exc}")
        if attempt == int("${DB_CONNECT_RETRIES_VALUE}"):
            raise
        time.sleep(int("${DB_CONNECT_RETRY_DELAY_VALUE}"))

cur = conn.cursor()
cur.execute("SELECT to_regclass('public.ir_config_parameter')")
if cur.fetchone()[0]:
    cur.execute(
        """
        INSERT INTO ir_config_parameter (key, value, create_uid, write_uid, create_date, write_date)
        VALUES ('web.base.url', %s, 1, 1, NOW(), NOW())
        ON CONFLICT (key)
        DO UPDATE SET value = EXCLUDED.value, write_uid = 1, write_date = NOW()
        """,
        ("${WEB_BASE_URL_VALUE}",),
    )
    print(f"web_base_url_updated=${WEB_BASE_URL_VALUE}")
    conn.commit()
else:
    print("ir_config_parameter_not_ready")
cur.close()
conn.close()
PY
fi

if [ "${RUN_MODULE_REPAIR_ON_START:-0}" = "1" ]; then
  echo "Running one-time module repair (upgrade B2B stack)..."
  odoo \
    --config="${RUNTIME_CONFIG_PATH}" \
    --proxy-mode \
    --data-dir="${DATA_DIR_VALUE}" \
    --db_host="${DB_HOST_VALUE}" \
    --db_port="${DB_PORT_VALUE}" \
    --db_user="${DB_USER_VALUE}" \
    --db_password="${DB_PASSWORD_VALUE}" \
    --database="${DB_NAME_VALUE}" \
    --db_sslmode="${DB_SSLMODE_VALUE}" \
    --limit-time-real="${LIMIT_TIME_REAL_VALUE}" \
    --limit-time-cpu="${LIMIT_TIME_CPU_VALUE}" \
    -u "${CORE_MODULES_VALUE}" \
    --stop-after-init
fi

exec odoo \
  --config="${RUNTIME_CONFIG_PATH}" \
  --proxy-mode \
  --data-dir="${DATA_DIR_VALUE}" \
  --http-port="${HTTP_PORT_VALUE}" \
  --db_host="${DB_HOST_VALUE}" \
  --db_port="${DB_PORT_VALUE}" \
  --db_user="${DB_USER_VALUE}" \
  --db_password="${DB_PASSWORD_VALUE}" \
  --database="${DB_NAME_VALUE}" \
  --db_sslmode="${DB_SSLMODE_VALUE}" \
  --limit-time-real="${LIMIT_TIME_REAL_VALUE}" \
  --limit-time-cpu="${LIMIT_TIME_CPU_VALUE}"
