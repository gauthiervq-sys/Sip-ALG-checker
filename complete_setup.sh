#!/bin/bash
# Setup Completion Script for SIP ALG Checker
# Use this script to complete the setup after manually running initial setup steps
# 
# This script handles:
# 1. Creating log directory (if not exists)
# 2. Creating monitoring script (if not exists)
# 3. Adding cron job for periodic monitoring
# 4. Running initial SIP ALG and network quality checks
# 5. Optionally creating AGI script for Asterisk integration
# 6. Optionally configuring firewall rules
# 7. Optionally setting up web dashboard
#
# Usage: sudo bash complete_setup.sh

set -e

# Configuration
REPO_DIR="/opt/Sip-ALG-checker"
LOG_DIR="/var/log/asterisk/sip-alg-checker"
CHECK_SCRIPT="/usr/local/bin/asterisk-sip-check.sh"
AGI_SCRIPT="/var/lib/asterisk/agi-bin/check-sip-alg.py"
WAN_IP="193.105.36.4"  # Update this if your WAN IP is different

echo "════════════════════════════════════════════════════════════"
echo "  SIP ALG Checker - Setup Completion Script"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Repository: $REPO_DIR"
echo "Log Directory: $LOG_DIR"
echo "WAN IP: $WAN_IP"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "⚠ Please run this script with sudo privileges."
    exit 1
fi

# Step 1: Verify repository exists
echo "Step 1: Verifying repository..."
if [ ! -d "$REPO_DIR" ]; then
    echo "✗ Repository not found at $REPO_DIR"
    echo "  Please clone the repository first:"
    echo "  git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git $REPO_DIR"
    exit 1
fi
echo "✓ Repository found"

# Step 2: Create log directory
echo ""
echo "Step 2: Creating log directory..."
if [ -d "$LOG_DIR" ]; then
    echo "  Log directory already exists"
else
    mkdir -p "$LOG_DIR"
    chown asterisk:asterisk "$LOG_DIR" 2>/dev/null || chown root:root "$LOG_DIR"
    echo "✓ Log directory created"
fi

# Step 3: Create monitoring script
echo ""
echo "Step 3: Creating monitoring script..."
if [ -f "$CHECK_SCRIPT" ]; then
    echo "  Monitoring script already exists, backing up..."
    cp "$CHECK_SCRIPT" "$CHECK_SCRIPT.bak.$(date +%Y%m%d-%H%M%S)"
fi

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

# Use bc for floating point comparison if available, otherwise skip
if command -v bc >/dev/null 2>&1; then
    if (( $(echo "$PACKET_LOSS > 1.0" | bc -l 2>/dev/null || echo 0) )) || (( $(echo "$JITTER > 30" | bc -l 2>/dev/null || echo 0) )); then
        echo "WARNING: Poor network quality detected!" | \
          mail -s "SIP Quality Alert - $(hostname)" root 2>/dev/null || \
          echo "Mail not configured, but alert triggered: Packet Loss $PACKET_LOSS%, Jitter ${JITTER}ms"
    fi
fi

# Keep only last 30 days of logs
find "$LOG_DIR" -type f -mtime +30 -delete 2>/dev/null || true

# Log completion
echo "$(date): Check completed" >> "$LOG_DIR/check-completed.log"
EOFSCRIPT

chmod +x "$CHECK_SCRIPT"
echo "✓ Monitoring script created at $CHECK_SCRIPT"

# Step 4: Add cron job
echo ""
echo "Step 4: Adding cron job for periodic monitoring..."
CRON_JOB="0 */6 * * * $CHECK_SCRIPT >/dev/null 2>&1"

# Check if exact cron job already exists
if crontab -l 2>/dev/null | grep -qF "$CRON_JOB"; then
    echo "  Cron job already exists"
else
    # Remove any old versions of this cron job and add the new one
    (crontab -l 2>/dev/null | grep -vF "$CHECK_SCRIPT" || true; echo "$CRON_JOB") | crontab -
    echo "✓ Cron job added (runs every 6 hours)"
fi

# Step 5: Run initial checks
echo ""
echo "Step 5: Running initial checks..."
echo "════════════════════════════════════════════════════════════"
cd "$REPO_DIR"

echo ""
echo "=== SIP ALG Check ==="
python3 sip_alg_checker.py --check-alg

echo ""
echo "=== Network Quality Check (30 seconds) ==="
python3 sip_alg_checker.py --monitor "$WAN_IP" --duration 30 --output "$LOG_DIR/initial-check.json"

# Step 6: Optional - Create AGI script
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Step 6: Optional - AGI script for Asterisk integration"
echo "════════════════════════════════════════════════════════════"
echo ""
read -p "Create AGI script for Asterisk integration? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "/var/lib/asterisk/agi-bin" ]; then
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
        chown asterisk:asterisk "$AGI_SCRIPT" 2>/dev/null || true
        echo "✓ AGI script created at $AGI_SCRIPT"
        echo ""
        echo "Add this to your Asterisk dialplan (/etc/asterisk/extensions.conf):"
        echo ""
        echo "[macro-check-sip-alg]"
        echo "exten => s,1,NoOp(Checking SIP ALG)"
        echo " same => n,AGI(check-sip-alg.py)"
        echo " same => n,NoOp(Status: \${SIPALG_STATUS})"
        echo " same => n,Return()"
        echo ""
    else
        echo "✗ Asterisk AGI directory not found at /var/lib/asterisk/agi-bin"
        echo "  Install Asterisk first or create the directory"
    fi
else
    echo "Skipping AGI script creation"
fi

# Step 7: Optional - Configure firewall
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Step 7: Optional - Firewall configuration"
echo "════════════════════════════════════════════════════════════"
echo ""
read -p "Configure firewall rules for SIP/RTP? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command_exists ufw; then
        echo "Configuring UFW firewall..."
        ufw allow 5060/udp comment 'SIP' 2>/dev/null || true
        ufw allow 5060/tcp comment 'SIP' 2>/dev/null || true
        ufw allow 10000:20000/udp comment 'RTP' 2>/dev/null || true
        ufw --force enable 2>/dev/null || true
        echo "✓ UFW firewall configured"
        echo ""
        ufw status verbose
    elif command_exists iptables; then
        echo "Configuring iptables..."
        iptables -A INPUT -p udp --dport 5060 -j ACCEPT 2>/dev/null || true
        iptables -A INPUT -p tcp --dport 5060 -j ACCEPT 2>/dev/null || true
        iptables -A INPUT -p udp --dport 10000:20000 -j ACCEPT 2>/dev/null || true
        
        # Save rules if netfilter-persistent is available
        if command_exists netfilter-persistent; then
            netfilter-persistent save 2>/dev/null || true
        fi
        echo "✓ iptables rules configured"
    else
        echo "✗ No firewall tool found (ufw or iptables)"
    fi
else
    echo "Skipping firewall configuration"
fi

# Step 8: Optional - Web dashboard
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Step 8: Optional - Web dashboard"
echo "════════════════════════════════════════════════════════════"
echo ""
read -p "Create web dashboard for monitoring? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    DASHBOARD_DIR="/var/www/html/sip-status"
    if [ -d "/var/www/html" ]; then
        mkdir -p "$DASHBOARD_DIR"
        cat > "$DASHBOARD_DIR/index.php" << EOFDASH
<?php
// Configuration - hardcoded for security
\$log_dir = '$LOG_DIR';
\$wan_ip = '$WAN_IP';

// Get latest quality file
\$files = glob(\$log_dir . '/quality-*.json');
if (\$files) {
    usort(\$files, function(\$a, \$b) { return filemtime(\$b) - filemtime(\$a); });
    \$latest = \$files[0];
    \$data = json_decode(file_get_contents(\$latest), true);
} else {
    \$data = ['summary' => ['packet_loss_percent' => 0, 'jitter_ms' => 0, 'avg_latency_ms' => 0, 'timestamp' => 'No data yet']];
}

// Get latest ALG check log
\$alg_status = 'UNKNOWN';
\$alg_timestamp = 'No check performed yet';
\$alg_files = glob(\$log_dir . '/alg-check-*.log');
if (\$alg_files) {
    usort(\$alg_files, function(\$a, \$b) { return filemtime(\$b) - filemtime(\$a); });
    \$alg_log = \$alg_files[0];
    \$alg_content = file_get_contents(\$alg_log);
    \$alg_timestamp = date('Y-m-d H:i:s', filemtime(\$alg_log));
    
    // Parse SIP ALG status from log
    if (preg_match('/SIP ALG Status: (LIKELY|UNLIKELY|POSSIBLE|NO)/', \$alg_content, \$matches)) {
        \$alg_status = \$matches[1];
    } elseif (preg_match('/sip_alg_detected.*?: ["\']?(LIKELY|UNLIKELY|POSSIBLE|NO)["\']?/', \$alg_content, \$matches)) {
        \$alg_status = \$matches[1];
    }
}

// Determine ALG status class
\$alg_class = 'good';
if (\$alg_status == 'LIKELY') {
    \$alg_class = 'poor';
} elseif (\$alg_status == 'POSSIBLE') {
    \$alg_class = 'fair';
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>SIP ALG Status - <?php echo \$wan_ip; ?></title>
    <meta http-equiv="refresh" content="300">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #0066cc; padding-bottom: 10px; }
        h2 { color: #666; margin-top: 30px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }
        .section { margin-top: 20px; }
        .alg-status-box { padding: 15px; margin: 15px 0; border-radius: 8px; font-size: 1.2em; font-weight: bold; text-align: center; }
        .alg-status-box.good { background: #d4edda; border: 2px solid #28a745; color: #155724; }
        .alg-status-box.fair { background: #fff3cd; border: 2px solid #ffc107; color: #856404; }
        .alg-status-box.poor { background: #f8d7da; border: 2px solid #dc3545; color: #721c24; }
        .metric { margin: 15px 0; padding: 10px; background: #f9f9f9; border-left: 4px solid #ccc; }
        .metric strong { display: inline-block; width: 150px; }
        .good { border-left-color: green; color: green; }
        .fair { border-left-color: orange; color: orange; }
        .poor { border-left-color: red; color: red; }
        .timestamp { color: #999; font-size: 0.9em; margin-top: 10px; }
        .button { display: inline-block; padding: 10px 20px; background: #0066cc; color: white; text-decoration: none; border-radius: 4px; margin-top: 10px; }
        .button:hover { background: #0052a3; cursor: pointer; }
        .header-info { color: #666; font-size: 0.95em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>SIP ALG Checker Dashboard</h1>
        <p class="header-info">Server: <strong><?php echo \$wan_ip; ?></strong></p>
        
        <!-- SIP ALG Status Section -->
        <div class="section">
            <h2>🔍 SIP ALG Status</h2>
            <div class="alg-status-box <?php echo \$alg_class; ?>">
                SIP ALG: <?php echo \$alg_status; ?>
            </div>
            <div class="timestamp">
                <em>Last ALG check: <?php echo \$alg_timestamp; ?></em>
            </div>
            <?php if (\$alg_status == 'LIKELY'): ?>
                <p style="color: #721c24; margin-top: 10px;">
                    ⚠️ <strong>Action Required:</strong> SIP ALG is likely interfering with VoIP traffic. 
                    Disable SIP ALG in your router settings to improve call quality.
                </p>
            <?php elseif (\$alg_status == 'POSSIBLE'): ?>
                <p style="color: #856404; margin-top: 10px;">
                    ℹ️ SIP ALG may be present. If experiencing VoIP issues, try disabling SIP ALG in your router.
                </p>
            <?php endif; ?>
        </div>
        
        <!-- Network Quality Section -->
        <div class="section">
            <h2>📊 Network Quality Metrics</h2>
            
            <div class="metric <?php echo \$data['summary']['packet_loss_percent'] > 1 ? 'poor' : 'good'; ?>">
                <strong>Packet Loss:</strong> 
                <?php echo \$data['summary']['packet_loss_percent']; ?>%
            </div>
            
            <div class="metric <?php echo \$data['summary']['jitter_ms'] > 30 ? 'poor' : (\$data['summary']['jitter_ms'] > 20 ? 'fair' : 'good'); ?>">
                <strong>Jitter:</strong> 
                <?php echo \$data['summary']['jitter_ms']; ?>ms
            </div>
            
            <div class="metric <?php echo \$data['summary']['avg_latency_ms'] > 150 ? 'poor' : 'good'; ?>">
                <strong>Avg Latency:</strong> 
                <?php echo \$data['summary']['avg_latency_ms']; ?>ms
            </div>
            
            <div class="timestamp">
                <em>Last quality check: <?php echo \$data['summary']['timestamp']; ?></em>
            </div>
        </div>
        
        <div style="margin-top: 30px; text-align: center;">
            <a href="?refresh=1" class="button">🔄 Run Full Check Now</a>
        </div>
        
        <p style="text-align: center; color: #999; font-size: 0.85em; margin-top: 20px;">
            <em>Page auto-refreshes every 5 minutes</em>
        </p>
    </div>
</body>
</html>
<?php
if (isset(\$_GET['refresh'])) {
    shell_exec('$CHECK_SCRIPT > /dev/null 2>&1 &');
    header("Location: index.php");
    exit;
}
?>
EOFDASH
        echo "✓ Web dashboard created at: http://$WAN_IP/sip-status/"
        echo "  Note: Requires PHP and a web server (Apache/Nginx)"
    else
        echo "✗ Web server directory not found at /var/www/html"
        echo "  Install a web server first (e.g., apache2 or nginx with php)"
    fi
else
    echo "Skipping web dashboard creation"
fi

# Final summary
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Setup Completion Successful!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📁 Installation Details:"
echo "   • SIP ALG Checker: $REPO_DIR"
echo "   • Logs: $LOG_DIR"
echo "   • Monitor script: $CHECK_SCRIPT"
echo "   • Cron: Every 6 hours (0 */6 * * *)"

if [ -f "$AGI_SCRIPT" ]; then
    echo "   • AGI script: $AGI_SCRIPT"
fi

echo ""
echo "✅ Completed Tasks:"
echo "   • Log directory created"
echo "   • Monitoring script created"
echo "   • Cron job added for automatic monitoring"
echo "   • Initial checks completed"

echo ""
echo "📝 Next Steps:"
echo "   1. Review logs: ls -la $LOG_DIR"
echo "   2. Check cron job: crontab -l"
echo "   3. Manual check: $CHECK_SCRIPT"
echo "   4. View monitoring: tail -f $LOG_DIR/monitor.log"

if [ -f "$AGI_SCRIPT" ]; then
    echo "   5. Configure Asterisk dialplan to use AGI script"
fi

echo ""
echo "🔧 Useful Commands:"
echo "   • Run check manually: $CHECK_SCRIPT"
echo "   • Quick ALG check: cd $REPO_DIR && python3 sip_alg_checker.py --check-alg"
echo "   • Monitor quality: cd $REPO_DIR && python3 sip_alg_checker.py --monitor $WAN_IP --duration 300"
echo "   • View latest log: tail -20 $LOG_DIR/monitor.log"
echo ""

if [ -d "/var/www/html/sip-status" ]; then
    echo "🌐 Web Dashboard:"
    echo "   • URL: http://$WAN_IP/sip-status/"
    echo ""
fi

echo "📖 Documentation:"
echo "   • Full guide: $REPO_DIR/ASTERISK_SETUP.md"
echo "   • Security: $REPO_DIR/SECURITY.md"
echo "   • Quick start: $REPO_DIR/QUICK_START.md"
echo ""
echo "════════════════════════════════════════════════════════════"
