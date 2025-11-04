#!/bin/bash

# Asterisk SIP ALG Checker Listener

echo "Starting Asterisk SIP ALG Server Listener..."

# Create a socket for listening
PORT=5060

# Start the listener
while true; do
    nc -lu -p $PORT -c 'echo "Received SIP Message: " && cat'
    echo "Waiting for the next SIP message..."
done