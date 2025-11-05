#!/bin/bash
#
# Automated Setup Script for SIP ALG Checker on Asterisk Server
# Server: 193.105.36.4
#
# Usage: sudo bash setup-asterisk.sh
#

set -e

echo "════════════════════════════════════════════════════════════"
echo "  Asterisk SIP ALG Checker - Automated Setup"
echo "  Server IP: 193.105.36.4"
echo "════════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠ Please run as root (use sudo)"
    exit 1
fi

echo "Step 1: Installing dependencies..."
apt-get update -qq
apt-get install -y python3 python3-pip git jq bc netcat curl fail2ban ufw > /dev/null 2>&1
echo "✓ Dependencies installed"

echo ""
echo "Step 2: Installing Python packages..."
pip3 install -q ping3 || echo "  (ping3 optional - will work without it)"
echo "✓ Python packages installed"

echo ""
echo "Step 3: Setting up SIP ALG Checker..."
cd /opt

if [ -d "Sip-ALG-checker" ]; then
    echo "  Updating existing installation..."
    cd Sip-ALG-checker
    git pull -q
else
    echo "  Cloning repository..."
    git clone -q https://github.com/gauthiervq-sys/Sip-ALG-checker.git
    cd Sip-ALG-checker
fi

chmod +x sip_alg_checker.py
echo "✓ SIP ALG Checker installed in /opt/Sip-ALG-checker"

echo ""
echo "Step 4: Creating log directory..."
mkdir -p /var/log/asterisk/sip-alg-checker
chown -R asterisk:asterisk /var/log/asterisk/sip-alg-checker 2>/dev/null || true
echo "✓ Log directory created"

echo ""
echo "Step 5: Installing monitoring script..."
cat > /usr/local/bin/asterisk-sip-check.sh << 'EOFSCRIPT'
#!/bin/bash
# Asterisk SIP ALG Monitoring Script
# Runs periodic checks and logs results

LOG_DIR="/var/log/asterisk/sip-alg-checker"
CHECKER_PATH="/opt/Sip-ALG-checker"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$LOG_DIR"
cd "$CHECKER_PATH"

# Check for SIP ALG
echo "[$DATE] Running SIP ALG check..." >> "$LOG_DIR/monitor.log"
python3 sip_alg_checker.py --check-alg > "$LOG_DIR/alg-check-$DATE.log" 2>&1

# Monitor network quality (5 minute sample)
echo "[$DATE] Running network quality check..." >> "$LOG_DIR/monitor.log"
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 300 \
  --output "$LOG_DIR/quality-$DATE.json" 2>&1 | tee -a "$LOG_DIR/monitor.log"

# Check for quality issues
if [ -f "$LOG_DIR/quality-$DATE.json" ]; then
    PACKET_LOSS=$(jq -r '.summary.packet_loss_percent // 0' "$LOG_DIR/quality-$DATE.json")
    JITTER=$(jq -r '.summary.jitter_ms // 0' "$LOG_DIR/quality-$DATE.json")
    
    if (( $(echo "$PACKET_LOSS > 1.0" | bc -l 2>/dev/null || echo 0) )); then
        echo "⚠ WARNING: High packet loss detected: ${PACKET_LOSS}%" >> "$LOG_DIR/monitor.log"
    fi
    
    if (( $(echo "$JITTER > 30" | bc -l 2>/dev/null || echo 0) )); then
        echo "⚠ WARNING: High jitter detected: ${JITTER}ms" >> "$LOG_DIR/monitor.log"
    fi
fi

# Cleanup old logs (keep 30 days)
find "$LOG_DIR" -type f -mtime +30 -delete 2>/dev/null

echo "[$DATE] Check complete" >> "$LOG_DIR/monitor.log"
EOFSCRIPT

chmod +x /usr/local/bin/asterisk-sip-check.sh
echo "✓ Monitoring script installed"

echo ""
echo "Step 6: Setting up cron job..."
# Remove old cron job if exists
crontab -l 2>/dev/null | grep -v "asterisk-sip-check.sh" | crontab - 2>/dev/null || true

# Add new cron job (runs every 6 hours)
(crontab -l 2>/dev/null; echo "# SIP ALG Checker - runs every 6 hours") | crontab -
(crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/asterisk-sip-check.sh >/dev/null 2>&1") | crontab -
echo "✓ Cron job installed (runs every 6 hours)"

echo ""
echo "Step 7: Installing AGI script (optional - for Asterisk integration)..."
mkdir -p /var/lib/asterisk/agi-bin

cat > /var/lib/asterisk/agi-bin/check-sip-alg.py << 'EOFAGI'
#!/usr/bin/env python3
"""
Asterisk AGI Script to check SIP ALG
Usage in dialplan: AGI(check-sip-alg.py)
"""

import sys
import os

sys.path.insert(0, '/opt/Sip-ALG-checker')

try:
    from sip_alg_checker import SIPALGChecker
    
    # Read AGI environment
    env = {}
    while True:
        line = sys.stdin.readline().strip()
        if not line:
            break
        if ':' in line:
            key, value = line.split(':', 1)
            env[key.strip()] = value.strip()
    
    # Check SIP ALG
    checker = SIPALGChecker()
    results = checker.check_sip_alg_via_nat()
    
    # Set channel variable
    sys.stdout.write(f'SET VARIABLE SIPALG_STATUS "{results["sip_alg_detected"]}"\n')
    sys.stdout.flush()
    sys.stdin.readline()
    
    # Log result
    status = results['sip_alg_detected']
    sys.stdout.write(f'VERBOSE "SIP ALG Status: {status}" 1\n')
    sys.stdout.flush()
    sys.stdin.readline()
    
except Exception as e:
    sys.stdout.write(f'VERBOSE "SIP ALG Check Error: {str(e)}" 1\n')
    sys.stdout.flush()

sys.exit(0)
EOFAGI

chmod +x /var/lib/asterisk/agi-bin/check-sip-alg.py
chown asterisk:asterisk /var/lib/asterisk/agi-bin/check-sip-alg.py 2>/dev/null || true
echo "✓ AGI script installed"

echo ""
echo "Step 8: Creating sample Asterisk configuration..."
cat > /tmp/asterisk-sip-alg-config.txt << 'EOFCONFIG'
# ========================================
# Asterisk Configuration for SIP ALG Detection
# Add these settings to your Asterisk configuration
# ========================================

# For PJSIP (Asterisk 13+) - /etc/asterisk/pjsip.conf
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=193.105.36.4
external_signaling_address=193.105.36.4

# For chan_sip (legacy) - /etc/asterisk/sip.conf
[general]
externip=193.105.36.4
nat=force_rport,comedia
directmedia=no

# RTP Configuration - /etc/asterisk/rtp.conf
[general]
rtpstart=10000
rtpend=20000
strictrtp=yes

# Dialplan Integration - /etc/asterisk/extensions.conf
[macro-check-sip-alg]
exten => s,1,NoOp(Checking SIP ALG)
 same => n,AGI(check-sip-alg.py)
 same => n,NoOp(Status: ${SIPALG_STATUS})
 same => n,Return()

EOFCONFIG

echo "✓ Sample configuration created in /tmp/asterisk-sip-alg-config.txt"

echo ""
echo "Step 9: Configuring security (Fail2ban)..."
if [ -d "/etc/fail2ban" ]; then
    # Create Asterisk Fail2ban filter
    cat > /etc/fail2ban/filter.d/asterisk.conf << 'EOFFAIL2BAN'
[Definition]
failregex = NOTICE.* .*: Registration from '.*' failed for '<HOST>:.*' - Wrong password
            NOTICE.* .*: Registration from '.*' failed for '<HOST>:.*' - No matching peer found
            NOTICE.* .*: Registration from '.*' failed for '<HOST>:.*' - Username/auth name mismatch
            NOTICE.* <HOST> failed to authenticate as '.*'
            NOTICE.* .*: No registration for peer '.*' \(from <HOST>\)
ignoreregex =
EOFFAIL2BAN

    # Create Asterisk jail configuration
    cat > /etc/fail2ban/jail.d/asterisk.conf << 'EOFJAIL'
[asterisk]
enabled = true
port = 5060,5061
protocol = all
filter = asterisk
logpath = /var/log/asterisk/full
maxretry = 3
bantime = 86400
findtime = 600
action = iptables-allports[name=ASTERISK, protocol=all]
EOFJAIL

    systemctl restart fail2ban 2>/dev/null || true
    echo "✓ Fail2ban configured for Asterisk protection"
else
    echo "⚠ Fail2ban not installed - skipping (install with: apt-get install fail2ban)"
fi

echo ""
echo "Step 10: Setting secure file permissions..."
# Secure the checker tool
chown root:root /opt/Sip-ALG-checker/sip_alg_checker.py 2>/dev/null || true
chmod 755 /opt/Sip-ALG-checker/sip_alg_checker.py

# Secure AGI script
chown asterisk:asterisk /var/lib/asterisk/agi-bin/check-sip-alg.py 2>/dev/null || true
chmod 550 /var/lib/asterisk/agi-bin/check-sip-alg.py 2>/dev/null || true

# Secure log directory
chmod 750 /var/log/asterisk/sip-alg-checker 2>/dev/null || true
echo "✓ Secure permissions set"

echo ""
echo "Step 11: Creating firewall configuration template..."
cat > /tmp/firewall-config.sh << 'EOFFIREWALL'
#!/bin/bash
# Secure Firewall Configuration for Asterisk Server
# REVIEW AND CUSTOMIZE BEFORE RUNNING!

# UFW Configuration (Recommended)
if command -v ufw &> /dev/null; then
    echo "Configuring UFW firewall..."
    
    # Reset to defaults
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH (CHANGE PORT IF USING NON-STANDARD)
    ufw allow 22/tcp comment 'SSH'
    
    # SIP with rate limiting (public access)
    ufw limit 5060/udp comment 'SIP-UDP'
    ufw limit 5060/tcp comment 'SIP-TCP'
    
    # RTP media
    ufw allow 10000:20000/udp comment 'RTP'
    
    # Enable firewall
    ufw --force enable
    
    echo "✓ UFW configured"
    ufw status verbose
else
    echo "UFW not installed. Install with: apt-get install ufw"
fi
EOFFIREWALL

chmod +x /tmp/firewall-config.sh
echo "✓ Firewall config template created in /tmp/firewall-config.sh"

echo ""
echo "Step 12: Creating security audit script..."
cat > /tmp/security-audit.sh << 'EOFAUDIT'
#!/bin/bash
# Security Audit for Asterisk Server

echo "╔════════════════════════════════════════════════════════════╗"
echo "║            ASTERISK SECURITY AUDIT                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "1. Checking firewall status..."
if command -v ufw &> /dev/null; then
    ufw status | grep -q "Status: active" && echo "✓ UFW is active" || echo "✗ UFW is NOT active"
else
    echo "⚠ UFW not installed"
fi

echo ""
echo "2. Checking Fail2ban status..."
if systemctl is-active --quiet fail2ban; then
    echo "✓ Fail2ban is running"
    fail2ban-client status asterisk 2>/dev/null || echo "⚠ Asterisk jail not configured"
else
    echo "✗ Fail2ban is NOT running"
fi

echo ""
echo "3. Checking Asterisk guest access..."
if grep -q "allowguest=no" /etc/asterisk/sip.conf 2>/dev/null || \
   grep -q "allowguest=no" /etc/asterisk/pjsip.conf 2>/dev/null; then
    echo "✓ Guest access is disabled"
else
    echo "⚠ Guest access status unknown - verify manually"
fi

echo ""
echo "4. Checking for weak passwords in SIP config..."
if grep -E "(secret|password)=.{1,8}$" /etc/asterisk/sip.conf 2>/dev/null || \
   grep -E "(secret|password)=.{1,8}$" /etc/asterisk/pjsip.conf 2>/dev/null; then
    echo "⚠ WARNING: Weak passwords detected (less than 9 characters)"
else
    echo "✓ No obviously weak passwords found"
fi

echo ""
echo "5. Checking recent failed authentication attempts..."
FAILED_AUTHS=$(grep "failed to authenticate" /var/log/asterisk/full 2>/dev/null | tail -100 | wc -l)
echo "   Last 100 log entries: $FAILED_AUTHS failed attempts"
if [ "$FAILED_AUTHS" -gt 10 ]; then
    echo "   ⚠ WARNING: High number of failed attempts detected"
fi

echo ""
echo "6. Checking file permissions..."
if [ -f "/var/lib/asterisk/agi-bin/check-sip-alg.py" ]; then
    PERMS=$(stat -c %a /var/lib/asterisk/agi-bin/check-sip-alg.py 2>/dev/null)
    if [ "$PERMS" = "550" ] || [ "$PERMS" = "750" ]; then
        echo "✓ AGI script has secure permissions ($PERMS)"
    else
        echo "⚠ AGI script permissions: $PERMS (recommended: 550)"
    fi
fi

echo ""
echo "7. Checking SSH configuration..."
if grep -q "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    echo "✓ Root login is disabled"
else
    echo "⚠ Root login may be enabled"
fi

if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
    echo "✓ Password authentication is disabled"
else
    echo "⚠ Password authentication may be enabled"
fi

echo ""
echo "8. Checking for system updates..."
if command -v apt-get &> /dev/null; then
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    echo "   Available updates: $UPDATES"
    if [ "$UPDATES" -gt 10 ]; then
        echo "   ⚠ Consider running: apt-get update && apt-get upgrade"
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║            AUDIT COMPLETE                                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
EOFAUDIT

chmod +x /tmp/security-audit.sh
echo "✓ Security audit script created in /tmp/security-audit.sh"

echo ""
echo "Step 13: Running initial check..."
cd /opt/Sip-ALG-checker
python3 sip_alg_checker.py --check-alg

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Setup Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📁 Installation Details:"
echo "   • Checker: /opt/Sip-ALG-checker/sip_alg_checker.py"
echo "   • Logs: /var/log/asterisk/sip-alg-checker/"
echo "   • Monitor script: /usr/local/bin/asterisk-sip-check.sh"
echo "   • AGI script: /var/lib/asterisk/agi-bin/check-sip-alg.py"
echo "   • Cron: Every 6 hours (0 */6 * * *)"
echo ""
echo "🔒 SECURITY (IMPORTANT):"
echo "   • Fail2ban configured for Asterisk protection"
echo "   • Review firewall config: /tmp/firewall-config.sh"
echo "   • Run security audit: /tmp/security-audit.sh"
echo "   • Read security guide: /opt/Sip-ALG-checker/SECURITY.md"
echo ""
echo "⚠  CRITICAL NEXT STEPS:"
echo "   1. Review and run: /tmp/firewall-config.sh"
echo "   2. Configure strong SIP passwords (20+ chars)"
echo "   3. Disable guest access in Asterisk"
echo "   4. Restrict outbound calling in dialplan"
echo "   5. Run security audit: /tmp/security-audit.sh"
echo ""
echo "📝 Configuration:"
echo "   1. Review sample config: cat /tmp/asterisk-sip-alg-config.txt"
echo "   2. Update Asterisk with external IP: 193.105.36.4"
echo "   3. Reload Asterisk: asterisk -rx 'core reload'"
echo "   4. Test from client: python3 sip_alg_checker.py --monitor 193.105.36.4"
echo ""
echo "🔧 Manual Commands:"
echo "   • Run check now: /usr/local/bin/asterisk-sip-check.sh"
echo "   • View logs: ls -la /var/log/asterisk/sip-alg-checker/"
echo "   • Security audit: /tmp/security-audit.sh"
echo "   • Check cron: crontab -l"
echo ""
echo "📖 Documentation:"
echo "   • Full guide: /opt/Sip-ALG-checker/ASTERISK_SETUP.md"
echo "   • Security: /opt/Sip-ALG-checker/SECURITY.md"
echo "   • Quick setup: /opt/Sip-ALG-checker/QUICK_SETUP_193.105.36.4.md"
echo ""
echo "════════════════════════════════════════════════════════════"
