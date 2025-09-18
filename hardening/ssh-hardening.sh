#!/usr/bin/env bash
# ssh-hardening.sh (phase-ready)
# - Optional admin user creation
# - SSH configuration hardening with backup + syntax test + safe reload
# - Optional UFW setup on Debian/Ubuntu
set -euo pipefail

NEW_ADMIN_USER="${NEW_ADMIN_USER:-}"
SSH_PORT="${SSH_PORT:-22}"
DISABLE_ROOT_LOGIN="${DISABLE_ROOT_LOGIN:-yes}"
ENABLE_UFW="${ENABLE_UFW:-yes}"

LOG_FILE="/var/log/srv-utils.log"
log(){ echo -e "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
has(){ command -v "$1" >/dev/null 2>&1; }
svc(){ systemctl list-units | grep -qE '^ssh\.service' && echo ssh || echo sshd; }

log "SSH_PORT: $SSH_PORT | NEW_ADMIN_USER: ${NEW_ADMIN_USER:-<none>} | DISABLE_ROOT_LOGIN: $DISABLE_ROOT_LOGIN | ENABLE_UFW: $ENABLE_UFW"

# 1) Optional: create non-root sudo user
if [[ -n "$NEW_ADMIN_USER" ]]; then
  if id "$NEW_ADMIN_USER" >/dev/null 2>&1; then
    log "User $NEW_ADMIN_USER already exists"
  else
    log "Creating user: $NEW_ADMIN_USER"
    useradd -m -s /bin/bash "$NEW_ADMIN_USER"
    if getent group sudo >/dev/null; then usermod -aG sudo "$NEW_ADMIN_USER"; else usermod -aG wheel "$NEW_ADMIN_USER" || true; fi
    passwd -l "$NEW_ADMIN_USER" || true   # keep locked until key is set
  fi
fi

# 2) UFW basics (Debian/Ubuntu)
if [[ "$ENABLE_UFW" == "yes" ]] && has apt; then
  apt update && apt install -y ufw
  ufw allow "${SSH_PORT}/tcp" || true
  ufw --force enable || true
  ufw status || true
fi

# 3) SSH config hardening (keep current session alive)
SSHD_CFG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.$(date +%Y%m%d-%H%M%S).bak"
cp -a "$SSHD_CFG" "$BACKUP"
log "Backup saved: $BACKUP"

apply(){
  local key="$1" val="$2"
  if grep -Eq "^[# ]*${key}[[:space:]]" "$SSHD_CFG"; then
    sed -i "s|^[# ]*${key}.*|${key} ${val}|g" "$SSHD_CFG"
  else
    printf "\n%s %s\n" "$key" "$val" >> "$SSHD_CFG"
  fi
}

apply "Port" "$SSH_PORT"
apply "Protocol" "2"
apply "PermitRootLogin" "$([[ "$DISABLE_ROOT_LOGIN" == "yes" ]] && echo "no" || echo "prohibit-password")"
apply "PasswordAuthentication" "yes"      # keep for now; switch to 'no' after keys/2FA are tested
apply "ChallengeResponseAuthentication" "yes"  # for future Google Authenticator
apply "UsePAM" "yes"
apply "LoginGraceTime" "30s"
apply "MaxAuthTries" "3"
apply "X11Forwarding" "no"
apply "AllowTcpForwarding" "no"

# 4) Syntax test & safe reload
if has sshd; then
  if sshd -t; then
    systemctl reload "$(svc)" || systemctl restart "$(svc)"
    log "SSH reloaded on port ${SSH_PORT}"
  else
    cp -a "$BACKUP" "$SSHD_CFG"
    log "Invalid sshd_config; restored backup"
    exit 1
  fi
else
  log "sshd binary not found; please validate config manually."
fi

log "SSH hardening done. Test a NEW SSH session before closing this one."