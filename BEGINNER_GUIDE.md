# Complete Beginner's Guide to SIP ALG Checker & Asterisk Security

This guide is for users with **basic Asterisk and Linux knowledge**. We'll walk through everything step-by-step, explaining what each command does and why.

## 📋 Table of Contents

1. [What You'll Learn](#what-youll-learn)
2. [Prerequisites](#prerequisites)
3. [Understanding SIP ALG](#understanding-sip-alg)
4. [Part 1: Basic Installation](#part-1-basic-installation)
5. [Part 2: Testing the Tool](#part-2-testing-the-tool)
6. [Part 3: Asterisk Integration](#part-3-asterisk-integration)
7. [Part 4: Security Setup](#part-4-security-setup)
8. [Part 5: Testing Everything](#part-5-testing-everything)
9. [Troubleshooting](#troubleshooting)
10. [Glossary](#glossary)

---

## What You'll Learn

By the end of this guide, you will:
- ✅ Understand what SIP ALG is and why it's a problem
- ✅ Install and use the SIP ALG Checker tool
- ✅ Integrate it with your Asterisk server
- ✅ Secure your Asterisk server against attacks
- ✅ Monitor your VoIP call quality
- ✅ Troubleshoot common issues

**Time Required:** 30-45 minutes

---

## Prerequisites

### What You Need

1. **An Asterisk server** (any version 11+)
   - You should know how to log into it via SSH
   - You should have `sudo` (admin) access

2. **Basic Linux command knowledge**
   - How to use `cd` to change directories
   - How to edit files with `nano` or `vi`
   - How to run commands with `sudo`

3. **Your server's public IP address**
   - Example: 193.105.36.4
   - Find it with: `curl ifconfig.me`

4. **Internet connection** on your server

### Verify Your Access

First, let's make sure you can access your server:

```bash
# Connect to your server (replace with your details)
ssh your-username@your-server-ip

# Check if you have sudo access
sudo whoami
# Should print: root

# Check if Asterisk is installed
asterisk -V
# Should show Asterisk version
```

✅ **If all these work, you're ready to continue!**

---

## Understanding SIP ALG

### What is SIP ALG?

**SIP ALG** stands for "SIP Application Layer Gateway". It's a feature in many routers that tries to "help" with VoIP calls but usually causes more problems than it solves.

### Problems SIP ALG Causes:

- ❌ **One-way audio**: You can hear them, but they can't hear you (or vice versa)
- ❌ **Dropped calls**: Calls disconnect randomly
- ❌ **Registration failures**: Your phones can't register to Asterisk
- ❌ **Echo or audio quality issues**

### The Solution:

1. **Detect** if SIP ALG is interfering (this tool helps with that)
2. **Disable** SIP ALG in the router
3. **Configure** Asterisk correctly to work without SIP ALG

---

## Part 1: Basic Installation

### Step 1: Connect to Your Server

```bash
# Replace with your actual details
ssh your-username@193.105.36.4
```

### Step 2: Become Root

Most installation commands need admin privileges:

```bash
# Become root user
sudo su -

# You should see your prompt change to show you're root
# Example: root@server:~#
```

### Step 3: Download the Tool

```bash
# Go to the /opt directory (where optional software is stored)
cd /opt

# Download the SIP ALG Checker from GitHub
git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git

# Enter the directory
cd Sip-ALG-checker

# List what's inside
ls -lh
```

You should see files like:
- `sip_alg_checker.py` - The main tool
- `setup-asterisk.sh` - Automated setup script
- `secure-asterisk.sh` - Security script
- `README.md` - Documentation

### Step 4: Install Python (if needed)

The tool needs Python 3:

```bash
# Check if Python 3 is installed
python3 --version

# If not installed, install it
apt-get update
apt-get install -y python3 python3-pip
```

### Step 5: Install Dependencies

```bash
# Install required Python packages
pip3 install -r requirements.txt

# Make the main script executable
chmod +x sip_alg_checker.py
```

✅ **Installation complete!** The tool is now ready to use.

---

## Part 2: Testing the Tool

Let's test that everything works before integrating with Asterisk.

### Test 1: Check for SIP ALG Locally

This checks if SIP ALG is affecting YOUR server:

```bash
# Run the SIP ALG check
python3 sip_alg_checker.py --check-alg
```

**What you'll see:**

```
============================================================
SIP ALG CHECK
============================================================

Local IP: 193.105.36.4
Timestamp: 2024-11-04T15:00:00

SIP ALG Status: UNLIKELY

Recommendation:
No strong indication of SIP ALG interference detected.

Detailed Checks:

  • SIP Port (5060) Availability
    Checks if SIP port 5060 is accessible
    Status: PASS
```

**Understanding the Results:**

- **UNLIKELY**: Your server itself is fine (SIP ALG might be on client routers)
- **POSSIBLE**: Keep an eye on it
- **LIKELY**: There's a problem - SIP ALG may be interfering

### Test 2: Check Network Quality

This tests the connection quality to your server:

```bash
# Monitor for 30 seconds (replace 193.105.36.4 with your IP)
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 30
```

**What you'll see:**

```
============================================================
Network Quality Monitor - 2024-11-04T15:01:00
============================================================
Target: 193.105.36.4
Packets: Sent=10, Received=10
Packet Loss: 0.0%
Latency: Avg=15.2ms, Min=12.5ms, Max=18.9ms
Jitter: 2.3ms
Quality Assessment: EXCELLENT
```

**Understanding the Results:**

- **Packet Loss**: Should be < 1% (lower is better)
- **Jitter**: Should be < 30ms (lower is better)
- **Latency**: Should be < 150ms (lower is better)
- **Quality**:
  - **EXCELLENT**: Perfect for VoIP
  - **GOOD**: Acceptable for VoIP
  - **FAIR**: May have minor issues
  - **POOR**: Not suitable for VoIP

✅ **If tests work, move on to Asterisk integration!**

---

## Part 3: Asterisk Integration

Now let's integrate the tool with your Asterisk server.

### Step 1: Run the Automated Setup

This script installs everything automatically:

```bash
# Make sure you're in the tool directory
cd /opt/Sip-ALG-checker

# Run the setup script
sudo bash setup-asterisk.sh
```

**What the script does:**

1. Installs dependencies (git, jq, bc, etc.)
2. Creates monitoring scripts
3. Sets up a cron job (runs checks every 6 hours)
4. Creates an AGI script for Asterisk dialplan
5. Creates log directory
6. Runs an initial check

**Wait for it to complete** - this takes 2-5 minutes.

### Step 2: Configure Your Asterisk

Now we need to tell Asterisk about your public IP address.

#### For PJSIP (Asterisk 13+):

```bash
# Edit the PJSIP configuration
nano /etc/asterisk/pjsip.conf
```

**Find the `[transport-udp]` section and add/modify:**

```ini
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
; CHANGE THIS TO YOUR PUBLIC IP:
external_media_address=193.105.36.4
external_signaling_address=193.105.36.4
```

**Save the file:**
- Press `Ctrl+X`
- Press `Y` to confirm
- Press `Enter` to save

#### For chan_sip (older Asterisk):

```bash
# Edit the SIP configuration
nano /etc/asterisk/sip.conf
```

**Find the `[general]` section and add/modify:**

```ini
[general]
; CHANGE THIS TO YOUR PUBLIC IP:
externip=193.105.36.4
nat=force_rport,comedia
directmedia=no
```

**Save the file** (same as above: Ctrl+X, Y, Enter)

### Step 3: Configure RTP Ports

RTP carries the actual voice data. Let's configure the port range:

```bash
# Edit RTP configuration
nano /etc/asterisk/rtp.conf
```

**Add or modify:**

```ini
[general]
rtpstart=10000
rtpend=20000
strictrtp=yes
```

**Save the file.**

### Step 4: Reload Asterisk

Now tell Asterisk to use the new configuration:

```bash
# Connect to Asterisk
asterisk -rvvv

# Inside Asterisk console, reload configuration:
core reload

# Exit Asterisk console
exit
```

**Or reload from command line:**

```bash
asterisk -rx "core reload"
```

✅ **Asterisk integration complete!**

---

## Part 4: Security Setup

**⚠️ IMPORTANT:** Without security, your server can be hacked and used to make expensive international calls (toll fraud). This could cost you thousands of dollars!

### Step 1: Run the Security Script

```bash
# Make sure you're in the tool directory
cd /opt/Sip-ALG-checker

# Run the security hardening script
sudo bash secure-asterisk.sh
```

**The script will ask you questions:**

1. **Continue? (y/n)**: Type `y` and press Enter
2. **Enter SSH port**: 
   - If you use the default SSH port, type `22` and press Enter
   - If you changed it, enter your custom port

**What the script does:**

1. ✅ Installs firewall (UFW)
2. ✅ Installs Fail2ban (blocks attackers)
3. ✅ Creates secure Asterisk configurations
4. ✅ Sets up monitoring for attacks
5. ✅ Creates security audit script

**Wait for completion** - takes 3-5 minutes.

### Step 2: Review Security Configuration

The script created secure configuration templates. Let's integrate them:

```bash
# View the sample security config
cat /tmp/asterisk-sip-alg-config.txt
```

#### Add Security to PJSIP:

```bash
# Edit PJSIP config
nano /etc/asterisk/pjsip.conf
```

**Add this line at the TOP of the file:**

```ini
#include pjsip-security.conf
```

**Save the file.**

#### Add Security to Dialplan:

```bash
# Edit dialplan
nano /etc/asterisk/extensions.conf
```

**Add this line at the TOP of the file:**

```ini
#include extensions-security.conf
```

**Important:** Now edit the security config to set which countries you allow:

```bash
# Edit the security dialplan
nano /etc/asterisk/extensions-security.conf
```

**Find this line:**

```ini
ALLOWED_COUNTRY_CODES=1|31|32|33|49|44
```

**Modify it for your needs:**
- `1` = USA/Canada
- `31` = Netherlands
- `32` = Belgium  
- `33` = France
- `44` = United Kingdom
- `49` = Germany

**Example:** If you only want to allow calls to Netherlands and Belgium:

```ini
ALLOWED_COUNTRY_CODES=31|32
```

**Save the file.**

#### Disable Guest Access:

```bash
# For PJSIP
nano /etc/asterisk/pjsip.conf
```

**In the `[global]` section, add:**

```ini
[global]
type=global
max_calls=50
; Add this line:
user_agent=Asterisk PBX
```

**For chan_sip:**

```bash
nano /etc/asterisk/sip.conf
```

**In the `[general]` section, add:**

```ini
[general]
allowguest=no
alwaysauthreject=yes
```

**Save the file.**

### Step 3: Generate Strong Passwords

Never use weak passwords! Let's generate strong ones:

```bash
# Run the password generator
/usr/local/bin/generate-sip-password.sh
```

**You'll see something like:**

```
Generating strong SIP credentials...
==================================
Username: user1
Password: xK9mL2nQ4pR7sT3vW8yB
---
Username: user2
Password: aB5cD8eF2gH4iJ7kL9mN
---
```

**Write these down securely!** You'll use them for your SIP phones.

### Step 4: Reload Asterisk with Security

```bash
# Reload everything
asterisk -rx "core reload"

# Check that it loaded without errors
asterisk -rx "core show channels"
```

### Step 5: Run Security Audit

Let's verify everything is secure:

```bash
# Run the audit
/usr/local/bin/asterisk-security-audit.sh
```

**You should see:**

```
╔════════════════════════════════════════════════════════════╗
║            ASTERISK SECURITY AUDIT                         ║
╚════════════════════════════════════════════════════════════╝

1. Firewall Status:
   ✓ UFW is active

2. Fail2ban Status:
   ✓ Fail2ban is running
   Currently banned IPs: 0

3. Guest Access:
   ✓ Guest access is disabled

4. Password Security:
   ✓ No obviously weak passwords found

5. Recent Failed Authentication:
   Last 100 log entries: 0 failed attempts

6. SSH Security:
   ✓ Root login disabled
```

**All checks should pass (✓).**

✅ **Security setup complete!**

---

## Part 5: Testing Everything

Now let's test that everything works together.

### Test 1: Check Firewall

```bash
# Check firewall status
sudo ufw status verbose
```

**You should see:**

```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     LIMIT       Anywhere
5060/tcp                   LIMIT       Anywhere
5060/udp                   LIMIT       Anywhere
10000:20000/udp            ALLOW       Anywhere
```

### Test 2: Check Fail2ban

```bash
# Check Fail2ban status
sudo fail2ban-client status asterisk
```

**You should see:**

```
Status for the jail: asterisk
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
|  `- File list:        /var/log/asterisk/full
`- Actions
   |- Currently banned: 0
   |- Total banned:     0
   `- Banned IP list:
```

### Test 3: Check Monitoring

```bash
# Run a manual check
/usr/local/bin/asterisk-sip-check.sh

# View the logs
ls -lh /var/log/asterisk/sip-alg-checker/

# View the latest log
tail -20 /var/log/asterisk/sip-alg-checker/monitor.log
```

### Test 4: Check Cron Job

The tool should run automatically every 6 hours:

```bash
# View cron jobs
crontab -l | grep asterisk
```

**You should see:**

```
0 */6 * * * /usr/local/bin/asterisk-sip-check.sh
```

### Test 5: Test from a Client

On a computer/phone that connects to your Asterisk server:

```bash
# If you installed the tool on client machines
python3 sip_alg_checker.py --check-alg

# Test connection to your server
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 60
```

### Test 6: Make a Test Call

1. Register a SIP phone to your Asterisk server
2. Use one of the strong passwords you generated
3. Make a test call
4. Check the call quality

**To view active calls:**

```bash
asterisk -rx "core show channels"
```

**To view SIP registrations:**

```bash
# For PJSIP
asterisk -rx "pjsip show endpoints"

# For chan_sip
asterisk -rx "sip show peers"
```

✅ **If calls work and quality is good, you're all set!**

---

## Troubleshooting

### Problem: "Permission denied" errors

**Solution:**

```bash
# Make sure you're running as root
sudo su -

# Or add sudo before commands
sudo python3 sip_alg_checker.py --check-alg
```

### Problem: "git: command not found"

**Solution:**

```bash
# Install git
sudo apt-get update
sudo apt-get install -y git
```

### Problem: "python3: command not found"

**Solution:**

```bash
# Install Python 3
sudo apt-get update
sudo apt-get install -y python3 python3-pip
```

### Problem: Firewall blocks everything

**Solution:**

```bash
# Check if UFW is blocking too much
sudo ufw status numbered

# If you locked yourself out via SSH, use the server console
# Temporarily disable UFW
sudo ufw disable

# Re-add SSH rule
sudo ufw allow 22/tcp

# Re-enable UFW
sudo ufw enable
```

### Problem: Asterisk won't reload

**Solution:**

```bash
# Check Asterisk status
sudo systemctl status asterisk

# View Asterisk logs for errors
sudo tail -50 /var/log/asterisk/full

# Check configuration syntax
sudo asterisk -rx "core show config"
```

### Problem: Phones can't register

**Causes and Solutions:**

1. **Firewall blocking**: Check `sudo ufw status` - port 5060 should be open
2. **Wrong password**: Use the strong passwords from generator
3. **NAT issues**: Make sure `externip` is set to your public IP
4. **SIP ALG on client router**: Disable it in the client's router

**Debug registration:**

```bash
# Watch Asterisk log in real-time
sudo tail -f /var/log/asterisk/full | grep REGISTER
```

### Problem: One-way audio

**Solution:**

```bash
# Edit PJSIP config
sudo nano /etc/asterisk/pjsip.conf
```

**Make sure you have:**

```ini
direct_media=no
rtp_symmetric=yes
force_rport=yes
```

**Reload Asterisk:**

```bash
sudo asterisk -rx "core reload"
```

### Problem: High CPU usage

**Solution:**

```bash
# Check what's running
top

# If fail2ban is using too much CPU, adjust settings
sudo nano /etc/fail2ban/jail.d/asterisk.conf

# Reduce checking frequency
findtime = 1200
```

### Getting Help

If you're still stuck:

1. **Check the logs:**
   ```bash
   sudo tail -100 /var/log/asterisk/full
   tail -50 /var/log/asterisk/sip-alg-checker/monitor.log
   ```

2. **Run the security audit:**
   ```bash
   /usr/local/bin/asterisk-security-audit.sh
   ```

3. **Read the detailed guides:**
   - `/opt/Sip-ALG-checker/SECURITY.md`
   - `/opt/Sip-ALG-checker/ASTERISK_SETUP.md`

---

## Glossary

**Terms you should know:**

- **SIP**: Session Initiation Protocol - the protocol used to set up VoIP calls
- **RTP**: Real-time Transport Protocol - carries the actual voice audio
- **ALG**: Application Layer Gateway - a router feature that modifies SIP traffic
- **Jitter**: Variation in packet arrival times - causes choppy audio
- **Packet Loss**: Dropped network packets - causes audio gaps
- **NAT**: Network Address Translation - how routers share one public IP
- **Firewall**: Security system that controls network traffic
- **Fail2ban**: Tool that blocks IP addresses after failed login attempts
- **PJSIP**: Modern SIP stack in Asterisk (version 13+)
- **chan_sip**: Older SIP stack in Asterisk (being deprecated)
- **AGI**: Asterisk Gateway Interface - lets scripts interact with Asterisk
- **Dialplan**: Asterisk's call routing configuration
- **Context**: Section in Asterisk dialplan that groups extensions
- **Extension**: Phone number or pattern in Asterisk
- **Trunk**: Connection from Asterisk to external phone provider
- **Codec**: Audio compression format (e.g., ulaw, alaw, g722)
- **SSH**: Secure Shell - encrypted way to access server remotely
- **Sudo**: Command to run something as administrator
- **Cron**: System for scheduling automatic tasks

---

## Quick Reference Commands

### Daily Use Commands

```bash
# Check Asterisk status
sudo systemctl status asterisk

# Restart Asterisk
sudo systemctl restart asterisk

# View live Asterisk log
sudo tail -f /var/log/asterisk/full

# Check active calls
asterisk -rx "core show channels"

# Check registered phones (PJSIP)
asterisk -rx "pjsip show endpoints"

# Check registered phones (chan_sip)
asterisk -rx "sip show peers"

# Run SIP ALG check
cd /opt/Sip-ALG-checker
python3 sip_alg_checker.py --check-alg

# Run security audit
/usr/local/bin/asterisk-security-audit.sh

# Check firewall
sudo ufw status verbose

# Check Fail2ban
sudo fail2ban-client status asterisk

# View monitoring logs
ls -lh /var/log/asterisk/sip-alg-checker/
tail -20 /var/log/asterisk/sip-alg-checker/monitor.log
```

### Weekly Maintenance

```bash
# Update system
sudo apt-get update
sudo apt-get upgrade

# Check disk space
df -h

# Review banned IPs
sudo fail2ban-client status asterisk

# Check for failed logins
grep "failed to authenticate" /var/log/asterisk/full | tail -20
```

---

## Next Steps

Now that you have everything set up:

1. ✅ **Monitor for a week** - Check logs regularly
2. ✅ **Test call quality** - Make test calls at different times
3. ✅ **Review security audit** - Run weekly
4. ✅ **Update system** - Keep software current
5. ✅ **Document your config** - Save your passwords securely
6. ✅ **Train users** - Show them how to check for SIP ALG on their routers

---

## Congratulations! 🎉

You now have:
- ✅ A working SIP ALG checker
- ✅ Asterisk properly configured
- ✅ Strong security protecting your server
- ✅ Automated monitoring
- ✅ Tools to troubleshoot issues

**Your Asterisk server is now professional-grade and secure!**

---

## Support & Resources

- **Full Security Guide**: `/opt/Sip-ALG-checker/SECURITY.md`
- **Asterisk Setup Guide**: `/opt/Sip-ALG-checker/ASTERISK_SETUP.md`
- **Quick Setup Guide**: `/opt/Sip-ALG-checker/QUICK_SETUP_193.105.36.4.md`
- **Asterisk Documentation**: https://wiki.asterisk.org/
- **SIP ALG Information**: https://www.voip-info.org/sip-alg/

**Remember:** Security is an ongoing process. Check your logs, run audits regularly, and keep your system updated!
