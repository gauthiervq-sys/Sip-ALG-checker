#!/bin/bash
# Start script for SIP ALG Checker Web Interface

echo "========================================="
echo "SIP ALG Checker - Web Interface Startup"
echo "========================================="
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed."
    echo "Please install Python 3 and try again."
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"
echo ""

# Check if pip3 is installed
if ! command -v pip3 &> /dev/null; then
    echo "Error: pip3 is not installed."
    echo "Please install pip3 and try again."
    exit 1
fi

echo "✓ pip3 found"
echo ""

# Install requirements
echo "Installing/updating requirements..."
pip3 install -r requirements.txt

if [ $? -ne 0 ]; then
    echo ""
    echo "Error: Failed to install requirements."
    echo "Please check your internet connection and try again."
    exit 1
fi

echo ""
echo "✓ Requirements installed successfully"
echo ""

# Start the web application
echo "========================================="
echo "Starting Web Application..."
echo "========================================="
echo ""
echo "The web interface will be available at:"
echo "  http://localhost:5000"
echo "  http://127.0.0.1:5000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python3 web_app.py
