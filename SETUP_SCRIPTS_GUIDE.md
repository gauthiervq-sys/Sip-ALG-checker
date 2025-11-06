# Setup Scripts Guide

This document explains the different setup scripts available in the SIP ALG Checker repository and when to use each one.

## Overview of Setup Scripts

The repository includes several setup scripts for different installation scenarios:

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `all_in_one_setup.sh` | Complete automated setup from scratch | Fresh server, no prior setup |
| `setup-asterisk.sh` | Asterisk-specific setup with security | Existing Asterisk installation |
| `complete_setup.sh` | Completion of partial setup | Partially completed manual setup |
| `secure-asterisk.sh` | Security hardening only | After basic setup is complete |

## Detailed Script Descriptions

### 1. all_in_one_setup.sh

**Purpose**: Complete installation from a fresh system.

**What it does**:
- Installs system dependencies (Python, git, jq, bc, etc.)
- Clones/updates the repository
- Creates log directories
- Installs monitoring scripts
- Adds cron jobs
- Creates AGI scripts
- Configures firewall
- Sets up web dashboard
- Runs initial checks

**Usage**:
```bash
sudo bash all_in_one_setup.sh
```

**When to use**:
- Fresh Linux server
- First-time installation
- Want everything automated
- Don't have any components installed yet

### 2. setup-asterisk.sh

**Purpose**: Setup for existing Asterisk installations with added security.

**What it does**:
- Installs dependencies
- Sets up monitoring
- Configures Fail2ban for Asterisk
- Creates security audit scripts
- Generates firewall templates
- Creates sample configurations

**Usage**:
```bash
cd /opt/Sip-ALG-checker
sudo bash setup-asterisk.sh
```

**When to use**:
- Already have Asterisk installed
- Want security hardening included
- Need Asterisk-specific integration
- Prefer guided setup with templates

### 3. complete_setup.sh ⭐ NEW

**Purpose**: Complete a partially finished setup.

**What it does**:
- Verifies repository is cloned
- Creates log directory (if missing)
- Creates monitoring script (if missing)
- Adds cron job
- Runs initial checks
- **Optionally** creates AGI script (interactive prompt)
- **Optionally** configures firewall (interactive prompt)
- **Optionally** sets up web dashboard (interactive prompt)

**Usage**:
```bash
cd /opt/Sip-ALG-checker
sudo bash complete_setup.sh
```

**When to use**:
- You manually cloned the repository
- You ran some steps from another script but not all
- You want to complete specific components only
- You prefer interactive prompts for optional features

**Interactive Features**:
The script will ask you about:
- AGI script creation (y/n)
- Firewall configuration (y/n)
- Web dashboard setup (y/n)

### 4. secure-asterisk.sh

**Purpose**: Security hardening only.

**What it does**:
- Installs and configures Fail2ban
- Configures UFW firewall
- Creates security configurations
- Sets up password generator
- Creates security audit script
- Restricts file permissions

**Usage**:
```bash
sudo bash secure-asterisk.sh
```

**When to use**:
- After basic setup is complete
- Want to add security to existing installation
- Need to harden an exposed Asterisk server
- Want to prevent toll fraud

## Decision Tree: Which Script to Use?

```
Do you have a fresh server with nothing installed?
├─ YES → Use all_in_one_setup.sh
└─ NO
   │
   Do you have Asterisk already installed?
   ├─ YES → Use setup-asterisk.sh
   └─ NO
      │
      Have you manually done some setup steps?
      ├─ YES → Use complete_setup.sh ⭐
      └─ NO → Use all_in_one_setup.sh

After any setup, if you need security:
└─ Run secure-asterisk.sh
```

## Common Scenarios

### Scenario 1: Fresh Server

You have a brand new Linux server and want everything installed:

```bash
sudo bash all_in_one_setup.sh
```

### Scenario 2: Existing Asterisk Server

You already have Asterisk running and want to add SIP ALG monitoring:

```bash
cd /opt
sudo git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git
cd Sip-ALG-checker
sudo bash setup-asterisk.sh
```

### Scenario 3: Partial Manual Setup

You cloned the repo and created some directories manually, now want to complete setup:

```bash
cd /opt/Sip-ALG-checker
sudo bash complete_setup.sh
```

The script will:
- Check what's already done
- Fill in missing pieces
- Ask about optional components

### Scenario 4: Security Only

You have everything working but need to secure it:

```bash
cd /opt/Sip-ALG-checker
sudo bash secure-asterisk.sh
```

### Scenario 5: Minimal Setup

You only want the core monitoring without optional features:

```bash
# Clone repository
cd /opt
sudo git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git
cd Sip-ALG-checker

# Run completion script and answer "n" to all optional features
sudo bash complete_setup.sh
# When prompted:
# AGI script? n
# Firewall? n
# Web dashboard? n
```

## What Each Script Creates

### File Locations

All scripts follow these conventions:

| Component | Location |
|-----------|----------|
| Repository | `/opt/Sip-ALG-checker/` |
| Logs | `/var/log/asterisk/sip-alg-checker/` |
| Monitoring Script | `/usr/local/bin/asterisk-sip-check.sh` |
| AGI Script | `/var/lib/asterisk/agi-bin/check-sip-alg.py` |
| Cron Job | Root crontab |
| Web Dashboard | `/var/www/html/sip-status/` |
| Security Audit | `/usr/local/bin/asterisk-security-audit.sh` |
| Password Generator | `/usr/local/bin/generate-sip-password.sh` |

### Cron Schedule

All scripts set up the same cron schedule:
```
0 */6 * * * /usr/local/bin/asterisk-sip-check.sh
```
(Runs every 6 hours)

## Upgrading or Re-running Scripts

### Can I run scripts multiple times?

**Yes**, all scripts are idempotent (safe to run multiple times):

- `all_in_one_setup.sh`: Updates repository, recreates scripts
- `setup-asterisk.sh`: Updates configurations, safe to re-run
- `complete_setup.sh`: Checks existing components, only creates missing ones
- `secure-asterisk.sh`: Updates security configurations

### Updating the repository

If you need to update to the latest version:

```bash
cd /opt/Sip-ALG-checker
sudo git pull
```

Then optionally re-run your setup script to update configurations.

## Troubleshooting

### Script fails with "Repository not found"

**Solution**: Clone the repository first:
```bash
cd /opt
sudo git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git
```

### Script fails with "Permission denied"

**Solution**: Run with sudo:
```bash
sudo bash scriptname.sh
```

### Want to undo changes

Each script creates backups with timestamps. Original files are preserved as:
- `filename.bak.YYYYMMDD-HHMMSS`

To remove everything:
```bash
# See COMPLETE_SETUP_README.md for cleanup instructions
```

## Documentation References

For detailed information about each component:

- **Complete Setup**: [COMPLETE_SETUP_README.md](COMPLETE_SETUP_README.md)
- **Asterisk Integration**: [ASTERISK_SETUP.md](ASTERISK_SETUP.md)
- **Security**: [SECURITY.md](SECURITY.md)
- **Beginner Guide**: [BEGINNER_GUIDE.md](BEGINNER_GUIDE.md)
- **Quick Start**: [QUICK_START.md](QUICK_START.md)

## Getting Help

If you're unsure which script to use:

1. **Start with**: Try `complete_setup.sh` - it's the safest option
2. **Check status**: See what's already installed on your system
3. **Read docs**: Review [COMPLETE_SETUP_README.md](COMPLETE_SETUP_README.md)
4. **Ask for help**: Open an issue on GitHub

## Summary

- **New installation**: `all_in_one_setup.sh`
- **Existing Asterisk**: `setup-asterisk.sh`
- **Partial setup**: `complete_setup.sh` ⭐
- **Security only**: `secure-asterisk.sh`

The new `complete_setup.sh` script is specifically designed for the scenario described in the problem statement where some manual steps have been completed and you need to finish the remaining tasks.
