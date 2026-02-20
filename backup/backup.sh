#!/usr/bin/env bash
set -euo pipefail

# ---- Config via env ----
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DB="${MYSQL_DB:-medassist}"
MYSQL_USER="${MYSQL_USER:-medassist}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-medassistpass}"

PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://pushgateway:9091}"
RPO_TARGET_SECONDS="${BACKUP_RPO_SECONDS:-1800}"
RETENTION_FILES="${BACKUP_RETENTION_FILES:-48}"

BACKUP_DIR="/backup/data"
JOB="mysql_backup"
INSTANCE="${MYSQL_HOST}_${MYSQL_PORT}"

mkdir -p "$BACKUP_DIR"

# ---- Metrics defaults ----
success=0
exit_code=1
duration=0
size_bytes=0
last_run_ts="$(date +%s)"
last_success_file="${BACKUP_DIR}/.last_success_ts"
last_success_ts="$(cat "${last_success_file}" 2>/dev/null || echo 0)"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"; }

push_metrics() {
  payload=$(cat <<EOF
# TYPE medassist_backup_success gauge
medassist_backup_success ${success}
# TYPE medassist_backup_exit_code gauge
medassist_backup_exit_code ${exit_code}
# TYPE medassist_backup_duration_seconds gauge
medassist_backup_duration_seconds ${duration}
# TYPE medassist_backup_size_bytes gauge
medassist_backup_size_bytes ${size_bytes}
# TYPE medassist_backup_last_run_timestamp gauge
medassist_backup_last_run_timestamp ${last_run_ts}
# TYPE medassist_backup_last_success_timestamp gauge
medassist_backup_last_success_timestamp ${last_success_ts}
# TYPE medassist_backup_rpo_target_seconds gauge
medassist_backup_rpo_target_seconds ${RPO_TARGET_SECONDS}
EOF
)

  for i in $(seq 1 10); do
    if echo "${payload}" | curl -sS --data-binary @- \
      "${PUSHGATEWAY_URL}/metrics/job/${JOB}/instance/${INSTANCE}" >/dev/null; then
      log "OK push metrics to ${PUSHGATEWAY_URL} (try ${i}/10)"
      return 0
    fi
    log "WARN pushgateway not reachable yet (try ${i}/10) -> ${PUSHGATEWAY_URL}"
    sleep 2
  done

  log "ERROR could not push metrics to Pushgateway after retries."
  return 1
}

on_exit() {
  rc=$?
  if [ "${exit_code:-}" = "1" ] && [ "$rc" -ne 0 ]; then
    exit_code="$rc"
  fi
  push_metrics || true
  exit "$rc"
}
trap on_exit EXIT

log "INFO backup starting"
log "INFO MYSQL=${MYSQL_HOST}:${MYSQL_PORT} DB=${MYSQL_DB} USER=${MYSQL_USER}"
log "INFO PUSHGATEWAY=${PUSHGATEWAY_URL}"

getent hosts "${MYSQL_HOST}" >/dev/null 2>&1 && log "OK DNS mysql" || log "WARN DNS mysql"
getent hosts "pushgateway" >/dev/null 2>&1 && log "OK DNS pushgateway" || log "WARN DNS pushgateway"

log "INFO Waiting for MySQL (${MYSQL_HOST}:${MYSQL_PORT}) ..."
ok=0
for i in $(seq 1 30); do
  if mysqladmin ping -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 2
done
if [ "${ok}" -ne 1 ]; then
  log "WARN MySQL not ready after 60s; will try dump anyway."
else
  log "OK MySQL is reachable."
fi

stamp="$(date -u +"%Y%m%dT%H%M%SZ")"
outfile="${BACKUP_DIR}/medassist_${stamp}.sql.gz"

start_ts="$(date +%s)"
set +e

# ✅ FIX MySQL8 : --no-tablespaces (évite privilège PROCESS)
mysqldump \
  --protocol=tcp \
  -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
  -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
  --databases "${MYSQL_DB}" \
  --single-transaction \
  --quick \
  --no-tablespaces \
  2> "${BACKUP_DIR}/mysqldump_last_error.log" \
| gzip -c > "${outfile}"

exit_code=$?
set -e

end_ts="$(date +%s)"
duration="$((end_ts - start_ts))"
last_run_ts="$(date +%s)"

if [ "$exit_code" -ne 0 ]; then
  success=0
  rm -f "${outfile}" >/dev/null 2>&1 || true
  log "ERROR mysqldump failed (exit_code=${exit_code}). Last error:"
  tail -n 50 "${BACKUP_DIR}/mysqldump_last_error.log" || true
else
  success=1
  size_bytes="$(stat -c%s "${outfile}" 2>/dev/null || wc -c < "${outfile}")"
  last_success_ts="$(date +%s)"
  echo "${last_success_ts}" > "${last_success_file}"
  log "OK backup created: ${outfile} (${size_bytes} bytes) in ${duration}s"
fi

# ---- Retention ----
set +e
ls -1t "${BACKUP_DIR}"/medassist_*.sql.gz 2>/dev/null \
  | tail -n +"$((RETENTION_FILES + 1))" \
  | xargs -r rm -f
set -e

log "DONE success=${success} exit_code=${exit_code} duration=${duration}s size=${size_bytes}B last_success_ts=${last_success_ts}"
