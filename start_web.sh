#!/bin/bash
# Startup script for SIP ALG Checker Web Interface

echo "==========================================="
echo "  SIP ALG Checker Web Interface Setup"
echo "==========================================="
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed."
    echo "Please install Python 3 and try again."
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"

# Check if pip is installed
if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null; then
    echo "Error: pip is not installed."
    echo "Please install pip and try again."
    exit 1
fi

echo "✓ pip found"

# Install requirements
echo ""
echo "Installing requirements..."
if python3 -m pip install -r requirements.txt --quiet; then
    echo "✓ Requirements installed successfully"
else
    echo "Error: Failed to install requirements"
    exit 1
fi

# Start the web application
echo ""
echo "==========================================="
echo "  Starting Web Server"
echo "==========================================="
echo ""
echo "The web interface will be available at:"
echo "  http://localhost:5000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python3 web_app.py
