# Asterisk Integration Guide for SIP ALG Checker

This guide will help you set up the SIP ALG Checker to work with your Asterisk server and detect SIP ALG issues that commonly affect VoIP quality.

## Your Server Details

- **WAN IP**: 193.105.36.4
- **Platform**: Asterisk PBX

## Overview

SIP ALG (Application Layer Gateway) can interfere with Asterisk SIP traffic by:
- Modifying SIP headers incorrectly
- Changing SDP content
- Blocking or corrupting SIP packets
- Causing one-way audio issues
- Breaking SIP registration

## Quick Setup

### 1. Install the SIP ALG Checker

```bash
cd /opt
git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git
cd Sip-ALG-checker
pip install -r requirements.txt
chmod +x sip_alg_checker.py
```

### 2. Run Initial Check

Check if SIP ALG is affecting your server:

```bash
# From your Asterisk server
python3 sip_alg_checker.py --check-alg

# Monitor network quality to your server from a remote client
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 300
```

### 3. Test from Remote Clients

Have your SIP clients (users connecting to your server) run:

```bash
# Check for SIP ALG on their network
python3 sip_alg_checker.py --check-alg

# Monitor connection quality to your Asterisk server
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 300 --output results.json
```

## Asterisk Configuration for Better SIP ALG Detection

### Method 1: Enable SIP OPTIONS Monitoring

Create a script that Asterisk can use to periodically check for SIP ALG issues.

**File**: `/usr/local/bin/asterisk-sip-check.sh`

```bash
#!/bin/bash
# Asterisk SIP ALG Checker Script
# Run this periodically via cron

LOG_DIR="/var/log/asterisk/sip-alg-checker"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y%m%d-%H%M%S)
CHECKER_PATH="/opt/Sip-ALG-checker"

# Check local SIP ALG status
cd "$CHECKER_PATH"
python3 sip_alg_checker.py --check-alg > "$LOG_DIR/alg-check-$DATE.log"

# Monitor network quality (sample 5 minutes)
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 300 \
  --output "$LOG_DIR/quality-$DATE.json"

# Alert if quality is poor
PACKET_LOSS=$(jq -r '.summary.packet_loss_percent' "$LOG_DIR/quality-$DATE.json")
JITTER=$(jq -r '.summary.jitter_ms' "$LOG_DIR/quality-$DATE.json")

if (( $(echo "$PACKET_LOSS > 1.0" | bc -l) )) || (( $(echo "$JITTER > 30" | bc -l) )); then
    echo "WARNING: Poor network quality detected!" | \
      mail -s "SIP Quality Alert - $(hostname)" root
fi

# Keep only last 30 days of logs
find "$LOG_DIR" -type f -mtime +30 -delete
```

Make it executable:

```bash
chmod +x /usr/local/bin/asterisk-sip-check.sh
```

### Method 2: Add Cron Job for Continuous Monitoring

```bash
# Edit crontab
crontab -e

# Add this line to check every 6 hours
0 */6 * * * /usr/local/bin/asterisk-sip-check.sh >/dev/null 2>&1
```

### Method 3: Asterisk AGI Script Integration

Create an AGI script that checks SIP ALG before calls.

**File**: `/var/lib/asterisk/agi-bin/check-sip-alg.py`

```python
#!/usr/bin/env python3
"""
Asterisk AGI Script to check SIP ALG before calls
Usage in dialplan: AGI(check-sip-alg.py)
"""

import sys
import os
import json

# Add the SIP ALG checker to path
sys.path.insert(0, '/opt/Sip-ALG-checker')

try:
    from sip_alg_checker import SIPALGChecker
    
    # AGI environment reading
    env = {}
    while True:
        line = sys.stdin.readline().strip()
        if not line:
            break
        key, value = line.split(':', 1)
        env[key.strip()] = value.strip()
    
    # Check SIP ALG
    checker = SIPALGChecker()
    results = checker.check_sip_alg_via_nat()
    
    # Set Asterisk channel variable with result
    sys.stdout.write(f'SET VARIABLE SIPALG_STATUS "{results["sip_alg_detected"]}"\n')
    sys.stdout.flush()
    sys.stdin.readline()  # Read response
    
    # Log to Asterisk
    if results['sip_alg_detected'] == 'LIKELY':
        sys.stdout.write('VERBOSE "WARNING: SIP ALG likely interfering!" 1\n')
        sys.stdout.flush()
        sys.stdin.readline()
    
except Exception as e:
    sys.stdout.write(f'VERBOSE "SIP ALG Check Error: {str(e)}" 1\n')
    sys.stdout.flush()

sys.exit(0)
```

Make it executable:

```bash
chmod +x /var/lib/asterisk/agi-bin/check-sip-alg.py
chown asterisk:asterisk /var/lib/asterisk/agi-bin/check-sip-alg.py
```

### Method 4: Asterisk Dialplan Integration

Add to your `/etc/asterisk/extensions.conf`:

```ini
[globals]
; SIP ALG Checker settings
SIPALG_CHECKER=/opt/Sip-ALG-checker/sip_alg_checker.py

[macro-check-sip-alg]
; Macro to check SIP ALG status
exten => s,1,NoOp(Checking SIP ALG Status)
 same => n,AGI(check-sip-alg.py)
 same => n,NoOp(SIP ALG Status: ${SIPALG_STATUS})
 same => n,GotoIf($["${SIPALG_STATUS}" = "LIKELY"]?warn:continue)
 same => n(warn),Playback(custom/sip-alg-warning)
 same => n(continue),Return()

[from-internal]
; Example: Check before outbound calls
exten => _X.,1,Macro(check-sip-alg)
 same => n,Dial(SIP/${EXTEN}@trunk)
 same => n,Hangup()
```

## Asterisk SIP Configuration for Better ALG Detection

### pjsip.conf (Asterisk 13+)

```ini
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=193.105.36.4
external_signaling_address=193.105.36.4

[transport-tcp]
type=transport
protocol=tcp
bind=0.0.0.0:5060

[endpoint_template](!)
type=endpoint
context=from-external
disallow=all
allow=ulaw
allow=alaw
allow=g722
direct_media=no
ice_support=yes
force_rport=yes
rewrite_contact=yes
rtp_symmetric=yes
```

### sip.conf (Asterisk 11-13)

```ini
[general]
context=default
bindaddr=0.0.0.0
bindport=5060
externip=193.105.36.4
localnet=192.168.0.0/255.255.0.0
nat=force_rport,comedia
directmedia=no
```

### rtp.conf

```ini
[general]
rtpstart=10000
rtpend=20000
strictrtp=yes
icesupport=yes
```

## Testing Procedure

### Step 1: Server-Side Check

On your Asterisk server (193.105.36.4):

```bash
# Check local SIP ALG status
python3 /opt/Sip-ALG-checker/sip_alg_checker.py --check-alg

# Verify SIP port is accessible
netstat -tulpn | grep 5060

# Check RTP ports
netstat -tulpn | grep -E "1[0-9]{4}"
```

### Step 2: Client-Side Check

From a SIP client location:

```bash
# Check for SIP ALG on client network
python3 sip_alg_checker.py --check-alg

# Test connection quality to server
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 300

# Combined check with export
python3 sip_alg_checker.py --check-alg --monitor 193.105.36.4 \
  --duration 600 --output client-to-server.json
```

### Step 3: Analyze Results

```bash
# View JSON results
cat client-to-server.json | jq .

# Check for issues
jq '.summary | {packet_loss, jitter_ms, avg_latency_ms}' client-to-server.json
```

## Common Issues and Solutions

### Issue 1: SIP ALG Detected as LIKELY

**Solution**: 
1. Access client's router
2. Disable SIP ALG (varies by router brand)
3. Reboot router
4. Test again

### Issue 2: High Jitter (>30ms)

**Solution**:
- Enable QoS on router
- Prioritize SIP/VoIP traffic (UDP ports 5060, 10000-20000)
- Reduce network congestion

### Issue 3: High Packet Loss (>1%)

**Solution**:
- Check internet connection stability
- Test during different times of day
- Consider upgrading internet plan
- Check for local network issues

### Issue 4: One-Way Audio

**Symptoms**: Can hear but not be heard (or vice versa)

**Solution**:
1. Disable SIP ALG
2. Enable `nat=force_rport,comedia` in Asterisk
3. Use `directmedia=no`
4. Configure correct external IP

## Firewall Configuration

Ensure these ports are open on your Asterisk server:

```bash
# UFW (Ubuntu/Debian)
ufw allow 5060/udp comment 'SIP'
ufw allow 5060/tcp comment 'SIP'
ufw allow 10000:20000/udp comment 'RTP'

# iptables
iptables -A INPUT -p udp --dport 5060 -j ACCEPT
iptables -A INPUT -p tcp --dport 5060 -j ACCEPT
iptables -A INPUT -p udp --dport 10000:20000 -j ACCEPT

# Save rules
netfilter-persistent save
```

## Automated Monitoring Dashboard

Create a simple monitoring dashboard:

**File**: `/var/www/html/sip-status/index.php`

```php
<?php
$log_dir = '/var/log/asterisk/sip-alg-checker';
$latest = shell_exec("ls -t $log_dir/quality-*.json | head -1");
$data = json_decode(file_get_contents(trim($latest)), true);
?>
<!DOCTYPE html>
<html>
<head>
    <title>SIP ALG Status - 193.105.36.4</title>
    <meta http-equiv="refresh" content="60">
</head>
<body>
    <h1>SIP Quality Monitor</h1>
    <h2>Server: 193.105.36.4</h2>
    <table border="1">
        <tr><th>Metric</th><th>Value</th><th>Status</th></tr>
        <tr>
            <td>Packet Loss</td>
            <td><?= $data['summary']['packet_loss_percent'] ?>%</td>
            <td><?= $data['summary']['packet_loss_percent'] > 1 ? '❌ POOR' : '✅ OK' ?></td>
        </tr>
        <tr>
            <td>Jitter</td>
            <td><?= $data['summary']['jitter_ms'] ?>ms</td>
            <td><?= $data['summary']['jitter_ms'] > 30 ? '❌ POOR' : '✅ OK' ?></td>
        </tr>
        <tr>
            <td>Avg Latency</td>
            <td><?= $data['summary']['avg_latency_ms'] ?>ms</td>
            <td><?= $data['summary']['avg_latency_ms'] > 150 ? '❌ POOR' : '✅ OK' ?></td>
        </tr>
    </table>
    <p>Last updated: <?= $data['summary']['timestamp'] ?></p>
</body>
</html>
```

## Complete Setup Script

Run this automated setup script on your Asterisk server:

```bash
#!/bin/bash
# Complete Asterisk SIP ALG Checker Setup

set -e

echo "=== Asterisk SIP ALG Checker Setup ==="
echo "Server IP: 193.105.36.4"
echo ""

# Install dependencies
apt-get update
apt-get install -y python3 python3-pip jq bc

# Clone repository
cd /opt
if [ ! -d "Sip-ALG-checker" ]; then
    git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git
fi

cd Sip-ALG-checker
pip3 install -r requirements.txt
chmod +x sip_alg_checker.py

# Create log directory
mkdir -p /var/log/asterisk/sip-alg-checker

# Install check script
cat > /usr/local/bin/asterisk-sip-check.sh << 'EOFSCRIPT'
#!/bin/bash
LOG_DIR="/var/log/asterisk/sip-alg-checker"
mkdir -p "$LOG_DIR"
DATE=$(date +%Y%m%d-%H%M%S)
cd /opt/Sip-ALG-checker
python3 sip_alg_checker.py --check-alg > "$LOG_DIR/alg-check-$DATE.log"
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 300 \
  --output "$LOG_DIR/quality-$DATE.json" 2>&1 | tee -a "$LOG_DIR/monitor.log"
find "$LOG_DIR" -type f -mtime +30 -delete
EOFSCRIPT

chmod +x /usr/local/bin/asterisk-sip-check.sh

# Add cron job
(crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/asterisk-sip-check.sh") | crontab -

# Run initial check
echo ""
echo "Running initial check..."
python3 sip_alg_checker.py --check-alg

echo ""
echo "=== Setup Complete ==="
echo "• Checker installed: /opt/Sip-ALG-checker"
echo "• Logs directory: /var/log/asterisk/sip-alg-checker"
echo "• Cron job: Every 6 hours"
echo "• Manual check: /usr/local/bin/asterisk-sip-check.sh"
echo ""
echo "Next steps:"
echo "1. Configure Asterisk with external IP (see ASTERISK_SETUP.md)"
echo "2. Test from client: python3 sip_alg_checker.py --monitor 193.105.36.4"
echo "3. Review logs: ls -la /var/log/asterisk/sip-alg-checker"
```

## Support and Troubleshooting

### View Logs

```bash
# Check recent SIP ALG checks
ls -lt /var/log/asterisk/sip-alg-checker/

# View latest check
cat $(ls -t /var/log/asterisk/sip-alg-checker/alg-check-*.log | head -1)

# View latest quality report
cat $(ls -t /var/log/asterisk/sip-alg-checker/quality-*.json | head -1) | jq .
```

### Asterisk Logs

```bash
# Check SIP messages
tail -f /var/log/asterisk/full | grep SIP

# Check call quality
asterisk -rx "sip show peers"
asterisk -rx "pjsip show endpoints"
```

### Network Tests

```bash
# Test SIP port from client
nc -vz 193.105.36.4 5060

# Test from server
tcpdump -i any port 5060 -n
```

## Getting Help

If you encounter issues:

1. Run full diagnostic: `python3 sip_alg_checker.py --check-alg --monitor 193.105.36.4 --duration 600 --output diagnostic.json`
2. Check Asterisk logs: `/var/log/asterisk/full`
3. Review SIP ALG checker logs: `/var/log/asterisk/sip-alg-checker/`
4. Share the JSON output for analysis

## References

- [Asterisk NAT Documentation](https://wiki.asterisk.org/wiki/display/AST/NAT)
- [SIP ALG Problems](https://www.voip-info.org/sip-alg/)
- Asterisk Configuration: `/etc/asterisk/`
