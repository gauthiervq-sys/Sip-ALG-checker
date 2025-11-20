#!/bin/bash
# Start script for SIP ALG Checker Web Interface
# Note: For production use, consider running this in a virtual environment:
#   python3 -m venv venv
#   source venv/bin/activate
#   pip3 install -r requirements.txt
#   python3 web_app.py

echo "========================================"
echo "  SIP ALG Checker Web Interface"
echo "========================================"
echo ""

# Install dependencies
echo "Installing dependencies..."
pip3 install -r requirements.txt

if [ $? -ne 0 ]; then
    echo "Error: Failed to install dependencies"
    exit 1
fi

echo ""
echo "Dependencies installed successfully!"
echo ""

# Start the Flask server
echo "Starting web server..."
echo "Access the dashboard at: http://localhost:5000"
echo "Press Ctrl+C to stop the server"
echo ""

python3 web_app.py
