#!/bin/bash
echo "Installing dependencies..."
pip install -r requirements.txt
echo "Starting Web Interface..."
python3 web_app.py
