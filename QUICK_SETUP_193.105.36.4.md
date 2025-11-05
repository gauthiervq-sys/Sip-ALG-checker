# Quick Setup Guide for Asterisk Server 193.105.36.4

This is a streamlined setup guide specifically for your Asterisk server.

## 🚀 One-Command Setup

Run this on your Asterisk server (193.105.36.4):

```bash
curl -sSL https://raw.githubusercontent.com/gauthiervq-sys/Sip-ALG-checker/main/setup-asterisk.sh | sudo bash
```

Or download and run manually:

```bash
wget https://raw.githubusercontent.com/gauthiervq-sys/Sip-ALG-checker/main/setup-asterisk.sh
sudo bash setup-asterisk.sh
```

## 📋 What Gets Installed

- **SIP ALG Checker**: `/opt/Sip-ALG-checker/`
- **Monitoring Script**: `/usr/local/bin/asterisk-sip-check.sh`
- **AGI Script**: `/var/lib/asterisk/agi-bin/check-sip-alg.py`
- **Log Directory**: `/var/log/asterisk/sip-alg-checker/`
- **Cron Job**: Automatic checks every 6 hours

## ⚙️ Asterisk Configuration

### Step 1: Configure External IP

**For PJSIP** (edit `/etc/asterisk/pjsip.conf`):
```ini
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=193.105.36.4
external_signaling_address=193.105.36.4
```

**For chan_sip** (edit `/etc/asterisk/sip.conf`):
```ini
[general]
externip=193.105.36.4
nat=force_rport,comedia
directmedia=no
```

### Step 2: Configure RTP Ports

Edit `/etc/asterisk/rtp.conf`:
```ini
[general]
rtpstart=10000
rtpend=20000
```

### Step 3: Reload Asterisk

```bash
asterisk -rx "core reload"
```

## 🔍 Testing

### From Your Server (193.105.36.4)

```bash
# Check SIP ALG status
cd /opt/Sip-ALG-checker
python3 sip_alg_checker.py --check-alg

# Check if ports are open
netstat -tulpn | grep 5060
netstat -tulpn | grep -E "1[0-9]{4}"
```

### From Remote Clients

Have your SIP clients run:

```bash
# Check their local network for SIP ALG
python3 sip_alg_checker.py --check-alg

# Test connection quality to your server
python3 sip_alg_checker.py --monitor 193.105.36.4 --duration 300

# Full diagnostic with export
python3 sip_alg_checker.py --check-alg --monitor 193.105.36.4 \
  --duration 600 --output results.json
```

## 📊 Monitoring

### View Logs

```bash
# List all checks
ls -la /var/log/asterisk/sip-alg-checker/

# View latest ALG check
cat $(ls -t /var/log/asterisk/sip-alg-checker/alg-check-*.log | head -1)

# View latest quality report (formatted)
cat $(ls -t /var/log/asterisk/sip-alg-checker/quality-*.json | head -1) | jq .

# View monitoring log
tail -f /var/log/asterisk/sip-alg-checker/monitor.log
```

### Run Manual Check

```bash
/usr/local/bin/asterisk-sip-check.sh
```

### Check Cron Schedule

```bash
crontab -l | grep asterisk-sip-check
```

## 🔧 Asterisk Dialplan Integration (Optional)

Add to `/etc/asterisk/extensions.conf`:

```ini
[macro-check-sip-alg]
; Check SIP ALG before calls
exten => s,1,NoOp(Checking SIP ALG Status)
 same => n,AGI(check-sip-alg.py)
 same => n,NoOp(SIP ALG Status: ${SIPALG_STATUS})
 same => n,Return()

[from-internal]
; Example: Check on outbound calls
exten => _X.,1,Macro(check-sip-alg)
 same => n,Dial(SIP/${EXTEN}@your-trunk)
 same => n,Hangup()
```

Then reload:
```bash
asterisk -rx "dialplan reload"
```

## 🔥 Firewall Rules

Make sure these ports are open:

```bash
# UFW
sudo ufw allow 5060/udp comment 'SIP'
sudo ufw allow 5060/tcp comment 'SIP'
sudo ufw allow 10000:20000/udp comment 'RTP'

# Or iptables
sudo iptables -A INPUT -p udp --dport 5060 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5060 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 10000:20000 -j ACCEPT
```

## 🎯 Quality Thresholds

| Metric | Good | Fair | Poor |
|--------|------|------|------|
| **Jitter** | < 10ms | 10-30ms | > 30ms |
| **Packet Loss** | < 0.5% | 0.5-1% | > 1% |
| **Latency** | < 50ms | 50-150ms | > 150ms |

## ❗ Common Issues

### Issue: SIP ALG Status = LIKELY

**Fix**: Client must disable SIP ALG on their router
1. Access router admin (usually 192.168.1.1)
2. Find NAT/Firewall/ALG settings
3. Disable SIP ALG
4. Reboot router

### Issue: One-Way Audio

**Fix in Asterisk**:
```ini
nat=force_rport,comedia
directmedia=no
```

### Issue: High Jitter/Packet Loss

**Fix**:
- Enable QoS on router (prioritize UDP 5060, 10000-20000)
- Check internet connection stability
- Test during off-peak hours

## 📞 Testing Calls

### From Asterisk CLI

```bash
# Check SIP peers
asterisk -rx "sip show peers"

# Or for PJSIP
asterisk -rx "pjsip show endpoints"

# Check active calls
asterisk -rx "core show channels"
```

### Monitor SIP Traffic

```bash
# Watch SIP packets
sudo tcpdump -i any -n port 5060

# Watch RTP packets
sudo tcpdump -i any -n 'udp and portrange 10000-20000'
```

## 🆘 Getting Help

If you encounter issues:

1. **Collect diagnostic info**:
   ```bash
   python3 /opt/Sip-ALG-checker/sip_alg_checker.py --check-alg --monitor 193.105.36.4 \
     --duration 600 --output /tmp/diagnostic.json
   ```

2. **Check Asterisk logs**:
   ```bash
   tail -100 /var/log/asterisk/full
   ```

3. **Review SIP ALG logs**:
   ```bash
   cat $(ls -t /var/log/asterisk/sip-alg-checker/*.log | head -1)
   ```

4. **Share the diagnostic.json file** for analysis

## 📚 Additional Resources

- **Full Documentation**: `/opt/Sip-ALG-checker/ASTERISK_SETUP.md`
- **Quick Start**: `/opt/Sip-ALG-checker/QUICK_START.md`
- **General README**: `/opt/Sip-ALG-checker/README.md`
- **Example Usage**: `/opt/Sip-ALG-checker/example_usage.py`

## 🔄 Updates

Update the checker to latest version:

```bash
cd /opt/Sip-ALG-checker
git pull
```

## ✅ Setup Checklist

- [ ] Run setup script on 193.105.36.4
- [ ] Configure external IP in Asterisk
- [ ] Configure RTP ports (10000-20000)
- [ ] Open firewall ports
- [ ] Reload Asterisk configuration
- [ ] Test from server: `python3 sip_alg_checker.py --check-alg`
- [ ] Test from client: `python3 sip_alg_checker.py --monitor 193.105.36.4`
- [ ] Verify cron job: `crontab -l`
- [ ] Review logs after 6 hours
- [ ] Have clients test and report results

---

**Your Server**: 193.105.36.4  
**Platform**: Asterisk PBX  
**Support**: See ASTERISK_SETUP.md for detailed help
