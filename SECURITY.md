# Security Guide for SIP ALG Checker and Asterisk Server

This guide covers security best practices to protect your Asterisk server (193.105.36.4) from abuse, unauthorized access, and outbound call fraud.

## Table of Contents

1. [Security Overview](#security-overview)
2. [Firewall Configuration](#firewall-configuration)
3. [Asterisk Security Hardening](#asterisk-security-hardening)
4. [SIP ALG Checker Security](#sip-alg-checker-security)
5. [Access Controls](#access-controls)
6. [Monitoring and Alerts](#monitoring-and-alerts)
7. [Best Practices](#best-practices)

## Security Overview

### Common Threats

- **Toll Fraud**: Unauthorized outbound calls costing money
- **SIP Scanning**: Automated bots scanning for vulnerable servers
- **Brute Force Attacks**: Attempts to guess SIP credentials
- **DDoS Attacks**: Overwhelming the server with traffic
- **Registration Hijacking**: Unauthorized SIP registrations

### Security Principles

1. **Least Privilege**: Only allow what's necessary
2. **Defense in Depth**: Multiple layers of security
3. **Fail Secure**: Default to deny access
4. **Monitor Everything**: Log and alert on suspicious activity

## Firewall Configuration

### UFW (Ubuntu/Debian) - RECOMMENDED

```bash
#!/bin/bash
# Secure Firewall Setup for Asterisk

# Reset UFW to defaults
sudo ufw --force reset

# Default policies: deny incoming, allow outgoing
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (CHANGE PORT IF USING NON-STANDARD)
sudo ufw allow 22/tcp comment 'SSH'

# Allow SIP only from known networks (RECOMMENDED)
# Replace with your trusted IP ranges
sudo ufw allow from 192.168.0.0/16 to any port 5060 proto udp comment 'SIP-UDP-LAN'
sudo ufw allow from 192.168.0.0/16 to any port 5060 proto tcp comment 'SIP-TCP-LAN'

# If you need public SIP access, use rate limiting
sudo ufw limit 5060/udp comment 'SIP-UDP-Limited'
sudo ufw limit 5060/tcp comment 'SIP-TCP-Limited'

# Allow RTP media (limit to known ranges if possible)
sudo ufw allow 10000:20000/udp comment 'RTP-Media'

# Enable firewall
sudo ufw --force enable

# Show status
sudo ufw status verbose
```

### iptables with Rate Limiting

```bash
#!/bin/bash
# Advanced iptables rules with rate limiting

# Flush existing rules
iptables -F
iptables -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH access (change port if needed)
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# SIP with rate limiting (max 10 new connections per minute per IP)
iptables -A INPUT -p udp --dport 5060 -m state --state NEW -m recent --set --name SIP
iptables -A INPUT -p udp --dport 5060 -m state --state NEW -m recent --update --seconds 60 --hitcount 10 --name SIP -j DROP
iptables -A INPUT -p udp --dport 5060 -j ACCEPT

iptables -A INPUT -p tcp --dport 5060 -m state --state NEW -m recent --set --name SIP_TCP
iptables -A INPUT -p tcp --dport 5060 -m state --state NEW -m recent --update --seconds 60 --hitcount 10 --name SIP_TCP -j DROP
iptables -A INPUT -p tcp --dport 5060 -j ACCEPT

# RTP media ports
iptables -A INPUT -p udp --dport 10000:20000 -j ACCEPT

# Drop everything else
iptables -A INPUT -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### Fail2ban for SIP Protection

Install and configure Fail2ban to block attackers:

```bash
# Install Fail2ban
sudo apt-get install fail2ban

# Create Asterisk filter
sudo tee /etc/fail2ban/filter.d/asterisk.conf << 'EOF'
[Definition]
failregex = NOTICE.* .*: Registration from '.*' failed for '<HOST>:.*' - Wrong password
            NOTICE.* .*: Registration from '.*' failed for '<HOST>:.*' - No matching peer found
            NOTICE.* .*: Registration from '.*' failed for '<HOST>:.*' - Username/auth name mismatch
            NOTICE.* <HOST> failed to authenticate as '.*'
            NOTICE.* .*: No registration for peer '.*' \(from <HOST>\)
            VERBOSE.*SIP/<HOST>.*Received incoming SIP connection from unknown peer
ignoreregex =
EOF

# Configure jail
sudo tee /etc/fail2ban/jail.d/asterisk.conf << 'EOF'
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
sudo systemctl restart fail2ban
sudo fail2ban-client status asterisk
```

## Asterisk Security Hardening

### 1. Secure SIP Configuration (pjsip.conf)

```ini
[global]
type=global
; Maximum number of concurrent calls (adjust as needed)
max_calls=50

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=193.105.36.4
external_signaling_address=193.105.36.4
; Disable TCP if not needed
allow_reload=yes

[transport-tcp]
type=transport
protocol=tcp
bind=0.0.0.0:5060
; Only enable if you need TCP

; Security template for endpoints
[endpoint_secure](!)
type=endpoint
context=from-untrusted
disallow=all
allow=ulaw
allow=alaw
; Disable direct media to prevent IP exposure
direct_media=no
; Force symmetric RTP
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
; Enable ICE for better NAT traversal
ice_support=yes
; Limit concurrent calls per endpoint
device_state_busy_at=2
; Use strong authentication
auth_type=userpass
; Require authentication
deny=0.0.0.0/0.0.0.0
permit=192.168.0.0/255.255.0.0

[auth_template](!)
type=auth
auth_type=userpass
; Use strong passwords (minimum 20 characters, random)
; Example: openssl rand -base64 20
```

### 2. Secure Dialplan (extensions.conf)

```ini
[globals]
; Define allowed countries/prefixes
ALLOWED_COUNTRY_CODES=1|31|32|33|34|44|49
; Maximum call duration (seconds)
MAX_CALL_DURATION=3600

[from-untrusted]
; Context for untrusted/external sources
; Block all outbound by default
exten => _X.,1,NoOp(Unauthorized outbound attempt from ${CALLERID(num)})
same => n,Log(WARNING,Blocked outbound call attempt to ${EXTEN} from ${CALLERID(num)} at ${CHANNEL(peerip)})
same => n,Hangup(21)

[from-internal]
; Context for authenticated internal users
exten => _X.,1,NoOp(Call from ${CALLERID(num)} to ${EXTEN})
; Check if destination is allowed
same => n,GotoIf($[${REGEX("^(${ALLOWED_COUNTRY_CODES})" ${EXTEN})} = 1]?allowed:blocked)
same => n(blocked),Log(WARNING,Blocked call to unauthorized destination ${EXTEN})
same => n,Playback(ss-noservice)
same => n,Hangup()
same => n(allowed),Set(CHANNEL(hangup_handler_wipe)=hangup_handler,s,1)
same => n,Set(TIMEOUT(absolute)=${MAX_CALL_DURATION})
same => n,Dial(SIP/${EXTEN}@trunk,60)
same => n,Hangup()

[hangup_handler]
exten => s,1,NoOp(Call ended: ${CHANNEL(name)})
same => n,Log(NOTICE,Call duration: ${CDR(duration)}s, Cost: ${CDR(billsec)}s)
same => n,Return()

[authenticated]
; For properly authenticated users only
include => from-internal
```

### 3. Strong Authentication

```bash
#!/bin/bash
# Generate strong SIP passwords

echo "Generating strong SIP credentials..."

for i in {1..5}; do
    USERNAME="user$i"
    PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-20)
    echo "Username: $USERNAME"
    echo "Password: $PASSWORD"
    echo "---"
done

# Store in secure location
echo "Store these in /etc/asterisk/sip_secrets.conf with proper permissions:"
echo "chmod 600 /etc/asterisk/sip_secrets.conf"
echo "chown asterisk:asterisk /etc/asterisk/sip_secrets.conf"
```

### 4. Guest Access - DISABLE

```ini
; In pjsip.conf or sip.conf
[general]
allowguest=no
alwaysauthreject=yes
```

### 5. Call Detail Records (CDR) Monitoring

```ini
; In cdr.conf
[general]
enable=yes
unanswered=yes

; In cdr_custom.conf
[mappings]
Master.csv => "${CDR(accountcode)}","${CDR(src)}","${CDR(dst)}","${CDR(dcontext)}","${CDR(channel)}","${CDR(dstchannel)}","${CDR(lastapp)}","${CDR(lastdata)}","${CDR(start)}","${CDR(answer)}","${CDR(end)}","${CDR(duration)}","${CDR(billsec)}","${CDR(disposition)}","${CDR(amaflags)}","${CDR(uniqueid)}","${CDR(peerip)}"
```

## SIP ALG Checker Security

### Restrict Tool Access

The SIP ALG Checker should only be run by authorized users:

```bash
# Set proper permissions
sudo chown root:root /opt/Sip-ALG-checker/sip_alg_checker.py
sudo chmod 750 /opt/Sip-ALG-checker/sip_alg_checker.py

# Only allow specific users to run it
sudo chgrp voip-admin /opt/Sip-ALG-checker/sip_alg_checker.py

# Create the group if needed
sudo groupadd voip-admin
sudo usermod -a -G voip-admin asterisk
```

### Secure the AGI Script

```bash
# Restrict AGI script access
sudo chown asterisk:asterisk /var/lib/asterisk/agi-bin/check-sip-alg.py
sudo chmod 550 /var/lib/asterisk/agi-bin/check-sip-alg.py

# Ensure AGI directory is secure
sudo chmod 750 /var/lib/asterisk/agi-bin
```

### Secure Log Files

```bash
# Create secure log directory
sudo mkdir -p /var/log/asterisk/sip-alg-checker
sudo chown asterisk:asterisk /var/log/asterisk/sip-alg-checker
sudo chmod 750 /var/log/asterisk/sip-alg-checker

# Rotate logs to prevent disk fill
sudo tee /etc/logrotate.d/sip-alg-checker << 'EOF'
/var/log/asterisk/sip-alg-checker/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 asterisk asterisk
    sharedscripts
}

/var/log/asterisk/sip-alg-checker/*.json {
    weekly
    rotate 12
    compress
    delaycompress
    notifempty
    create 0640 asterisk asterisk
}
EOF
```

## Access Controls

### SSH Hardening

```bash
# Edit /etc/ssh/sshd_config
sudo tee -a /etc/ssh/sshd_config << 'EOF'

# Disable root login
PermitRootLogin no

# Use key-based authentication only
PubkeyAuthentication yes
PasswordAuthentication no

# Disable empty passwords
PermitEmptyPasswords no

# Limit user access
AllowUsers your-admin-user

# Change default port (optional but recommended)
Port 2222

# Disable X11 forwarding if not needed
X11Forwarding no

# Set login grace time
LoginGraceTime 30

# Maximum authentication attempts
MaxAuthTries 3
EOF

sudo systemctl restart sshd
```

### Sudo Access Restrictions

```bash
# Create sudoers file for Asterisk management
sudo visudo -f /etc/sudoers.d/asterisk-admin

# Add these lines:
# voip-admin group can manage Asterisk without password for specific commands
%voip-admin ALL=(root) NOPASSWD: /usr/sbin/asterisk -rx *
%voip-admin ALL=(root) NOPASSWD: /bin/systemctl restart asterisk
%voip-admin ALL=(root) NOPASSWD: /bin/systemctl status asterisk
```

## Monitoring and Alerts

### Real-time Monitoring Script

```bash
#!/bin/bash
# /usr/local/bin/asterisk-security-monitor.sh

LOG_FILE="/var/log/asterisk/full"
ALERT_EMAIL="admin@yourdomain.com"
THRESHOLD_FAILED_AUTH=5

# Monitor for failed authentication attempts
FAILED_AUTHS=$(tail -1000 "$LOG_FILE" | grep -c "failed to authenticate")

if [ "$FAILED_AUTHS" -gt "$THRESHOLD_FAILED_AUTH" ]; then
    echo "WARNING: $FAILED_AUTHS failed authentication attempts detected in last 1000 log lines" | \
        mail -s "Asterisk Security Alert - $(hostname)" "$ALERT_EMAIL"
    
    # Extract attacking IPs
    tail -1000 "$LOG_FILE" | grep "failed to authenticate" | \
        grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -rn | \
        head -10 > /tmp/attacking_ips.txt
    
    # Optionally auto-block with iptables
    # while read count ip; do
    #     if [ "$count" -gt 3 ]; then
    #         iptables -A INPUT -s "$ip" -j DROP
    #         echo "Blocked $ip (${count} attempts)"
    #     fi
    # done < /tmp/attacking_ips.txt
fi

# Monitor for unusual outbound call patterns
OUTBOUND_CALLS=$(asterisk -rx "core show channels" | grep -c "outbound")
if [ "$OUTBOUND_CALLS" -gt 10 ]; then
    echo "WARNING: Unusually high number of outbound calls: $OUTBOUND_CALLS" | \
        mail -s "Asterisk Toll Fraud Alert - $(hostname)" "$ALERT_EMAIL"
fi
```

Add to cron:
```bash
# Run every 5 minutes
*/5 * * * * /usr/local/bin/asterisk-security-monitor.sh
```

### Intrusion Detection with SNGREP

```bash
# Install sngrep for SIP packet analysis
sudo apt-get install sngrep

# Monitor suspicious SIP traffic
sudo sngrep -d any port 5060
```

## Best Practices

### 1. Regular Updates

```bash
#!/bin/bash
# Keep system and Asterisk updated

# System updates
sudo apt-get update
sudo apt-get upgrade -y

# Update SIP ALG Checker
cd /opt/Sip-ALG-checker
git pull
```

### 2. Strong Passwords

- Use passwords with minimum 20 characters
- Include uppercase, lowercase, numbers, and special characters
- Use different passwords for each SIP account
- Rotate passwords every 90 days
- Never use default passwords

### 3. Network Segmentation

```
Internet
    |
[Firewall] <- Only allow 5060, 10000-20000
    |
[Asterisk Server] (193.105.36.4)
    |
[Internal Network] <- Trusted devices only
```

### 4. Backup and Recovery

```bash
#!/bin/bash
# Backup Asterisk configuration

BACKUP_DIR="/backup/asterisk/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup configs
tar -czf "$BACKUP_DIR/asterisk-config.tar.gz" /etc/asterisk/

# Backup database (if using)
mysqldump asterisk > "$BACKUP_DIR/asterisk-db.sql"

# Backup voicemail
tar -czf "$BACKUP_DIR/voicemail.tar.gz" /var/spool/asterisk/voicemail/

# Keep only last 30 days
find /backup/asterisk/ -type d -mtime +30 -exec rm -rf {} +
```

### 5. Minimal Services

```bash
# Disable unnecessary services
sudo systemctl disable apache2  # If not needed
sudo systemctl disable cups     # If not needed
sudo systemctl disable bluetooth

# List all running services
sudo systemctl list-units --type=service --state=running
```

### 6. Security Audit Checklist

- [ ] Firewall configured with minimal allowed ports
- [ ] Fail2ban installed and monitoring Asterisk logs
- [ ] SSH hardened (key-based auth, non-standard port)
- [ ] Strong SIP passwords (20+ characters)
- [ ] Guest access disabled in Asterisk
- [ ] Outbound calling restricted by context/dialplan
- [ ] CDR logging enabled and monitored
- [ ] Regular security updates applied
- [ ] Backups configured and tested
- [ ] Monitoring and alerting configured
- [ ] SIP ALG Checker access restricted
- [ ] Log rotation configured
- [ ] Intrusion detection enabled

## Emergency Response

### If Compromised:

1. **Immediately disconnect from Internet**:
   ```bash
   sudo systemctl stop asterisk
   sudo ufw deny out
   ```

2. **Block all SIP traffic**:
   ```bash
   sudo iptables -A INPUT -p udp --dport 5060 -j DROP
   sudo iptables -A INPUT -p tcp --dport 5060 -j DROP
   ```

3. **Review logs**:
   ```bash
   grep -i "failed" /var/log/asterisk/full | tail -100
   asterisk -rx "sip show peers"
   asterisk -rx "core show channels"
   ```

4. **Change all passwords immediately**

5. **Review and block attacking IPs**:
   ```bash
   grep "failed to authenticate" /var/log/asterisk/full | \
       grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -rn
   ```

6. **Contact your VoIP provider** to check for fraudulent charges

## Additional Resources

- [Asterisk Security Guide](https://wiki.asterisk.org/wiki/display/AST/Asterisk+Security)
- [OWASP VoIP Security](https://owasp.org/www-community/vulnerabilities/VoIP_Security)
- [SIP Security Best Practices](https://www.voip-info.org/sip-security/)

## Support

For security concerns specific to the SIP ALG Checker:
1. Review logs in `/var/log/asterisk/sip-alg-checker/`
2. Check permissions on scripts and tools
3. Verify firewall rules are properly configured
4. Monitor for suspicious activity

**Remember**: Security is an ongoing process, not a one-time setup. Regularly review and update your security measures.
