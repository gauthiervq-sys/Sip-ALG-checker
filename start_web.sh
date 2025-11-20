#!/bin/bash
# Start Web Interface Script for SIP ALG Checker
# This script sets up and runs the Flask web interface

set -e  # Exit on error

echo "=========================================="
echo "SIP ALG Checker - Web Interface Setup"
echo "=========================================="
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed."
    echo "Please install Python 3 before running this script."
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"
echo ""

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "Error: pip3 is not installed."
    echo "Please install pip3 before running this script."
    exit 1
fi

echo "✓ pip3 found"
echo ""

# Install or upgrade dependencies
echo "Installing dependencies from requirements.txt..."
pip3 install -r requirements.txt --user

echo ""
echo "✓ Dependencies installed successfully"
echo ""

# Check if web_app.py exists
if [ ! -f "web_app.py" ]; then
    echo "Error: web_app.py not found in current directory"
    exit 1
fi

echo "=========================================="
echo "Starting Flask Web Application..."
echo "=========================================="
echo ""
echo "The web interface will be available at:"
echo "  → http://localhost:5000"
echo "  → http://0.0.0.0:5000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start the Flask application
python3 web_app.py
