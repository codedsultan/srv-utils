#!/usr/bin/env bash
# alerts-setup.sh (phase-ready)
# - Installs a tiny 'notify' helper (Slack + local mail)
# - Installs 'srv-health-check' (disk & load)
# - Schedules cron @ 09:00 daily
set -euo pipefail

SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
DISK_THRESHOLD="${DISK_THRESHOLD:-85}"     # %
LOAD_THRESHOLD="${LOAD_THRESHOLD:-4.00}"   # 1-min average
HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
LOG_FILE="/var/log/srv-utils.log"
log(){ echo -e "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
has(){ command -v "$1" >/dev/null 2>&1; }

install -d /usr/local/bin

# notify helper (Slack + local mail)
cat > /usr/local/bin/notify <<'NOTIFY'
#!/usr/bin/env bash
set -euo pipefail
SUBJECT="${1:-srv-utils alert}"
BODY="${2:-(no details)}"

# Slack (if configured in env)
if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
  # JSON-escape via Python (available by default) for reliability
  python3 - <<PY || true
import json, os, sys, urllib.request
payload = json.dumps({"text": f"{SUBJECT}\n{BODY}"}).encode()
req = urllib.request.Request(os.environ["SLACK_WEBHOOK_URL"], data=payload, headers={"Content-Type":"application/json"})
try:
  urllib.request.urlopen(req, timeout=5)
except Exception as e:
  pass
PY
fi

# Email (if 'mail' exists)
if command -v mail >/dev/null 2>&1; then
  echo -e "$BODY" | mail -s "$SUBJECT" root || true
elif command -v sendmail >/dev/null 2>&1; then
  {
    echo "Subject: $SUBJECT"
    echo "To: root"
    echo
    echo -e "$BODY"
  } | sendmail -t || true
fi
NOTIFY
chmod +x /usr/local/bin/notify

# health check
cat > /usr/local/bin/srv-health-check <<'HEALTH'
#!/usr/bin/env bash
set -euo pipefail
DISK_THRESHOLD="${DISK_THRESHOLD:-85}"
LOAD_THRESHOLD="${LOAD_THRESHOLD:-4.00}"
HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"

ALERTS=""

# Disk usage (root fs)
USE=$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')
if [[ "$USE" -ge "$DISK_THRESHOLD" ]]; then
  ALERTS+="Disk usage high on $HOSTNAME_FQDN: ${USE}% >= ${DISK_THRESHOLD}%\n"
fi

# Load (1-min average)
LOAD=$(awk '{print $1}' /proc/loadavg)
awk -v a="$LOAD" -v b="$LOAD_THRESHOLD" 'BEGIN{exit!(a>b)}' || true
if awk -v a="$LOAD" -v b="$LOAD_THRESHOLD" 'BEGIN{exit(a>b?0:1)}'; then
  ALERTS+="Load high on $HOSTNAME_FQDN: ${LOAD} > ${LOAD_THRESHOLD}\n"
fi

if [[ -n "$ALERTS" ]]; then
  /usr/local/bin/notify "srv-utils alert on $HOSTNAME_FQDN" "$ALERTS"
fi
HEALTH
chmod +x /usr/local/bin/srv-health-check

# Cron daily @ 09:00
CRON="0 9 * * * DISK_THRESHOLD=${DISK_THRESHOLD} LOAD_THRESHOLD=${LOAD_THRESHOLD} SLACK_WEBHOOK_URL='${SLACK_WEBHOOK_URL}' /usr/local/bin/srv-health-check >/dev/null 2>&1"
( crontab -l 2>/dev/null | grep -v 'srv-health-check' ; echo "$CRON" ) | crontab -

log "Monitoring installed. Test:"
log "SLACK_WEBHOOK_URL='${SLACK_WEBHOOK_URL}' /usr/local/bin/notify 'srv-utils test' 'Hello from ${HOSTNAME_FQDN}'"