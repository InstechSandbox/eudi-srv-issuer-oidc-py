#!/bin/bash

# Run server with HTTPS using self-signed certificate
AUTH_CONFIG_FILE="${AUTH_CONFIG_FILE:-config.json}"

python3 server.py "$AUTH_CONFIG_FILE" --cert server.crt --key server.key