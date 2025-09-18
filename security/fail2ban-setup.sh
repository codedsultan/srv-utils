#!/usr/bin/env bash
# fail2ban-setup.sh (phase-ready)
# - Installs & configures Fail2Ban for SSH
# - Email alerts (required: FAIL2BAN_EMAIL)
# - Optional Slack alerts (SLACK_WEBHOOK_URL)
# - Optional whitelist of current SSH client (WHITELIST_MYIP=yes|no, default no)
set -euo pipefail

: "${FAIL2BAN_EMAIL:?Set FAIL2BAN_EMAIL}"
: "${SSH_PORT:?Set SSH_PORT (e.g., 22)}"
SERVER_HOSTNAME="${SERVER_HOSTNAME:-$(hostname -f)}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
WHITELIST_MYIP="${WHITELIST_MYIP:-no}"

LOG_FILE="/var/log/srv-utils.log"
log(){ echo -e "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
has(){ command -v "$1" >/dev/null 2>&1; }

# Optional whitelist of current SSH client IP
ALLOW_IPS="127.0.0.1/8 ::1"
if [[ "$WHITELIST_MYIP" == "yes" && -n "${SSH_CONNECTION:-}" ]]; then
  CLIENT_IP="${SSH_CONNECTION%% *}"
  ALLOW_IPS="$ALLOW_IPS $CLIENT_IP"
  log "Whitelisting current SSH client IP: $CLIENT_IP"
else
  log "Not whitelisting dynamic client IP (WHITELIST_MYIP=$WHITELIST_MYIP)"
fi

# Detect auth log path
AUTH_LOG="/var/log/auth.log"
[[ -f /var/log/secure ]] && AUTH_LOG="/var/log/secure"

log "AUTH_LOG: $AUTH_LOG | SSH_PORT: $SSH_PORT | EMAIL: $FAIL2BAN_EMAIL | HOSTNAME: $SERVER_HOSTNAME"
[[ -n "$SLACK_WEBHOOK_URL" ]] && log "Slack: enabled" || log "Slack: disabled"

# Install deps
if ! has fail2ban-client; then
  if has apt; then apt update && apt install -y fail2ban curl
  elif has dnf; then dnf install -y fail2ban curl; systemctl enable --now fail2ban || true
  elif has yum; then yum install -y epel-release || true; yum install -y fail2ban curl; systemctl enable --now fail2ban || true
  else log "Unsupported package manager"; exit 1;
  fi
fi

install -d /etc/fail2ban
cat > /etc/fail2ban/jail.local <<JAIL
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3
ignoreip = ${ALLOW_IPS}

destemail  = ${FAIL2BAN_EMAIL}
sendername = Fail2Ban on ${SERVER_HOSTNAME}
mta        = sendmail

# Email ban + whois + log excerpts
action = %(action_mwl)s

[sshd]
enabled  = true
port     = ${SSH_PORT}
filter   = sshd
logpath  = ${AUTH_LOG}
maxretry = 3
bantime  = 7200
findtime = 300
JAIL

# Optional Slack action
if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
  log "Enabling Slack notifications..."
  cat > /etc/fail2ban/action.d/slack-notify.conf <<'SLACK'
[Definition]
actionstart = curl -sS -X POST -H 'Content-type: application/json' --data "{\"text\":\"🛡️ Fail2Ban started on <hostname>\"}" <webhook>
actionstop  = curl -sS -X POST -H 'Content-type: application/json' --data "{\"text\":\"🛑 Fail2Ban stopped on <hostname>\"}" <webhook>
actioncheck =
actionban   = curl -sS -X POST -H 'Content-type: application/json' --data "{\"text\":\"🚨 BANNED IP: <ip> on <hostname>\nService: <name>\nTime: <time>\"}" <webhook>
actionunban = curl -sS -X POST -H 'Content-type: application/json' --data "{\"text\":\"✅ UNBANNED IP: <ip> on <hostname>\nService: <name>\nTime: <time>\"}" <webhook>

[Init]
name = default
SLACK
  sed -i "s#<hostname>#${SERVER_HOSTNAME//[#&]/}#g" /etc/fail2ban/action.d/slack-notify.conf
  sed -i "s#<webhook>#${SLACK_WEBHOOK_URL}#g" /etc/fail2ban/action.d/slack-notify.conf

  # Append 'slack-notify' to DEFAULT action once
  awk '
    BEGIN{in_def=0}
    /^\[DEFAULT\]/{in_def=1}
    /^\[.*\]/{if($0!~"\\[DEFAULT\\]") in_def=0}
    {print}
    in_def==1 && /^action *=/ && appended!=1 {print "         slack-notify"; appended=1}
  ' /etc/fail2ban/jail.local > /etc/fail2ban/jail.local.tmp && mv /etc/fail2ban/jail.local.tmp /etc/fail2ban/jail.local
fi

log "Testing Fail2Ban configuration..."
fail2ban-client -t

systemctl enable fail2ban >/dev/null 2>&1 || true
systemctl reload fail2ban 2>/dev/null || systemctl restart fail2ban

sleep 1
systemctl --no-pager -l status fail2ban || true
fail2ban-client status || true

log "Fail2Ban setup: done."