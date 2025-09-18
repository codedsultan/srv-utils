# monitoring

Lightweight monitoring and alerting system for server health checks.

## Scripts

### alerts-setup.sh

Sets up a comprehensive monitoring system with Slack notifications and email alerts for server health metrics.

**Features:**
- Installs `/usr/local/bin/notify` utility (Slack + local mail)
- Adds `/usr/local/bin/srv-health-check` for disk and load monitoring
- Configures automatic daily health checks via cron (09:00)
- Customizable thresholds for disk usage and system load
- Cross-platform notification support

**Environment Variables (Optional):**

```bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"  # Optional: Slack webhook
DISK_THRESHOLD="85"                                               # Disk usage alert threshold (%)
LOAD_THRESHOLD="4.00"                                            # System load alert threshold
```

**Usage:**

```bash
# Basic setup (email only)
sudo -E bash -c 'bash <(curl -fsSL https://raw.githubusercontent.com/codedsultan/srv-utils/main/monitoring/alerts-setup.sh)'

# With Slack integration
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"
export DISK_THRESHOLD="85"
export LOAD_THRESHOLD="4.00"
sudo -E bash -c 'bash <(curl -fsSL https://raw.githubusercontent.com/codedsultan/srv-utils/main/monitoring/alerts-setup.sh)'

# Or via Makefile
make deploy-health-check
```

## Installed Components

### `/usr/local/bin/notify`
Universal notification utility that supports:
- **Slack notifications**: Via webhook URL if configured
- **Local email**: Using system's sendmail/postfix
- **Fallback logging**: Writes to syslog if other methods fail

Usage:
```bash
# Send notification
/usr/local/bin/notify "Alert title" "Detailed message"

# Examples
notify "Disk Alert" "Root partition is 90% full"
notify "Load Alert" "System load average: 8.45"
```

### `/usr/local/bin/srv-health-check`
Automated health monitoring script that checks:
- **Disk Usage**: All mounted filesystems
- **System Load**: 1-minute load average
- **Memory Usage**: Available memory status
- **Service Status**: Critical system services

**Default Thresholds:**
- Disk usage: 85%
- Load average: 4.00
- Memory: Warns when less than 10% available

### Cron Schedule
Automatic daily health check scheduled at 09:00:
```bash
0 9 * * * /usr/local/bin/srv-health-check
```

## Customization

### Modifying Thresholds
Edit the configuration in `/usr/local/bin/srv-health-check`:

```bash
# Edit thresholds
sudo nano /usr/local/bin/srv-health-check

# Common modifications:
DISK_THRESHOLD=90        # Increase disk threshold to 90%
LOAD_THRESHOLD=2.00      # Lower load threshold to 2.00
MEMORY_THRESHOLD=5       # Alert when less than 5% memory available
```

### Adding Custom Checks
Extend `/usr/local/bin/srv-health-check` with additional monitoring:

```bash
# Example: Check specific service
if ! systemctl is-active --quiet nginx; then
    notify "Service Alert" "Nginx service is not running on $(hostname)"
fi

# Example: Check log file size
LOG_SIZE=$(du -m /var/log/nginx/error.log | cut -f1)
if [ "$LOG_SIZE" -gt 100 ]; then
    notify "Log Alert" "Nginx error log is ${LOG_SIZE}MB on $(hostname)"
fi
```

### Changing Schedule
Modify the cron schedule:

```bash
# Edit cron for root user
sudo crontab -e

# Examples:
# Every hour: 0 * * * * /usr/local/bin/srv-health-check
# Every 6 hours: 0 */6 * * * /usr/local/bin/srv-health-check
# Twice daily: 0 9,21 * * * /usr/local/bin/srv-health-check
```

## Slack Integration

### Webhook Setup
1. Go to your Slack workspace settings
2. Navigate to Apps → Incoming Webhooks
3. Create a new webhook for your desired channel
4. Copy the webhook URL

### Message Format
Slack notifications include:
- 🚨 Alert emoji for critical issues
- Server hostname identification  
- Detailed metric information
- Timestamp of the alert

## Testing

### Manual Health Check
```bash
# Run immediate health check
sudo /usr/local/bin/srv-health-check

# Test notification system
sudo /usr/local/bin/notify "Test Alert" "This is a test notification from $(hostname)"
```

### Verify Cron Setup
```bash
# Check cron is installed and running
sudo systemctl status cron

# List active crontab
sudo crontab -l

# Check cron logs
sudo journalctl -u cron -f
```

## Troubleshooting

### Email Issues
- Ensure `sendmail` or `postfix` is installed and configured
- Check `/var/log/mail.log` for delivery issues
- Verify server can send outbound email (port 25/587)

### Slack Issues
- Validate webhook URL format
- Test webhook manually with curl
- Check network connectivity to Slack (hooks.slack.com)

### Permission Issues
- Ensure scripts are executable: `chmod +x /usr/local/bin/*`
- Verify cron has appropriate permissions
- Check that the monitoring user can read system metrics