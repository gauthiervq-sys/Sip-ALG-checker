#!/bin/bash
# SIP ALG Checker Web Interface Startup Script
# This script installs dependencies and starts the web server

set -e

echo "=================================="
echo "SIP ALG Checker Web Interface"
echo "=================================="
echo ""

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed"
    echo "Please install Python 3.6 or higher"
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if requirements.txt exists
if [ ! -f "requirements.txt" ]; then
    echo "Error: requirements.txt not found"
    exit 1
fi

# Install requirements
echo "Installing dependencies..."
python3 -m pip install --user -r requirements.txt

if [ $? -ne 0 ]; then
    echo ""
    echo "Error: Failed to install dependencies"
    echo "Try running: sudo pip3 install -r requirements.txt"
    exit 1
fi

echo ""
echo "✓ Dependencies installed successfully"
echo ""

# Check if web_app.py exists
if [ ! -f "web_app.py" ]; then
    echo "Error: web_app.py not found"
    exit 1
fi

# Start the web application
echo "Starting web server..."
echo ""
python3 web_app.py
