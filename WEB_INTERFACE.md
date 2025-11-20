# SIP ALG Checker - Web Interface

A user-friendly web interface for the SIP ALG Checker tool, making it easy to check for SIP ALG interference and monitor network quality without using the command line.

## Features

- 🔍 **SIP ALG Status Check**: One-click checking for SIP ALG interference with detailed results
- 📊 **Network Quality Monitor**: Real-time monitoring of latency, jitter, and packet loss
- 🎨 **Modern UI**: Clean, responsive design with gradient background
- ⚡ **Dynamic Updates**: Real-time monitoring updates using AJAX
- 🔒 **Thread-Safe**: Proper synchronization for concurrent operations
- 🚀 **Easy Deployment**: Simple start script handles all dependencies

## Quick Start

### 1. Start the Web Interface

The easiest way to start the web interface is using the provided script:

```bash
./start_web.sh
```

This will:
- Check for Python 3 and pip
- Install missing dependencies (Flask, ping3)
- Start the web server on port 5000

### 2. Access the Interface

Once started, open your web browser and navigate to:
- http://localhost:5000
- http://127.0.0.1:5000
- Or the IP address shown in the terminal

### 3. Use the Features

#### Check SIP ALG Status
1. Optionally enter your local IP address (auto-detected if left empty)
2. Click "Check SIP ALG Status"
3. View detailed results including:
   - SIP ALG detection status (LIKELY, POSSIBLE, UNLIKELY)
   - SIP port availability
   - RTP port range check
   - NAT behavior analysis
   - Recommendations

#### Monitor Network Quality
1. Enter the target host (default: 8.8.8.8)
2. Set duration in seconds (default: 60)
3. Set interval in seconds (default: 1)
4. Click "Start Network Monitor"
5. View real-time statistics:
   - Packets sent/received
   - Packet loss percentage
   - Average/min/max latency
   - Jitter measurements
   - Quality assessment (EXCELLENT, GOOD, FAIR, POOR)

## Advanced Usage

### Custom Host and Port

```bash
./start_web.sh --host 0.0.0.0 --port 8080
```

Options:
- `--host HOST`: Host to bind to (default: 0.0.0.0)
- `--port PORT`: Port to bind to (default: 5000)
- `--debug`: Run in debug mode
- `-h, --help`: Show help message

### Running Directly with Python

```bash
python3 web_app.py --host 127.0.0.1 --port 5000
```

### Running in Debug Mode

```bash
./start_web.sh --debug
```

## Requirements

- Python 3.6 or higher
- Flask 2.0.0 or higher
- ping3 4.0.0 or higher (optional, recommended)

Dependencies are automatically installed when using `start_web.sh`.

## API Endpoints

The web application provides the following REST API endpoints:

### GET `/`
Main dashboard page

### POST `/api/check-alg`
Check for SIP ALG interference

**Request Body:**
```json
{
  "local_ip": "192.168.1.100"  // optional
}
```

**Response:**
```json
{
  "success": true,
  "results": {
    "local_ip": "192.168.1.100",
    "sip_alg_detected": "UNLIKELY",
    "recommendation": "...",
    "checks_performed": [...]
  }
}
```

### POST `/api/monitor`
Start network monitoring

**Request Body:**
```json
{
  "target_host": "8.8.8.8",
  "duration": 60,
  "interval": 1
}
```

**Response:**
```json
{
  "success": true,
  "message": "Monitoring started for 8.8.8.8",
  "duration": 60,
  "interval": 1
}
```

### GET `/api/monitor/status`
Get current monitoring status and results

**Response:**
```json
{
  "running": true,
  "stats": {
    "target": "8.8.8.8",
    "packets_sent": 30,
    "packets_received": 30,
    "packet_loss_percent": 0.0,
    "avg_latency_ms": 15.2,
    "min_latency_ms": 12.5,
    "max_latency_ms": 18.9,
    "jitter_ms": 2.3
  },
  "error": null
}
```

### POST `/api/monitor/stop`
Stop the running monitor

**Response:**
```json
{
  "success": true,
  "message": "Monitoring stopped"
}
```

## Troubleshooting

### Port Already in Use

If port 5000 is already in use:
```bash
./start_web.sh --port 8080
```

### Permission Errors

Network monitoring requires certain permissions:

**On Linux:**
```bash
# Option 1: Run with sudo
sudo ./start_web.sh

# Option 2: Set capabilities (recommended)
sudo setcap cap_net_raw+ep $(which python3)
```

**On macOS:**
```bash
sudo ./start_web.sh
```

### Missing Dependencies

If dependencies are not installed:
```bash
pip3 install -r requirements.txt
```

### Cannot Access from Other Devices

Make sure to bind to 0.0.0.0:
```bash
./start_web.sh --host 0.0.0.0
```

And ensure your firewall allows connections on the chosen port.

## Security Considerations

- The web interface is intended for **development and internal use only**
- Do not expose to the public internet without proper security measures
- Consider using a production WSGI server (e.g., Gunicorn, uWSGI) for production deployments
- Implement authentication if deploying in a shared environment

### Production Deployment Example

For production, use Gunicorn:

```bash
pip3 install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 web_app:app
```

## Architecture

### Backend (Flask)
- `web_app.py`: Main Flask application
  - Serves HTML templates
  - Provides REST API endpoints
  - Manages background monitoring thread with thread-safe operations

### Frontend (Vanilla JavaScript)
- `templates/index.html`: Single-page application
  - AJAX requests for dynamic updates
  - Real-time monitoring status polling
  - Responsive design with CSS3

### Data Flow
1. User clicks button in browser
2. JavaScript sends AJAX request to Flask API
3. Flask processes request using `sip_alg_checker.py` functions
4. For monitoring: Background thread runs and updates shared state
5. Frontend polls for status updates
6. Results displayed dynamically without page reload

## Contributing

Contributions are welcome! Please ensure:
- Code follows existing style
- All tests pass
- Thread safety is maintained
- Security best practices are followed

## License

This project is open source and available under the MIT License.

## Support

For issues, questions, or suggestions, please open an issue on the GitHub repository.
