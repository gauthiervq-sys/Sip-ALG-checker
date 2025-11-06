# Setup Completion Guide

This guide helps you complete the SIP ALG Checker setup after manually executing initial setup steps.

## Overview

If you've already:
- Cloned the repository
- Created the log directory (optional)
- Created the monitoring script (optional)

Then use the `complete_setup.sh` script to finish the remaining setup tasks.

## What the Script Does

The completion script handles:

1. **Verification**: Checks that the repository exists
2. **Log Directory**: Creates `/var/log/asterisk/sip-alg-checker` if it doesn't exist
3. **Monitoring Script**: Creates `/usr/local/bin/asterisk-sip-check.sh` for periodic checks
4. **Cron Job**: Adds automatic monitoring every 6 hours
5. **Initial Checks**: Runs SIP ALG and network quality checks
6. **Optional AGI Script**: Creates Asterisk integration script (interactive)
7. **Optional Firewall**: Configures firewall rules for SIP/RTP (interactive)
8. **Optional Dashboard**: Sets up a web dashboard for monitoring (interactive)

## Quick Start

### Step 1: Navigate to Repository

```bash
cd /opt/Sip-ALG-checker
```

### Step 2: Run Completion Script

```bash
sudo bash complete_setup.sh
```

### Step 3: Answer Prompts

The script will ask you about optional components:
- **AGI Script**: Type `y` if you have Asterisk and want dialplan integration
- **Firewall Rules**: Type `y` to configure SIP/RTP ports automatically
- **Web Dashboard**: Type `y` if you have a web server and want a status page

## Detailed Steps

### Prerequisites

- Root/sudo access
- Repository cloned to `/opt/Sip-ALG-checker`
- Python 3 installed
- Required Python packages installed

### What Gets Created

#### 1. Log Directory
```
/var/log/asterisk/sip-alg-checker/
├── alg-check-YYYYMMDD-HHMMSS.log
├── quality-YYYYMMDD-HHMMSS.json
├── monitor.log
└── check-completed.log
```

#### 2. Monitoring Script
```bash
/usr/local/bin/asterisk-sip-check.sh
```
This script:
- Checks for SIP ALG interference
- Monitors network quality (5-minute sample)
- Logs results to the log directory
- Alerts on poor quality (if mail is configured)
- Cleans up old logs (keeps 30 days)

#### 3. Cron Job
```
0 */6 * * * /usr/local/bin/asterisk-sip-check.sh
```
Runs automatically every 6 hours.

#### 4. AGI Script (Optional)
```bash
/var/lib/asterisk/agi-bin/check-sip-alg.py
```
Allows checking SIP ALG status from your Asterisk dialplan.

**Dialplan Integration:**
```
[macro-check-sip-alg]
exten => s,1,NoOp(Checking SIP ALG)
 same => n,AGI(check-sip-alg.py)
 same => n,NoOp(Status: ${SIPALG_STATUS})
 same => n,Return()
```

#### 5. Firewall Rules (Optional)
- Port 5060 (TCP/UDP) for SIP signaling
- Ports 10000-20000 (UDP) for RTP media

#### 6. Web Dashboard (Optional)
```
http://YOUR_IP/sip-status/
```
Shows real-time network quality metrics.

## Configuration

### Changing the WAN IP

Edit the script and modify this line:
```bash
WAN_IP="193.105.36.4"  # Update this if your WAN IP is different
```

Or edit the monitoring script after installation:
```bash
sudo nano /usr/local/bin/asterisk-sip-check.sh
```

### Changing Monitoring Frequency

The default cron job runs every 6 hours. To change:

```bash
# Edit crontab
crontab -e

# Change this line:
0 */6 * * * /usr/local/bin/asterisk-sip-check.sh

# Examples:
# Every 2 hours: 0 */2 * * *
# Every hour: 0 * * * *
# Every 30 minutes: */30 * * * *
# Daily at 2 AM: 0 2 * * *
```

### Adjusting Monitoring Duration

Edit the monitoring script:
```bash
sudo nano /usr/local/bin/asterisk-sip-check.sh
```

Change the `--duration` parameter (in seconds):
```bash
# Default: 5 minutes (300 seconds)
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 300

# Examples:
# 2 minutes: --duration 120
# 10 minutes: --duration 600
# 1 hour: --duration 3600
```

## Usage

### Run Manual Check

```bash
sudo /usr/local/bin/asterisk-sip-check.sh
```

### View Logs

```bash
# List all logs
ls -lh /var/log/asterisk/sip-alg-checker/

# View monitoring log
tail -f /var/log/asterisk/sip-alg-checker/monitor.log

# View latest ALG check
ls -t /var/log/asterisk/sip-alg-checker/alg-check-*.log | head -1 | xargs cat

# View latest quality check
ls -t /var/log/asterisk/sip-alg-checker/quality-*.json | head -1 | xargs cat
```

### Check Cron Job

```bash
# View cron jobs
crontab -l

# Check cron logs
grep CRON /var/log/syslog | grep asterisk-sip-check
```

### Test Components Individually

```bash
# Test SIP ALG check
cd /opt/Sip-ALG-checker
python3 sip_alg_checker.py --check-alg

# Test network quality monitoring
python3 sip_alg_checker.py --monitor YOUR_IP --duration 60

# Test AGI script (if installed)
python3 /var/lib/asterisk/agi-bin/check-sip-alg.py
```

## Troubleshooting

### Script Won't Run

**Problem**: Permission denied
```bash
# Solution: Make executable
chmod +x complete_setup.sh
sudo bash complete_setup.sh
```

### Repository Not Found

**Problem**: Repository directory doesn't exist
```bash
# Solution: Clone repository first
sudo mkdir -p /opt
cd /opt
sudo git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git
cd Sip-ALG-checker
sudo bash complete_setup.sh
```

### Cron Job Not Running

**Problem**: Monitoring not happening automatically
```bash
# Check if cron job exists
crontab -l | grep asterisk-sip-check

# Check cron service
systemctl status cron

# Manually test the script
sudo /usr/local/bin/asterisk-sip-check.sh

# Check for errors
tail -f /var/log/syslog | grep CRON
```

### Log Directory Permission Issues

**Problem**: Can't write to log directory
```bash
# Fix permissions
sudo chown -R asterisk:asterisk /var/log/asterisk/sip-alg-checker/
sudo chmod 755 /var/log/asterisk/sip-alg-checker/

# Or use root if asterisk user doesn't exist
sudo chown -R root:root /var/log/asterisk/sip-alg-checker/
```

### AGI Script Not Working

**Problem**: Asterisk can't execute AGI script
```bash
# Check if directory exists
ls -la /var/lib/asterisk/agi-bin/

# Check script permissions
ls -la /var/lib/asterisk/agi-bin/check-sip-alg.py

# Fix permissions
sudo chmod +x /var/lib/asterisk/agi-bin/check-sip-alg.py
sudo chown asterisk:asterisk /var/lib/asterisk/agi-bin/check-sip-alg.py

# Test from Asterisk CLI
asterisk -rvvv
AGI SET DEBUG ON
```

### Firewall Blocks Everything

**Problem**: Can't connect after firewall configuration
```bash
# Check firewall status
sudo ufw status verbose

# Allow SSH if locked out (use console/physical access)
sudo ufw allow 22/tcp

# Disable firewall temporarily
sudo ufw disable

# Re-enable with proper rules
sudo ufw enable
```

### Web Dashboard Not Working

**Problem**: Dashboard shows blank page or errors
```bash
# Check if web server is installed
dpkg -l | grep -E 'apache2|nginx'

# Install Apache and PHP if needed
sudo apt-get install apache2 php libapache2-mod-php

# Check dashboard exists
ls -la /var/www/html/sip-status/

# Check permissions
sudo chown -R www-data:www-data /var/www/html/sip-status/

# Check web server is running
systemctl status apache2
# or
systemctl status nginx

# View error logs
tail -f /var/log/apache2/error.log
# or
tail -f /var/log/nginx/error.log
```

### Python Dependencies Missing

**Problem**: Script fails with import errors
```bash
# Install dependencies
cd /opt/Sip-ALG-checker
sudo pip3 install -r requirements.txt

# Install specific packages
sudo pip3 install ping3
```

## Manual Installation (Alternative)

If you prefer to execute steps manually instead of using the script:

### 1. Create Log Directory
```bash
sudo mkdir -p /var/log/asterisk/sip-alg-checker
sudo chown asterisk:asterisk /var/log/asterisk/sip-alg-checker
```

### 2. Create Monitoring Script
```bash
sudo nano /usr/local/bin/asterisk-sip-check.sh
```
Copy the contents from lines 54-116 of `complete_setup.sh`.

```bash
sudo chmod +x /usr/local/bin/asterisk-sip-check.sh
```

### 3. Add Cron Job
```bash
crontab -e
```
Add this line:
```
0 */6 * * * /usr/local/bin/asterisk-sip-check.sh >/dev/null 2>&1
```

### 4. Run Initial Check
```bash
cd /opt/Sip-ALG-checker
python3 sip_alg_checker.py --check-alg
python3 sip_alg_checker.py --monitor YOUR_IP --duration 30
```

## Verification

After completion, verify everything is working:

### 1. Check File Structure
```bash
# Repository
ls -la /opt/Sip-ALG-checker/

# Logs
ls -la /var/log/asterisk/sip-alg-checker/

# Scripts
ls -la /usr/local/bin/asterisk-sip-check.sh
ls -la /var/lib/asterisk/agi-bin/check-sip-alg.py  # if created
```

### 2. Verify Cron Job
```bash
crontab -l
```

### 3. Test Manual Execution
```bash
sudo /usr/local/bin/asterisk-sip-check.sh
```

### 4. Check Logs Were Created
```bash
ls -la /var/log/asterisk/sip-alg-checker/
```

## Next Steps

After completing the setup:

1. **Monitor Logs**: Check logs regularly to establish baseline quality
   ```bash
   tail -f /var/log/asterisk/sip-alg-checker/monitor.log
   ```

2. **Integrate with Asterisk**: If you created the AGI script, add it to your dialplan

3. **Configure Alerts**: Set up email alerts for quality issues by configuring `mailutils`

4. **Review Documentation**: Read the full guides for detailed configuration
   - `/opt/Sip-ALG-checker/ASTERISK_SETUP.md`
   - `/opt/Sip-ALG-checker/SECURITY.md`

5. **Test from Clients**: Run the checker from client machines to test connectivity
   ```bash
   python3 sip_alg_checker.py --monitor YOUR_SERVER_IP --duration 60
   ```

## Support

For more information, see:
- Main README: `/opt/Sip-ALG-checker/README.md`
- Asterisk Setup: `/opt/Sip-ALG-checker/ASTERISK_SETUP.md`
- Security Guide: `/opt/Sip-ALG-checker/SECURITY.md`
- Quick Start: `/opt/Sip-ALG-checker/QUICK_START.md`

## Cleanup

If you need to remove the setup:

```bash
# Remove cron job
crontab -l | grep -v asterisk-sip-check.sh | crontab -

# Remove monitoring script
sudo rm /usr/local/bin/asterisk-sip-check.sh

# Remove AGI script (optional)
sudo rm /var/lib/asterisk/agi-bin/check-sip-alg.py

# Remove logs (if desired)
sudo rm -rf /var/log/asterisk/sip-alg-checker/

# Remove web dashboard (if created)
sudo rm -rf /var/www/html/sip-status/
```

The repository itself (`/opt/Sip-ALG-checker`) is preserved for future use.
