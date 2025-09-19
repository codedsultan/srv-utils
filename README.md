# srv-utils 🛡️

Utility scripts for server hardening, security, and monitoring. Supports Debian/Ubuntu (and best-effort RHEL). Scripts are idempotent and environment-driven.

> ⚠️ **Important Note**: This project is not production ready. Please review all scripts thoroughly before considering any use in production environments.

## 📦 Structure

```
srv-utils/
├── .gitignore
├── Makefile
├── security/      # Fail2Ban & security utilities
├── hardening/     # SSH hardening, firewall basics
└── monitoring/    # Slack/email alerts + health checks
```

You'll also use two ignored folders locally:
- `.local/` → per-host env files (secrets)
- `private/` → your "private repo" workspace (phase scripts, CP, users, etc.)

## 🚀 Quick Start

```bash
git clone git@github.com:codedsultan/srv-utils.git
cd srv-utils

# Create per-host config (ignored)
mkdir -p .local
cat > .local/config.mk <<'MK'
VPS := root@YOUR.VPS.IP
SSH_PORT := 22
REMOTE_BASE := /root/.srv-utils
MK

# (Optional) envs for public deploy targets
cp examples/fail2ban.env.example .local/fail2ban.env
cp examples/ssh.env.example      .local/ssh.env
cp examples/vps-setup.env.example .local/vps-setup.env

# Push local envs to server
make push-local
```

Run something immediately:
```bash
# Deploy Fail2Ban public script (reads .local/fail2ban.env)
make deploy-fail2ban

# Install monitoring (Slack optional)
make deploy-health-check
```

## 🧭 Phased Server Preparation (safe, no lockout)

Phases live under `private/vps-prep/` (ignored). You'll stage them locally and run via `make`.

- Phase 1: users & SSH keys (verify login)
- Phase 2: 2FA, SSH harden, firewall, Fail2Ban
- Phase 3: monitoring & final verification

```bash
# After you add private/vps-prep/* scripts locally:
make prepare-vps-phase1    # STOP and test login in new terminal
make prepare-vps-phase2    # STOP after 2FA; verify OTP in new terminal
make prepare-vps-phase3    # Monitoring + final audit
```

Run a single phase script:
```bash
make run-script SCRIPT=vps-prep/06-harden-ssh.sh
```

## 🛠️ Makefile Cheatsheet

```bash
make print-config               # Show current settings
make test-ssh                   # Verify connectivity

make push-local                 # Sync .local/ -> server
make push-private               # Sync private/ -> server

make deploy-fail2ban            # Run public Fail2Ban (uses .local/fail2ban.env)
make deploy-ssh-hardening       # Run public SSH hardening (uses .local/ssh.env)
make deploy-health-check        # Install monitoring

make run-private SCRIPT=users/setup-ssh
make run-remote  CMD='uname -a'
make curl-run    PATH=security/fail2ban-setup.sh
```

## 🔐 Environment Files (examples)

See `examples/` (copy to `.local/` and edit):
- `fail2ban.env.example`
- `ssh.env.example`
- `vps-setup.env.example`

## 🧯 Safety Notes

- Keep 2 SSH sessions open during changes.
- Test SSH config before reload: `sshd -t`
- Prefer `systemctl reload ssh` (or `sshd`) over restart.
- CP needs port 8443 open (add to `ALLOWED_PORTS`).

## 📜 License

MIT - review scripts before running in production.

## 👨‍💻 Credits

Created with ❤️ by [codedsultan](https://github.com/codedsultan)

If you found this project helpful, consider supporting my work:

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/codesultan)

---

**Note**: Before running any scripts, make sure to:
```bash
chmod +x ./security/fail2ban-setup.sh
chmod +x ./hardening/ssh-hardening.sh
chmod +x ./monitoring/alerts-setup.sh
```