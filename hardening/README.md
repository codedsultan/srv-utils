# hardening

System hardening scripts focused on SSH security and firewall configuration.

## Scripts

### ssh-hardening.sh

Comprehensive SSH hardening script that secures SSH access and optionally configures UFW firewall.

**Features:**
- Optional non-root sudo user creation
- SSH configuration hardening with safe backup/reload
- UFW firewall setup (Debian/Ubuntu)
- Automatic configuration validation
- Safe rollback on configuration errors

**Environment Variables:**

```bash
NEW_ADMIN_USER="myadmin"                   # Optional: Create new sudo user
SSH_PORT="22"                              # SSH port number
DISABLE_ROOT_LOGIN="yes"                   # yes|no - Disable direct root SSH login
ENABLE_UFW="yes"                           # yes|no - Enable UFW firewall
```

**Usage:**

```bash
# Set environment variables
export NEW_ADMIN_USER="myadmin"
export SSH_PORT="22"
export DISABLE_ROOT_LOGIN="yes"
export ENABLE_UFW="yes"

# Run via curl (one-liner)
sudo -E bash -c 'bash <(curl -fsSL https://raw.githubusercontent.com/codedsultan/srv-utils/main/hardening/ssh-hardening.sh)'

# Or via Makefile (after setting .local/ssh.env)
make deploy-ssh-hardening
```

## Security Enhancements

### SSH Configuration
The script applies these SSH hardening measures:

- **Protocol**: SSH Protocol 2 only
- **Authentication**: Public key authentication preferred
- **Root Login**: Configurable disable (recommended)
- **Empty Passwords**: Disabled
- **X11 Forwarding**: Disabled
- **Port Configuration**: Customizable (default 22)
- **Login Grace Time**: Reduced timeout
- **Max Auth Tries**: Limited attempts

### User Management
When `NEW_ADMIN_USER` is specified:
- Creates new user account
- Adds user to sudo group
- Sets up proper home directory permissions
- Configures SSH access for the new user

### Firewall (UFW)
When `ENABLE_UFW="yes"`:
- Installs UFW if not present
- Configures default deny incoming/allow outgoing
- Opens SSH port (specified in `SSH_PORT`)
- Enables firewall with proper rules

## Safety Features

- **Configuration Backup**: Creates timestamped backup of `sshd_config`
- **Syntax Validation**: Tests SSH config before applying (`sshd -t`)
- **Safe Reload**: Only reloads SSH service if configuration is valid
- **Session Protection**: Warnings to keep current session open
- **Rollback Support**: Backup files allow manual rollback if needed

## Verification

After running the script:

```bash
# Check SSH service status
sudo systemctl status ssh

# Verify SSH configuration
sudo sshd -t

# Check UFW status (if enabled)
sudo ufw status

# Test new user access (if created)
su - myadmin
```

## Important Notes

- **Keep SSH Session Open**: Always maintain an active SSH session while applying changes
- **Test Before Disconnect**: Verify new SSH settings work before closing your session
- **User Creation**: If creating a new admin user, ensure you can authenticate as that user
- **Firewall Rules**: UFW rules are basic - customize for your specific needs
- **Service Names**: RHEL systems may use `sshd` service name instead of `ssh`