#!/bin/bash
# Start script for SIP ALG Checker Web Interface
# This script installs dependencies and starts the Flask web application

set -e  # Exit on error

echo "================================================"
echo "  SIP ALG Checker - Web Interface Startup"
echo "================================================"
echo ""

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed."
    echo "Please install Python 3 and try again."
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "Error: pip3 is not installed."
    echo "Please install pip3 and try again."
    exit 1
fi

echo "✓ pip3 found"

# Check if requirements are installed
echo ""
echo "Checking dependencies..."

# Function to check if a Python package is installed
check_package() {
    python3 -c "import $1" 2>/dev/null
    return $?
}

INSTALL_NEEDED=0

if ! check_package "flask"; then
    echo "  Flask is not installed"
    INSTALL_NEEDED=1
else
    echo "✓ Flask is installed"
fi

if ! check_package "ping3"; then
    echo "  ping3 is not installed (optional but recommended)"
    INSTALL_NEEDED=1
else
    echo "✓ ping3 is installed"
fi

# Install dependencies if needed
if [ $INSTALL_NEEDED -eq 1 ]; then
    echo ""
    echo "Installing missing dependencies..."
    pip3 install -r requirements.txt
    echo "✓ Dependencies installed"
fi

# Parse command line arguments
HOST="0.0.0.0"
PORT="5000"
DEBUG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            HOST="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --debug)
            DEBUG="--debug"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --host HOST    Host to bind to (default: 0.0.0.0)"
            echo "  --port PORT    Port to bind to (default: 5000)"
            echo "  --debug        Run in debug mode"
            echo "  -h, --help     Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo ""
echo "================================================"
echo "  Starting Web Interface"
echo "================================================"
echo ""
echo "  Host: $HOST"
echo "  Port: $PORT"
echo ""

if [ "$HOST" = "0.0.0.0" ]; then
    echo "  Access the web interface at:"
    echo "    - http://localhost:$PORT"
    echo "    - http://127.0.0.1:$PORT"
    
    # Try to get local IP
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$LOCAL_IP" ]; then
        echo "    - http://$LOCAL_IP:$PORT"
    fi
else
    echo "  Access the web interface at:"
    echo "    - http://$HOST:$PORT"
fi

echo ""
echo "  Press Ctrl+C to stop the server"
echo ""
echo "================================================"
echo ""

# Start the web application
python3 web_app.py --host "$HOST" --port "$PORT" $DEBUG
