#!/bin/bash
# Complete Asterisk SIP ALG Checker Setup Script
# This script installs all dependencies, clones/updates the repo, sets up monitoring,
# and configures basic integration with Asterisk.
#
# USAGE:
#   Download and run as root:
#     sudo curl -o /tmp/all_in_one_setup.sh https://raw.githubusercontent.com/gauthiervq-sys/Sip-ALG-checker/main/all_in_one_setup.sh
#     sudo bash /tmp/all_in_one_setup.sh
#
#   Or if you already have the repository:
#     sudo bash all_in_one_setup.sh

set -e
set -o pipefail

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

# Function to print error messages
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Function to print warning messages
warn() {
    echo "WARNING: $1" >&2
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "ERROR: This script must be run as root or with sudo privileges."
    echo ""
    echo "To download and run this script, use one of these methods:"
    echo ""
    echo "Method 1: Download to /tmp and run:"
    echo "  curl -o /tmp/all_in_one_setup.sh https://raw.githubusercontent.com/gauthiervq-sys/Sip-ALG-checker/main/all_in_one_setup.sh"
    echo "  sudo bash /tmp/all_in_one_setup.sh"
    echo ""
    echo "Method 2: Clone repository and run:"
    echo "  git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git"
    echo "  cd Sip-ALG-checker"
    echo "  sudo bash all_in_one_setup.sh"
    echo ""
    exit 1
fi

# Check if /opt directory exists and is writable
if [ ! -d "/opt" ]; then
    echo "Creating /opt directory..."
    mkdir -p /opt || error_exit "Cannot create /opt directory. Check permissions."
fi

if [ ! -w "/opt" ]; then
    error_exit "/opt directory is not writable. This script needs write access to /opt."
fi

# Check for Asterisk installation and port conflicts
echo "Checking for Asterisk installation..."
ASTERISK_RUNNING=false
PORT_5060_IN_USE=false

if command_exists asterisk; then
    echo "✓ Asterisk is installed"
    
    # Check if Asterisk is running
    if pgrep -x "asterisk" > /dev/null 2>&1; then
        ASTERISK_RUNNING=true
        echo "✓ Asterisk is currently running"
        
        # Check if port 5060 is in use
        if netstat -tulpn 2>/dev/null | grep -q ":5060 " || ss -tulpn 2>/dev/null | grep -q ":5060 "; then
            PORT_5060_IN_USE=true
            echo "✓ Port 5060 is bound (expected for Asterisk)"
        else
            warn "Asterisk is running but port 5060 is not bound. This may indicate a configuration issue."
        fi
    else
        echo "  Asterisk is installed but not currently running"
    fi
else
    warn "Asterisk is not installed. This tool is designed for use with Asterisk PBX."
    echo "  You can still install the SIP ALG checker, but integration features will be limited."
    echo ""
    read -p "Continue without Asterisk? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

# Update package lists
echo ""
echo "Updating package lists..."
if ! apt-get update -y > /dev/null 2>&1; then
    error_exit "Failed to update package lists. Check your internet connection and apt configuration."
fi
echo "✓ Package lists updated"

# Install system dependencies
echo ""
echo "Installing system dependencies..."
REQUIRED_PACKAGES="python3 python3-pip python3-dev git jq bc curl net-tools"
OPTIONAL_PACKAGES="tcpdump mailutils postfix"

echo "  Installing required packages: $REQUIRED_PACKAGES"
if ! apt-get install -y $REQUIRED_PACKAGES > /dev/null 2>&1; then
    error_exit "Failed to install required system dependencies. Check apt configuration."
fi
echo "✓ Required packages installed"

echo "  Installing optional packages (email alerts and packet capture): $OPTIONAL_PACKAGES"
if apt-get install -y $OPTIONAL_PACKAGES > /dev/null 2>&1; then
    echo "✓ Optional packages installed"
else
    warn "Some optional packages could not be installed. Email alerts and tcpdump may not work."
fi

# Install Python dependencies
echo ""
echo "Installing Python dependencies..."
# Note: Skipping pip upgrade as it can cause issues with externally-managed environments
pip3 install --break-system-packages ping3>=4.0.0

# Clone or update repository
echo ""
if [ -d "$INSTALL_DIR" ]; then
    echo "Repository already exists at $INSTALL_DIR"
    echo "Updating existing repository..."
    cd "$INSTALL_DIR" || error_exit "Cannot access $INSTALL_DIR"
    
    if ! git pull > /dev/null 2>&1; then
        warn "Failed to update repository. Continuing with existing version..."
    else
        echo "✓ Repository updated"
    fi
else
    echo "Cloning repository from $REPO_URL..."
    if ! git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null 2>&1; then
        error_exit "Failed to clone repository. Check internet connection and git configuration."
    fi
    echo "✓ Repository cloned to $INSTALL_DIR"
    cd "$INSTALL_DIR" || error_exit "Cannot access $INSTALL_DIR"
fi

# Install Python requirements
echo ""
if [ -f "requirements.txt" ]; then
    pip3 install --break-system-packages -r requirements.txt
fi

# Make main script executable
if [ -f "sip_alg_checker.py" ]; then
    chmod +x sip_alg_checker.py
    echo "✓ Main script made executable"
else
    error_exit "sip_alg_checker.py not found in repository!"
fi

# Create log directory
echo ""
echo "Creating log directory..."
if ! mkdir -p "$LOG_DIR"; then
    error_exit "Failed to create log directory: $LOG_DIR"
fi

# Try to set ownership to asterisk user if available, otherwise use root
if id "asterisk" >/dev/null 2>&1; then
    chown asterisk:asterisk "$LOG_DIR" 2>/dev/null || chown root:root "$LOG_DIR"
    echo "✓ Log directory created and owned by asterisk user"
else
    chown root:root "$LOG_DIR"
    echo "✓ Log directory created (owned by root)"
fi

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
echo ""
if [ "$ASTERISK_RUNNING" = true ] || command_exists asterisk; then
    if [ ! -d "/var/lib/asterisk/agi-bin" ]; then
        echo "Creating AGI directory..."
        mkdir -p /var/lib/asterisk/agi-bin || warn "Failed to create AGI directory"
    fi
    
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
EOFAGI

    chmod +x "$AGI_SCRIPT"
    if id "asterisk" >/dev/null 2>&1; then
        chown asterisk:asterisk "$AGI_SCRIPT" 2>/dev/null || chown root:root "$AGI_SCRIPT"
    fi
    echo "✓ AGI script created at $AGI_SCRIPT"
    else
        warn "AGI directory could not be created. Asterisk integration will be limited."
    fi
else
    echo "Asterisk not detected. Skipping AGI script creation."
    echo "  (Install Asterisk first if you need AGI integration)"
fi

# Add cron job for periodic monitoring
echo ""
echo "Setting up cron job for periodic monitoring (every 6 hours)..."
CRON_JOB="0 */6 * * * $CHECK_SCRIPT >/dev/null 2>&1"

# Remove old cron job if it exists
(crontab -l 2>/dev/null | grep -v "$CHECK_SCRIPT" || true) | crontab - 2>/dev/null || true

# Add new cron job
if (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab - 2>/dev/null; then
    echo "✓ Cron job installed successfully"
else
    warn "Failed to install cron job. You may need to set up monitoring manually."
fi

# Create basic firewall rules (if ufw is available)
echo ""
if command_exists ufw; then
    echo "Configuring UFW firewall rules for SIP and RTP..."
    
    # Check if UFW is active before modifying rules
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    
    if ufw allow 5060/udp comment 'SIP' 2>/dev/null && \
       ufw allow 5060/tcp comment 'SIP' 2>/dev/null && \
       ufw allow 10000:20000/udp comment 'RTP' 2>/dev/null; then
        echo "✓ Firewall rules added for SIP (5060) and RTP (10000-20000)"
    else
        warn "Failed to add some firewall rules. Check UFW configuration."
    fi
    
    # Only enable UFW if it was already enabled or if this is a new setup
    if echo "$UFW_STATUS" | grep -q "Status: active"; then
        echo "✓ UFW is already enabled"
    else
        echo "  Note: UFW rules configured but not enabled automatically"
        echo "  To enable UFW, run: sudo ufw enable"
        echo "  WARNING: Make sure SSH access is allowed before enabling UFW!"
    fi
elif command_exists iptables; then
    echo "Configuring iptables rules for SIP and RTP..."
    
    if iptables -C INPUT -p udp --dport 5060 -j ACCEPT 2>/dev/null || \
       iptables -A INPUT -p udp --dport 5060 -j ACCEPT 2>/dev/null; then
        echo "  ✓ SIP UDP rule added"
    fi
    
    if iptables -C INPUT -p tcp --dport 5060 -j ACCEPT 2>/dev/null || \
       iptables -A INPUT -p tcp --dport 5060 -j ACCEPT 2>/dev/null; then
        echo "  ✓ SIP TCP rule added"
    fi
    
    if iptables -C INPUT -p udp --dport 10000:20000 -j ACCEPT 2>/dev/null || \
       iptables -A INPUT -p udp --dport 10000:20000 -j ACCEPT 2>/dev/null; then
        echo "  ✓ RTP range rule added"
    fi
    
    # Save rules if netfilter-persistent is available
    if command_exists netfilter-persistent; then
        if netfilter-persistent save 2>/dev/null; then
            echo "✓ iptables rules saved"
        else
            warn "Failed to save iptables rules. They may not persist after reboot."
        fi
    else
        warn "netfilter-persistent not found. iptables rules may not persist after reboot."
    fi
else
    warn "No firewall management tool detected (ufw or iptables)."
    echo "  You may need to manually configure firewall rules for:"
    echo "  - SIP: ports 5060 (TCP/UDP)"
    echo "  - RTP: ports 10000-20000 (UDP)"
fi

# Run initial check
echo ""
echo "=== Running Initial Checks ==="
cd "$INSTALL_DIR" || error_exit "Cannot access installation directory"

echo ""
echo "1. SIP ALG Check:"
if python3 sip_alg_checker.py --check-alg 2>&1; then
    echo "✓ SIP ALG check completed"
else
    warn "SIP ALG check encountered errors. Check the output above for details."
fi

echo ""
echo "2. Network Quality Check (30 second sample):"
if python3 sip_alg_checker.py --monitor "$WAN_IP" --duration 30 --output "$LOG_DIR/initial-check.json" 2>&1; then
    echo "✓ Network quality check completed"
    echo "  Results saved to: $LOG_DIR/initial-check.json"
else
    warn "Network quality check failed. This may be normal if the target host is not reachable."
fi

# Verify ports
echo ""
echo "=== Port Verification ==="
echo ""
echo "Checking SIP Port 5060:"
if netstat -tulpn 2>/dev/null | grep -q ":5060 " || ss -tulpn 2>/dev/null | grep -q ":5060 "; then
    echo "✓ Port 5060 is listening"
    netstat -tulpn 2>/dev/null | grep ":5060 " || ss -tulpn 2>/dev/null | grep ":5060 "
    
    if [ "$PORT_5060_IN_USE" = true ]; then
        echo "  (Port is bound by Asterisk as expected)"
    fi
else
    if [ "$ASTERISK_RUNNING" = true ]; then
        warn "Asterisk is running but port 5060 is not listening!"
        echo "  This may indicate a configuration problem. Check Asterisk's SIP/PJSIP configuration."
    else
        echo "  Port 5060 is not listening (normal if Asterisk is not running)"
    fi
fi

echo ""
echo "Checking RTP Ports (sample):"
if netstat -tulpn 2>/dev/null | grep -qE ":(1[0-9]{4}|20000)" || ss -tulpn 2>/dev/null | grep -qE ":(1[0-9]{4}|20000)"; then
    echo "✓ Some RTP ports are listening"
    netstat -tulpn 2>/dev/null | grep -E ":(1[0-9]{4}|20000)" | head -5 || \
    ss -tulpn 2>/dev/null | grep -E ":(1[0-9]{4}|20000)" | head -5
else
    echo "  No RTP ports currently listening (normal when no active calls)"
fi

# Create a simple status dashboard (optional)
echo ""
DASHBOARD_DIR="/var/www/html/sip-status"
if [ -d "/var/www/html" ]; then
    echo "Creating web status dashboard..."
    if mkdir -p "$DASHBOARD_DIR" 2>/dev/null; then
        cat > "$DASHBOARD_DIR/index.php" << EOFDASH
<?php
\$log_dir = '$LOG_DIR';
\$wan_ip = '$WAN_IP';
\$latest = shell_exec("ls -t \$log_dir/quality-*.json 2>/dev/null | head -1");
if (\$latest) {
    \$data = json_decode(file_get_contents(trim(\$latest)), true);
} else {
    \$data = ['summary' => ['packet_loss_percent' => 0, 'jitter_ms' => 0, 'avg_latency_ms' => 0, 'timestamp' => 'No data yet']];
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>SIP ALG Status - <?php echo \$wan_ip; ?></title>
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
    <h2>Server: <?php echo \$wan_ip; ?></h2>
    <div class="metric">
        <strong>Packet Loss:</strong> 
        <span class="<?php echo \$data['summary']['packet_loss_percent'] > 1 ? 'poor' : 'good'; ?>">
            <?php echo \$data['summary']['packet_loss_percent']; ?>%
        </span>
    </div>
    <div class="metric">
        <strong>Jitter:</strong> 
        <span class="<?php echo \$data['summary']['jitter_ms'] > 30 ? 'poor' : (\$data['summary']['jitter_ms'] > 20 ? 'fair' : 'good'); ?>">
            <?php echo \$data['summary']['jitter_ms']; ?>ms
        </span>
    </div>
    <div class="metric">
        <strong>Avg Latency:</strong> 
        <span class="<?php echo \$data['summary']['avg_latency_ms'] > 150 ? 'poor' : 'good'; ?>">
            <?php echo \$data['summary']['avg_latency_ms']; ?>ms
        </span>
    </div>
    <p><em>Last updated: <?php echo \$data['summary']['timestamp']; ?></em></p>
    <p><a href="?refresh=1">Refresh Now</a></p>
</body>
</html>
<?php
if (isset(\$_GET['refresh'])) {
    shell_exec('$CHECK_SCRIPT');
    header("Location: index.php");
}
?>
EOFDASH
        echo "✓ Status dashboard created at: http://$WAN_IP/sip-status/"
    else
        warn "Failed to create dashboard directory. Check web server permissions."
    fi
else
    echo "Web server directory not found (/var/www/html)."
    echo "  Skipping dashboard creation. Install Apache/Nginx if you want the web dashboard."
fi

# Final instructions
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                    ✓ Setup Complete!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📁 Installation Summary:"
echo "   • SIP ALG Checker: $INSTALL_DIR"
echo "   • Logs directory: $LOG_DIR"
echo "   • Check script: $CHECK_SCRIPT"
echo "   • Cron job: Every 6 hours (0 */6 * * *)"
if [ -f "$AGI_SCRIPT" ]; then
    echo "   • AGI script: $AGI_SCRIPT (for Asterisk integration)"
fi
echo ""

if [ "$ASTERISK_RUNNING" = true ]; then
    echo "✓ Asterisk Status: Running"
    if [ "$PORT_5060_IN_USE" = true ]; then
        echo "✓ Port 5060: Bound and ready"
    else
        echo "⚠ Port 5060: Not bound (check Asterisk configuration)"
    fi
elif command_exists asterisk; then
    echo "  Asterisk Status: Installed but not running"
    echo "  To start Asterisk: systemctl start asterisk"
else
    echo "  Asterisk: Not installed (limited integration features)"
fi

echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Configure Asterisk (if installed):"
echo "   • Review: cat $INSTALL_DIR/ASTERISK_SETUP.md"
echo "   • Update external IP in /etc/asterisk/pjsip.conf or sip.conf"
echo "   • Set external_media_address=$WAN_IP"
echo "   • Reload: asterisk -rx 'core reload'"
echo ""
echo "2. Test from a remote client:"
echo "   python3 $INSTALL_DIR/sip_alg_checker.py --monitor $WAN_IP --duration 60"
echo ""
echo "3. Review logs:"
echo "   ls -la $LOG_DIR"
echo "   tail -f $LOG_DIR/monitor.log"
echo ""
if [ -d "/var/www/html/sip-status" ]; then
echo "4. View web dashboard:"
echo "   http://$WAN_IP/sip-status/"
echo ""
fi

echo "🔧 Manual Commands:"
echo "   • Run check now:    $CHECK_SCRIPT"
echo "   • Quick ALG check:  cd $INSTALL_DIR && python3 sip_alg_checker.py --check-alg"
echo "   • Monitor quality:  cd $INSTALL_DIR && python3 sip_alg_checker.py --monitor $WAN_IP --duration 300"
echo "   • View cron jobs:   crontab -l"
echo ""
echo "📚 Documentation:"
echo "   • Full guide:       $INSTALL_DIR/ASTERISK_SETUP.md"
echo "   • Security:         $INSTALL_DIR/SECURITY.md"
echo "   • Quick start:      $INSTALL_DIR/QUICK_START.md"
echo ""
echo "❓ Troubleshooting:"
echo "   • View logs:        tail -f $LOG_DIR/*.log"
if command_exists asterisk; then
echo "   • Asterisk logs:    tail -f /var/log/asterisk/full"
echo "   • Check Asterisk:   asterisk -rvvv"
fi
echo "   • Port check:       netstat -tulpn | grep 5060"
echo "   • Firewall check:   sudo ufw status verbose"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""