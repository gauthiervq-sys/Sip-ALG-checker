#!/bin/bash
# Complete Asterisk SIP ALG Checker Setup Script
# This script installs all dependencies, clones/updates the repo, sets up monitoring,
# and configures basic integration with Asterisk.

set -e

# Configuration
REPO_URL="https://github.com/gauthiervq-sys/Sip-ALG-checker.git"
INSTALL_DIR="/opt/Sip-ALG-checker"
LOG_DIR="/var/log/asterisk/sip-alg-checker"
CHECK_SCRIPT="/usr/local/bin/asterisk-sip-check.sh"
AGI_SCRIPT="/var/lib/asterisk/agi-bin/check-sip-alg.py"
WAN_IP="193.105.36.4"  # Update this if your WAN IP changes

echo "=== Asterisk SIP ALG Checker - Complete Setup ==="
echo "Repository: $REPO_URL"
echo "Install Directory: $INSTALL_DIR"
echo "Log Directory: $LOG_DIR"
echo "WAN IP: $WAN_IP"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo privileges."
    exit 1
fi

# Update package lists
echo "Updating package lists..."
apt-get update -y

# Install system dependencies
echo "Installing system dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    git \
    jq \
    bc \
    curl \
    net-tools \
    tcpdump \
    mailutils \
    postfix  # For email alerts

# Install Python dependencies
echo "Installing Python dependencies..."

# Function to install pip packages (handles externally-managed-environment)
pip_install() {
    # Check if we're in a virtual environment
    if [ -n "$VIRTUAL_ENV" ] || python3 -c "import sys; exit(0 if sys.prefix != sys.base_prefix else 1)" 2>/dev/null; then
        echo "Virtual environment detected, using pip without additional flags..."
        pip3 install "$@"
    else
        echo "System-wide installation, using --break-system-packages flag..."
        pip3 install --break-system-packages "$@"
    fi
}

pip_install --upgrade pip
pip_install ping3>=4.0.0

# Clone or update repository
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing repository..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Install Python requirements
if [ -f "requirements.txt" ]; then
    pip_install -r requirements.txt
fi

# Make main script executable
chmod +x sip_alg_checker.py

# Create log directory
mkdir -p "$LOG_DIR"
chown asterisk:asterisk "$LOG_DIR" 2>/dev/null || chown root:root "$LOG_DIR"

# Create the monitoring check script
echo "Creating monitoring check script..."
cat > "$CHECK_SCRIPT" << 'EOFSCRIPT'
#!/bin/bash
# Asterisk SIP ALG Checker Script
# Run this periodically via cron

LOG_DIR="/var/log/asterisk/sip-alg-checker"
DATE=$(date +%Y%m%d-%H%M%S)
CHECKER_PATH="/opt/Sip-ALG-checker"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Check local SIP ALG status
cd "$CHECKER_PATH"
python3 sip_alg_checker.py --check-alg > "$LOG_DIR/alg-check-$DATE.log" 2>&1

# Monitor network quality (sample 5 minutes)
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 300 \
  --output "$LOG_DIR/quality-$DATE.json" 2>&1 | tee -a "$LOG_DIR/monitor.log"

# Alert if quality is poor (optional, requires mail setup)
PACKET_LOSS=$(jq -r '.summary.packet_loss_percent // 0' "$LOG_DIR/quality-$DATE.json" 2>/dev/null || echo "0")
JITTER=$(jq -r '.summary.jitter_ms // 0' "$LOG_DIR/quality-$DATE.json" 2>/dev/null || echo "0")

if (( $(echo "$PACKET_LOSS > 1.0" | bc -l) )) || (( $(echo "$JITTER > 30" | bc -l) )); then
    echo "WARNING: Poor network quality detected!" | \
      mail -s "SIP Quality Alert - $(hostname)" root 2>/dev/null || \
      echo "Mail not configured, but alert triggered: Packet Loss $PACKET_LOSS%, Jitter ${JITTER}ms"
fi

# Keep only last 30 days of logs
find "$LOG_DIR" -type f -mtime +30 -delete 2>/dev/null || true

# Log completion
echo "$(date): Check completed" >> "$LOG_DIR/check-completed.log"
EOFSCRIPT

chmod +x "$CHECK_SCRIPT"

# Create AGI script for Asterisk integration (optional)
if [ -d "/var/lib/asterisk/agi-bin" ]; then
    echo "Creating AGI script for Asterisk integration..."
    cat > "$AGI_SCRIPT" << 'EOFAGI'
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
    sys.stdout.write(f'SET VARIABLE SIPALG_STATUS "{results["sip_alg_detected"]}"
')
    sys.stdout.flush()
    sys.stdin.readline()  # Read response
    
    # Log to Asterisk
    if results['sip_alg_detected'] == 'LIKELY':
        sys.stdout.write('VERBOSE "WARNING: SIP ALG likely interfering!" 1
')
        sys.stdout.flush()
        sys.stdin.readline()
    
except Exception as e:
    sys.stdout.write(f'VERBOSE "SIP ALG Check Error: {str(e)}" 1
')
    sys.stdout.flush()

sys.exit(0)
EOFAGI

    chmod +x "$AGI_SCRIPT"
    chown asterisk:asterisk "$AGI_SCRIPT" 2>/dev/null || true
else
    echo "Asterisk AGI directory not found. Skipping AGI script creation."
fi

# Add cron job for periodic monitoring
echo "Adding cron job for periodic monitoring..."
CRON_JOB="0 */6 * * * $CHECK_SCRIPT >/dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v "$CHECK_SCRIPT" || true; echo "$CRON_JOB") | crontab -

# Create basic firewall rules (if ufw is available)
if command_exists ufw; then
    echo "Configuring basic firewall rules..."
    ufw allow 5060/udp comment 'SIP' 2>/dev/null || true
    ufw allow 5060/tcp comment 'SIP' 2>/dev/null || true
    ufw allow 10000:20000/udp comment 'RTP' 2>/dev/null || true
    ufw --force enable 2>/dev/null || true
elif command_exists iptables; then
    echo "Configuring iptables rules..."
    iptables -A INPUT -p udp --dport 5060 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 5060 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p udp --dport 10000:20000 -j ACCEPT 2>/dev/null || true
    # Save rules if netfilter-persistent is available
    if command_exists netfilter-persistent; then
        netfilter-persistent save 2>/dev/null || true
    fi
fi

# Run initial check
echo ""
echo "Running initial checks..."
cd "$INSTALL_DIR"
echo "=== SIP ALG Check ==="
python3 sip_alg_checker.py --check-alg

echo ""
echo "=== Network Quality Check (short) ==="
python3 sip_alg_checker.py --monitor "$WAN_IP" --duration 30 --output "$LOG_DIR/initial-check.json"

# Verify ports
echo ""
echo "=== Port Verification ==="
echo "SIP Port 5060:"
netstat -tulpn | grep :5060 || ss -tulpn | grep :5060 || echo "Port 5060 not found listening"

echo "RTP Ports (sample):"
netstat -tulpn | grep -E ":(1[0-9]{4}|20000)" || ss -tulpn | grep -E ":(1[0-9]{4}|20000)" || echo "No RTP ports found listening"

# Create a simple status dashboard (optional)
DASHBOARD_DIR="/var/www/html/sip-status"
if [ -d "/var/www/html" ]; then
    mkdir -p "$DASHBOARD_DIR"
    cat > "$DASHBOARD_DIR/index.php" << EOFDASH
<?php
\\$log_dir = '$LOG_DIR';
\\$wan_ip = '$WAN_IP';
\\$latest = shell_exec("ls -t \\$log_dir/quality-*.json 2>/dev/null | head -1");
if (\\$latest) {
    \\$data = json_decode(file_get_contents(trim(\\$latest)), true);
} else {
    \\$data = ['summary' => ['packet_loss_percent' => 0, 'jitter_ms' => 0, 'avg_latency_ms' => 0, 'timestamp' => 'No data yet']];
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>SIP ALG Status - <?php echo \\$wan_ip; ?></title>
    <meta http-equiv="refresh" content="300">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .metric { margin: 10px 0; }
        .good { color: green; }
        .fair { color: orange; }
        .poor { color: red; }
    </style>
</head>
<body>
    <h1>SIP Quality Monitor</h1>
    <h2>Server: <?php echo \\$wan_ip; ?></h2>
    <div class="metric">
        <strong>Packet Loss:</strong> 
        <span class="<?php echo \\$data['summary']['packet_loss_percent'] > 1 ? 'poor' : 'good'; ?>">
            <?php echo \\$data['summary']['packet_loss_percent']; ?>%
        </span>
    </div>
    <div class="metric">
        <strong>Jitter:</strong> 
        <span class="<?php echo \\$data['summary']['jitter_ms'] > 30 ? 'poor' : (\\$data['summary']['jitter_ms'] > 20 ? 'fair' : 'good'); ?>">
            <?php echo \\$data['summary']['jitter_ms']; ?>ms
        </span>
    </div>
    <div class="metric">
        <strong>Avg Latency:</strong> 
        <span class="<?php echo \\$data['summary']['avg_latency_ms'] > 150 ? 'poor' : 'good'; ?>">
            <?php echo \\$data['summary']['avg_latency_ms']; ?>ms
        </span>
    </div>
    <p><em>Last updated: <?php echo \\$data['summary']['timestamp']; ?></em></p>
    <p><a href="?refresh=1">Refresh Now</a></p>
</body>
</html>
<?php
if (isset(\\$_GET['refresh'])) {
    shell_exec('$CHECK_SCRIPT');
    header("Location: index.php");
}
?>
EOFDASH
    echo "Status dashboard created at: http://$WAN_IP/sip-status/"
else
    echo "Web server not detected. Skipping dashboard creation."
fi

# Final instructions
echo ""
echo "=== Setup Complete ==="
echo "• SIP ALG Checker installed: $INSTALL_DIR"
echo "• Logs directory: $LOG_DIR"
echo "• Check script: $CHECK_SCRIPT"
echo "• Cron job: Every 6 hours"
echo "• Initial check completed"
if [ -d "/var/lib/asterisk/agi-bin" ]; then
    echo "• AGI script: $AGI_SCRIPT"
fi
echo ""
echo "Next steps:"
echo "1. Review Asterisk configuration files (see ASTERISK_SETUP.md)"
echo "2. Test from client: python3 $INSTALL_DIR/sip_alg_checker.py --monitor $WAN_IP"
echo "3. Check logs: ls -la $LOG_DIR"
echo "4. View status: Browse to http://$WAN_IP/sip-status/ (if web server enabled)"
echo ""
echo "Manual checks:"
echo "• Run full check: $CHECK_SCRIPT"
echo "• Quick ALG check: cd $INSTALL_DIR && python3 sip_alg_checker.py --check-alg"
echo "• Monitor quality: cd $INSTALL_DIR && python3 sip_alg_checker.py --monitor $WAN_IP --duration 300"
echo ""
echo "Troubleshooting:"
echo "• Check cron: crontab -l"
echo "• View logs: tail -f $LOG_DIR/*.log"
echo "• Asterisk logs: tail -f /var/log/asterisk/full"