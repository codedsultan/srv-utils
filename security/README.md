# security

Security-focused scripts for server protection and intrusion detection.

## Scripts

### fail2ban-setup.sh

Installs and configures Fail2Ban for SSH protection with email and optional Slack notifications.

**Features:**
- Installs Fail2Ban with SSH jail configuration
- Email alerts on bans (requires `FAIL2BAN_EMAIL`)
- Optional Slack webhook notifications
- Optional whitelist for current SSH client IP
- Cross-platform support (Debian/Ubuntu/RHEL)

**Environment Variables:**

```bash
FAIL2BAN_EMAIL="you@example.com"           # Required: Email for ban notifications
SSH_PORT="22"                              # Required: SSH port number
SERVER_HOSTNAME="$(hostname -f)"           # Server hostname for notifications
WHITELIST_MYIP="no"                        # Set "yes" to whitelist current SSH client IP
SLACK_WEBHOOK_URL=""                       # Optional: Slack webhook for notifications
```

**Usage:**

```bash
# Set environment variables
export FAIL2BAN_EMAIL="you@example.com"
export SSH_PORT="22"

# Run via curl (one-liner)
sudo -E bash -c 'bash <(curl -fsSL https://raw.githubusercontent.com/codedsultan/srv-utils/main/security/fail2ban-setup.sh)'

# Or via Makefile (after setting .local/fail2ban.env)
make deploy-fail2ban
```

**Verification:**

```bash
# Test configuration
sudo fail2ban-client -t

# Check status
sudo fail2ban-client status
sudo fail2ban-client status sshd

# View logs
sudo journalctl -u fail2ban -f
```

## Configuration Details

### Default Settings
- **Ban time**: 3600 seconds (1 hour) for general, 7200 seconds (2 hours) for SSH
- **Find time**: 600 seconds (10 minutes) for general, 300 seconds (5 minutes) for SSH  
- **Max retry**: 3 attempts before ban
- **Ignored IPs**: 127.0.0.1/8, ::1, and optionally current SSH client

### Slack Integration
If `SLACK_WEBHOOK_URL` is provided, the script creates a custom Slack action that sends:
- 🛡️ Service start/stop notifications
- 🚨 Ban notifications with IP, service, and timestamp
- ✅ Unban notifications

## Safety Notes

- Keep at least one SSH session open while configuring
- Test the configuration before applying: `sudo fail2ban-client -t`
- The whitelist feature (`WHITELIST_MYIP=yes`) should be used cautiously on dynamic IP connections