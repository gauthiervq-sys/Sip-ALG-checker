#!/bin/bash
#
# Quick Security Hardening Script for Asterisk Server
# Server: 193.105.36.4
#
# Usage: sudo bash secure-asterisk.sh
#
# This script implements essential security measures to protect against:
# - Unauthorized outbound calls (toll fraud)
# - SIP scanning and brute force attacks
# - Unauthorized server access
#

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║      Asterisk Security Hardening - 193.105.36.4           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠ Please run as root (use sudo)"
    exit 1
fi

echo "This script will:"
echo "  1. Configure firewall with rate limiting"
echo "  2. Set up Fail2ban for SIP protection"
echo "  3. Secure file permissions"
echo "  4. Create Asterisk security config templates"
echo "  5. Set up monitoring and alerts"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Installing security tools..."
apt-get update -qq
apt-get install -y fail2ban ufw iptables-persistent > /dev/null 2>&1
echo "✓ Security tools installed"

echo ""
echo "Step 2: Configuring UFW Firewall..."

# Reset UFW
ufw --force reset > /dev/null 2>&1

# Default policies
ufw default deny incoming
ufw default allow outgoing

# SSH (with rate limiting)
read -p "Enter SSH port (default 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22}
ufw limit $SSH_PORT/tcp comment 'SSH'

# SIP with aggressive rate limiting
ufw limit 5060/udp comment 'SIP-UDP'
ufw limit 5060/tcp comment 'SIP-TCP'

# RTP media
ufw allow 10000:20000/udp comment 'RTP'

# Enable firewall
ufw --force enable

echo "✓ UFW firewall configured and enabled"
ufw status numbered

echo ""
echo "Step 3: Configuring Fail2ban..."

# Create Asterisk filter
cat > /etc/fail2ban/filter.d/asterisk.conf << 'EOF'
[Definition]
failregex = NOTICE.* .*: Registration from '.*' failed for '<HOST>:.*' - Wrong password
            NOTICE.* .*: Registration from '.*' failed for '<HOST>:.*' - No matching peer found
            NOTICE.* .*: Registration from '.*' failed for '<HOST>:.*' - Username/auth name mismatch
            NOTICE.* <HOST> failed to authenticate as '.*'
            NOTICE.* .*: No registration for peer '.*' \(from <HOST>\)
            VERBOSE.*SIP/<HOST>.*Received incoming SIP connection from unknown peer
ignoreregex =
EOF

# Create jail configuration
cat > /etc/fail2ban/jail.d/asterisk.conf << 'EOF'
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
EOF

# Restart Fail2ban
systemctl enable fail2ban
systemctl restart fail2ban
echo "✓ Fail2ban configured for Asterisk"

echo ""
echo "Step 4: Creating secure Asterisk configuration templates..."

# Create secure PJSIP config
cat > /etc/asterisk/pjsip-security.conf << 'EOF'
; ============================================
; SECURITY-HARDENED PJSIP CONFIGURATION
; Include this in your main pjsip.conf:
; #include pjsip-security.conf
; ============================================

[global]
type=global
max_calls=50
user_agent=Asterisk PBX

[transport-udp-secure]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=193.105.36.4
external_signaling_address=193.105.36.4

; Security template for all endpoints
[endpoint-secure](!)
type=endpoint
; Place in untrusted context by default
context=from-untrusted
disallow=all
allow=ulaw
allow=alaw
; Prevent IP exposure
direct_media=no
; Force symmetric RTP
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
; Enable ICE
ice_support=yes
; Limit calls per endpoint
device_state_busy_at=2
; Require authentication
auth_type=userpass

; Authentication template
[auth-secure](!)
type=auth
auth_type=userpass
; Password will be set per endpoint
; Use strong passwords: openssl rand -base64 20
EOF

# Create secure dialplan
cat > /etc/asterisk/extensions-security.conf << 'EOF'
; ============================================
; SECURITY-HARDENED DIALPLAN
; Include this in your main extensions.conf:
; #include extensions-security.conf
; ============================================

[globals]
; Define allowed country codes (customize for your needs)
; Example: US=1, Netherlands=31, Belgium=32, France=33, Germany=49, UK=44
ALLOWED_COUNTRY_CODES=1|31|32|33|49|44

; Maximum call duration (1 hour)
MAX_CALL_DURATION=3600

[from-untrusted]
; SECURITY: Block ALL calls from untrusted sources
exten => _X.,1,NoOp(SECURITY: Blocked call from untrusted source)
same => n,Log(WARNING,Unauthorized call attempt to ${EXTEN} from ${CALLERID(num)} at ${CHANNEL(peerip)})
same => n,Hangup(21)

; Reject all by default
exten => _.,1,NoOp(SECURITY: Blocked undefined pattern)
same => n,Hangup(21)

[from-internal]
; Context for authenticated internal users
exten => _X.,1,NoOp(Call from ${CALLERID(num)} to ${EXTEN})
; Log the call attempt
same => n,Log(NOTICE,Call attempt: ${CALLERID(num)} -> ${EXTEN})
; Check if destination matches allowed patterns
same => n,GotoIf($[${REGEX("^(${ALLOWED_COUNTRY_CODES})" ${EXTEN})} = 1]?allowed:blocked)
same => n(blocked),Log(WARNING,SECURITY: Blocked unauthorized destination ${EXTEN} from ${CALLERID(num)})
same => n,Playback(ss-noservice)
same => n,Hangup()
; If allowed, set timeout and place call
same => n(allowed),Set(TIMEOUT(absolute)=${MAX_CALL_DURATION})
same => n,Dial(SIP/${EXTEN}@yourtrunk,60)
same => n,Hangup()

; Emergency numbers (customize for your country)
exten => 112,1,NoOp(Emergency call)
same => n,Dial(SIP/112@yourtrunk)
same => n,Hangup()

exten => 911,1,NoOp(Emergency call)
same => n,Dial(SIP/911@yourtrunk)
same => n,Hangup()
EOF

# Create secure SIP config
cat > /etc/asterisk/sip-security.conf << 'EOF'
; ============================================
; SECURITY-HARDENED SIP CONFIGURATION
; Include this in your main sip.conf:
; #include sip-security.conf
; ============================================

[general]
; SECURITY: Disable guest access
allowguest=no
; SECURITY: Always reject with same response
alwaysauthreject=yes

; External IP configuration
externip=193.105.36.4
nat=force_rport,comedia
directmedia=no

; Port configuration
bindport=5060

; Security options
tcpenable=no
; Limit concurrent calls
maxcalls=50

; Registration timeout
minexpiry=60
maxexpiry=3600
defaultexpiry=120
EOF

echo "✓ Secure Asterisk configuration templates created"
echo "  - /etc/asterisk/pjsip-security.conf"
echo "  - /etc/asterisk/extensions-security.conf"
echo "  - /etc/asterisk/sip-security.conf"

echo ""
echo "Step 5: Securing file permissions..."

# Secure Asterisk configuration directory
chown -R asterisk:asterisk /etc/asterisk
chmod 750 /etc/asterisk
chmod 640 /etc/asterisk/*.conf

# Secure AGI directory
if [ -d "/var/lib/asterisk/agi-bin" ]; then
    chown asterisk:asterisk /var/lib/asterisk/agi-bin
    chmod 750 /var/lib/asterisk/agi-bin
    chmod 550 /var/lib/asterisk/agi-bin/*.py 2>/dev/null || true
fi

# Secure log directory
if [ -d "/var/log/asterisk/sip-alg-checker" ]; then
    chown asterisk:asterisk /var/log/asterisk/sip-alg-checker
    chmod 750 /var/log/asterisk/sip-alg-checker
fi

echo "✓ File permissions secured"

echo ""
echo "Step 6: Creating monitoring and alert scripts..."

# Create security monitoring script
cat > /usr/local/bin/asterisk-security-monitor.sh << 'EOFMONITOR'
#!/bin/bash
# Asterisk Security Monitoring
# Run via cron every 5 minutes

LOG_FILE="/var/log/asterisk/full"
ALERT_EMAIL="${ALERT_EMAIL:-root}"
THRESHOLD_FAILED_AUTH=10

# Check for failed authentication attempts
FAILED_AUTHS=$(tail -1000 "$LOG_FILE" 2>/dev/null | grep -c "failed to authenticate" || echo 0)

if [ "$FAILED_AUTHS" -gt "$THRESHOLD_FAILED_AUTH" ]; then
    echo "WARNING: $FAILED_AUTHS failed authentication attempts detected" | \
        mail -s "Asterisk Security Alert - $(hostname)" "$ALERT_EMAIL" 2>/dev/null || \
        logger -t asterisk-security "WARNING: $FAILED_AUTHS failed authentication attempts"
fi

# Check for unusual outbound call volume
OUTBOUND_CALLS=$(asterisk -rx "core show channels" 2>/dev/null | grep -c "outbound" || echo 0)
if [ "$OUTBOUND_CALLS" -gt 20 ]; then
    echo "WARNING: Unusual outbound call volume: $OUTBOUND_CALLS" | \
        mail -s "Asterisk Toll Fraud Alert - $(hostname)" "$ALERT_EMAIL" 2>/dev/null || \
        logger -t asterisk-security "WARNING: Unusual outbound call volume: $OUTBOUND_CALLS"
fi
EOFMONITOR

chmod +x /usr/local/bin/asterisk-security-monitor.sh

# Add to cron
(crontab -l 2>/dev/null | grep -v "asterisk-security-monitor"; \
 echo "*/5 * * * * /usr/local/bin/asterisk-security-monitor.sh") | crontab -

echo "✓ Security monitoring configured (runs every 5 minutes)"

echo ""
echo "Step 7: Creating password generator..."

cat > /usr/local/bin/generate-sip-password.sh << 'EOFPASS'
#!/bin/bash
# Generate strong SIP passwords

echo "Generating strong SIP credentials..."
echo "=================================="

for i in {1..5}; do
    USERNAME="user$i"
    PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
    echo "Username: $USERNAME"
    echo "Password: $PASSWORD"
    echo "---"
done

echo ""
echo "Add these to your Asterisk configuration with:"
echo "  • PJSIP: [auth-username](auth-secure)"
echo "  •        password=\$PASSWORD"
echo "  • SIP:   secret=\$PASSWORD"
EOFPASS

chmod +x /usr/local/bin/generate-sip-password.sh

echo "✓ Password generator created: /usr/local/bin/generate-sip-password.sh"

echo ""
echo "Step 8: Creating security audit script..."

cat > /usr/local/bin/asterisk-security-audit.sh << 'EOFAUDIT'
#!/bin/bash
# Asterisk Security Audit

echo "╔════════════════════════════════════════════════════════════╗"
echo "║            ASTERISK SECURITY AUDIT                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

ISSUES=0

# Check firewall
echo "1. Firewall Status:"
if ufw status | grep -q "Status: active"; then
    echo "   ✓ UFW is active"
else
    echo "   ✗ UFW is NOT active"; ((ISSUES++))
fi

# Check Fail2ban
echo ""
echo "2. Fail2ban Status:"
if systemctl is-active --quiet fail2ban; then
    echo "   ✓ Fail2ban is running"
    BANNED=$(fail2ban-client status asterisk 2>/dev/null | grep "Currently banned" | awk '{print $4}')
    echo "   Currently banned IPs: ${BANNED:-0}"
else
    echo "   ✗ Fail2ban is NOT running"; ((ISSUES++))
fi

# Check guest access
echo ""
echo "3. Guest Access:"
if grep -q "allowguest=no" /etc/asterisk/sip.conf /etc/asterisk/pjsip.conf 2>/dev/null; then
    echo "   ✓ Guest access is disabled"
else
    echo "   ⚠ Guest access status unknown"; ((ISSUES++))
fi

# Check for weak passwords
echo ""
echo "4. Password Security:"
WEAK=$(grep -E "(secret|password)=.{1,10}$" /etc/asterisk/sip.conf /etc/asterisk/pjsip.conf 2>/dev/null | wc -l)
if [ "$WEAK" -eq 0 ]; then
    echo "   ✓ No obviously weak passwords found"
else
    echo "   ✗ Found $WEAK potentially weak passwords"; ((ISSUES++))
fi

# Check authentication attempts
echo ""
echo "5. Recent Failed Authentication:"
FAILED=$(grep "failed to authenticate" /var/log/asterisk/full 2>/dev/null | tail -100 | wc -l)
echo "   Last 100 log entries: $FAILED failed attempts"
if [ "$FAILED" -gt 20 ]; then
    echo "   ⚠ HIGH number of failed attempts"; ((ISSUES++))
fi

# Check SSH
echo ""
echo "6. SSH Security:"
if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
    echo "   ✓ Root login disabled"
else
    echo "   ⚠ Root login may be enabled"; ((ISSUES++))
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
if [ "$ISSUES" -eq 0 ]; then
    echo "║  ✓ AUDIT PASSED - No critical issues found                ║"
else
    echo "║  ⚠ AUDIT FOUND $ISSUES ISSUE(S) - Review above               ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"

exit $ISSUES
EOFAUDIT

chmod +x /usr/local/bin/asterisk-security-audit.sh

echo "✓ Security audit script created: /usr/local/bin/asterisk-security-audit.sh"

echo ""
echo "Step 9: Running security audit..."
/usr/local/bin/asterisk-security-audit.sh || true

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           SECURITY HARDENING COMPLETE                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🔒 Security Measures Implemented:"
echo "   ✓ Firewall (UFW) configured with rate limiting"
echo "   ✓ Fail2ban protecting against brute force"
echo "   ✓ File permissions secured"
echo "   ✓ Security templates created"
echo "   ✓ Monitoring and alerts configured"
echo ""
echo "⚠  CRITICAL - Complete These Steps:"
echo ""
echo "1. Generate Strong Passwords:"
echo "   /usr/local/bin/generate-sip-password.sh"
echo ""
echo "2. Update Asterisk Configuration:"
echo "   • Add to pjsip.conf: #include pjsip-security.conf"
echo "   • Add to extensions.conf: #include extensions-security.conf"
echo "   • Add to sip.conf: #include sip-security.conf"
echo "   • Set allowguest=no in [general] section"
echo "   • Replace all weak passwords"
echo ""
echo "3. Restrict Outbound Calling:"
echo "   • Edit ALLOWED_COUNTRY_CODES in extensions-security.conf"
echo "   • Review and customize dialplan patterns"
echo ""
echo "4. Reload Asterisk:"
echo "   asterisk -rx 'core reload'"
echo ""
echo "5. Test Security:"
echo "   /usr/local/bin/asterisk-security-audit.sh"
echo ""
echo "📖 Documentation:"
echo "   • Security guide: /opt/Sip-ALG-checker/SECURITY.md"
echo "   • Asterisk guide: /opt/Sip-ALG-checker/ASTERISK_SETUP.md"
echo ""
echo "🔧 Useful Commands:"
echo "   • Security audit: /usr/local/bin/asterisk-security-audit.sh"
echo "   • Generate passwords: /usr/local/bin/generate-sip-password.sh"
echo "   • Check Fail2ban: fail2ban-client status asterisk"
echo "   • Check firewall: ufw status verbose"
echo ""
echo "╚════════════════════════════════════════════════════════════╝"
