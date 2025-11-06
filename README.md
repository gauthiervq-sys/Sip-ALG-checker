# SIP ALG Checker

A comprehensive, easy-to-use tool for checking SIP ALG (Application Layer Gateway) status and monitoring important VoIP network parameters including Jitter, Packet Loss, and Latency over extended periods.

## Features

- **SIP ALG Detection**: Automatically detects if SIP ALG is interfering with your VoIP traffic
- **Client-Side Test Tool**: Web-based GUI for non-technical users to test SIP ALG from their browser
- **Network Quality Monitoring**: Real-time monitoring of critical VoIP parameters:
  - **Jitter**: Measures variance in packet arrival times
  - **Packet Loss**: Tracks percentage of lost packets
  - **Latency**: Monitors round-trip time (min/avg/max)
  - **Quality Assessment**: Provides overall quality rating
- **Long-term Monitoring**: Support for extended monitoring periods with configurable intervals
- **Easy-to-Use CLI**: Simple command-line interface with clear output
- **Data Export**: Save monitoring results to JSON for further analysis
- **Comprehensive Reports**: Detailed analysis and recommendations
- **Asterisk Integration**: Full support for Asterisk PBX with AGI scripts and automated monitoring

## Special Guides

- **📚 BEGINNER'S GUIDE**: See [BEGINNER_GUIDE.md](BEGINNER_GUIDE.md) - **START HERE** if you're new to Asterisk or Linux
- **🎯 Asterisk PBX Setup**: See [ASTERISK_SETUP.md](ASTERISK_SETUP.md) for complete Asterisk integration
- **⚡ Quick Asterisk Setup (193.105.36.4)**: See [QUICK_SETUP_193.105.36.4.md](QUICK_SETUP_193.105.36.4.md)
- **🔒 Security Guide**: See [SECURITY.md](SECURITY.md) for protecting against toll fraud and unauthorized access
- **🚀 Quick Start**: See [QUICK_START.md](QUICK_START.md) for getting started in 5 minutes
- **✅ Setup Completion**: See [COMPLETE_SETUP_README.md](COMPLETE_SETUP_README.md) for completing partial setup
- **🔧 Setup Scripts Guide**: See [SETUP_SCRIPTS_GUIDE.md](SETUP_SCRIPTS_GUIDE.md) for choosing the right setup script

## 🌐 Client-Side Test Tool

We provide an easy-to-use web-based tool for your clients to test if SIP ALG is active on their network:

### For End Users (Your Clients)

Simply share this URL with your clients: `http://YOUR_SERVER_IP/sip-test.html`

**Features:**
- ✅ Beautiful, user-friendly interface
- ✅ No installation required - works in any web browser
- ✅ Automated connectivity tests to SIP/RTP ports
- ✅ Clear results with actionable recommendations
- ✅ Mobile-friendly responsive design
- ✅ Includes download link for advanced Python script

**Perfect for non-technical users who need to:**
- Check if their router has SIP ALG enabled
- Diagnose VoIP connection issues
- Test connectivity to your VoIP server

### For Server Administrators

The client test page is automatically deployed when you run the setup scripts:

```bash
# Using complete setup
sudo bash complete_setup.sh

# Using all-in-one setup
sudo bash all_in_one_setup.sh
```

Both scripts will offer to deploy the client test page to `/var/www/html/sip-test.html`.

**Manual deployment:**
```bash
# Copy the test page to your web server
sudo cp sip-test.html /var/www/html/

# Verify it's accessible
curl http://YOUR_SERVER_IP/sip-test.html
```

The test page (`sip-test.html`) is a standalone HTML file that can also be:
- Sent directly to clients to open locally
- Hosted on any web server
- Customized for your branding (edit the HTML file)

## Installation

### Prerequisites

- Python 3.6 or higher
- pip (Python package manager)

### Quick Install

```bash
# Clone the repository
git clone https://github.com/gauthiervq-sys/Sip-ALG-checker.git
cd Sip-ALG-checker

# Install dependencies
pip install -r requirements.txt

# Make the script executable (Linux/Mac)
chmod +x sip_alg_checker.py
```

### Optional: Install ping3 for enhanced functionality

```bash
# On Linux, you may need to run with sudo or set capabilities
pip install ping3

# On Linux, to allow non-root ping:
sudo setcap cap_net_raw+ep $(which python3)
```

### Automated Setup for Asterisk Servers

For a complete automated installation on Asterisk servers, use the all-in-one setup script:

```bash
# Download and run the setup script
curl -o /tmp/all_in_one_setup.sh https://raw.githubusercontent.com/gauthiervq-sys/Sip-ALG-checker/main/all_in_one_setup.sh
sudo bash /tmp/all_in_one_setup.sh
```

This script will:
- Install all required dependencies
- Clone or update the repository
- Set up automated monitoring (cron job every 6 hours)
- Create Asterisk AGI integration scripts
- Configure firewall rules for SIP and RTP
- Detect and handle existing Asterisk installations
- Provide comprehensive error messages and guidance

**Features:**
- ✅ Detects if Asterisk is installed and running
- ✅ Checks for port 5060 binding conflicts
- ✅ Safe firewall configuration (no auto-enable to prevent lockout)
- ✅ Clear error messages with troubleshooting steps
- ✅ Works with or without existing Asterisk installation

## ⚠️ Security Warning for Asterisk Servers

If you're running this on an Asterisk server, **protect your server from toll fraud and unauthorized access**:

```bash
# Run the security hardening script
sudo bash secure-asterisk.sh
```

This will configure:
- Firewall with rate limiting
- Fail2ban for SIP protection  
- Secure file permissions
- Strong password requirements
- Outbound calling restrictions

**See [SECURITY.md](SECURITY.md) for complete security guide.**

## Usage

### Check for SIP ALG

Quickly check if SIP ALG is interfering with your VoIP setup:

```bash
python3 sip_alg_checker.py --check-alg
```

**Example Output:**
```
==============================================================
SIP ALG CHECK
==============================================================

Local IP: 192.168.1.100
Timestamp: 2024-11-03T15:30:00

SIP ALG Status: LIKELY

Recommendation:
SIP ALG is likely interfering with your VoIP traffic.
Recommendation: Disable SIP ALG in your router settings.
This typically improves VoIP call quality and reduces connection issues.
```

### Monitor Network Quality

Monitor network quality parameters for a specific duration:

```bash
# Monitor for 60 seconds (default)
python3 sip_alg_checker.py --monitor 8.8.8.8

# Monitor for 5 minutes
python3 sip_alg_checker.py --monitor 8.8.8.8 --duration 300

# Monitor with custom interval (check every 2 seconds)
python3 sip_alg_checker.py --monitor 8.8.8.8 --duration 120 --interval 2
```

**Example Output:**
```
==============================================================
Network Quality Monitor - 2024-11-03T15:30:45
==============================================================
Target: 8.8.8.8
Packets: Sent=30, Received=30
Packet Loss: 0.0%
Latency: Avg=15.2ms, Min=12.5ms, Max=18.9ms
Jitter: 2.3ms
Quality Assessment: EXCELLENT
==============================================================
```

### Save Results to File

Export monitoring results to JSON for analysis:

```bash
python3 sip_alg_checker.py --monitor 8.8.8.8 --duration 300 --output results.json
```

### Combined Check

Check SIP ALG and monitor network quality in one command:

```bash
python3 sip_alg_checker.py --check-alg --monitor 8.8.8.8 --duration 120
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `--check-alg` | Check for SIP ALG interference |
| `--monitor HOST` | Monitor network quality to specified host |
| `--duration SECONDS` | Monitoring duration in seconds (default: 60) |
| `--interval SECONDS` | Monitoring interval in seconds (default: 1) |
| `--output FILE` | Save monitoring results to JSON file |
| `--local-ip IP` | Specify local IP address (auto-detected if not provided) |

## Understanding the Results

### SIP ALG Status

- **UNLIKELY**: No indication of SIP ALG interference
- **POSSIBLE**: SIP ALG may be present; monitor for issues
- **LIKELY**: Strong indication of SIP ALG interference; should be disabled

### Quality Assessment

- **EXCELLENT**: Packet loss < 0.5%, Jitter < 10ms
- **GOOD**: Packet loss < 0.5%, Jitter < 20ms
- **FAIR**: Packet loss < 1%, Jitter < 30ms
- **POOR**: Packet loss > 1% or Jitter > 30ms

### Network Parameters

- **Jitter**: Should be < 30ms for good VoIP quality (ideally < 20ms)
- **Packet Loss**: Should be < 1% for acceptable VoIP (ideally < 0.5%)
- **Latency**: Should be < 150ms for good VoIP quality

## Troubleshooting

### Permission Errors (Linux)

If you get permission errors when running the tool:

```bash
# Option 1: Run with sudo
sudo python3 sip_alg_checker.py --check-alg

# Option 2: Set capabilities (recommended)
sudo setcap cap_net_raw+ep $(which python3)
```

### ping3 Not Available

The tool works without ping3 but with reduced functionality. It will automatically fall back to socket-based testing.

### Connection Refused Errors

If monitoring fails, ensure:
- The target host is reachable
- Firewall rules allow outbound connections
- You have network connectivity

## How to Disable SIP ALG

If SIP ALG is detected, you should disable it in your router:

1. **Access your router**: Open web browser and go to your router's IP (usually 192.168.1.1 or 192.168.0.1)
2. **Login**: Use your router credentials
3. **Find SIP ALG settings**: Look in:
   - Advanced Settings → NAT
   - Firewall → ALG
   - Security → Application Layer Gateway
4. **Disable SIP ALG**: Uncheck or disable the SIP ALG option
5. **Reboot router**: Restart your router for changes to take effect

> **Note**: Router interfaces vary by manufacturer. Consult your router's manual for specific instructions.

## Use Cases

### VoIP Troubleshooting

```bash
# Check if SIP ALG is causing issues
python3 sip_alg_checker.py --check-alg

# Monitor quality during a problematic call
python3 sip_alg_checker.py --monitor YOUR_SIP_SERVER --duration 600
```

### Network Quality Baseline

```bash
# Establish baseline during off-peak hours
python3 sip_alg_checker.py --monitor 8.8.8.8 --duration 3600 --output baseline.json

# Compare during peak hours
python3 sip_alg_checker.py --monitor 8.8.8.8 --duration 3600 --output peak.json
```

### Long-term Monitoring

```bash
# Monitor for 24 hours with 5-minute intervals
python3 sip_alg_checker.py --monitor YOUR_SERVER --duration 86400 --interval 300 --output daily_report.json
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is open source and available under the MIT License.

## Support

For issues, questions, or suggestions, please open an issue on the GitHub repository.