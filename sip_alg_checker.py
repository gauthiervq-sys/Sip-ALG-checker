# SIP ALG Checker

This is a basic SIP ALG Checker application.

## Overview

The SIP ALG Checker application detects whether SIP ALG is enabled on a router or firewall.

## Functionality

- Checks if SIP ALG is enabled.
- Provides instructions to disable SIP ALG if necessary.

## Usage

Run the application in your Python environment. It will perform the SIP ALG check and provide the result.

## Code

```python
import socket

class SipAlgChecker:
    def __init__(self):
        self.sip_port = 5060
        self.sip_message = "OPTIONS sip:example.com SIP/2.0\r\n"

    def check_alg(self):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(2)
            try:
                sock.sendto(self.sip_message.encode(), ('router_ip', self.sip_port))
                response, _ = sock.recvfrom(1024)
                return "SIP ALG is enabled" if b'200 OK' in response else "SIP ALG is not enabled"
            except socket.timeout:
                return "Request timed out"

if __name__ == '__main__':
    checker = SipAlgChecker()
    print(checker.check_alg())
```