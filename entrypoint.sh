#!/bin/bash
set -e

echo "=========================================="
echo "iDRAC6 Legacy SSL/TLS Proxy"
echo "=========================================="
echo "OpenSSL version:"
/opt/openssl-legacy/bin/openssl version
echo ""
echo "Proxy: https://localhost:${PROXY_PORT}"
echo "Target: https://${IDRAC_HOST}:${IDRAC_PORT}"
echo "=========================================="
echo ""
echo "SSL/TLS Configuration:"
echo "- SSLv3: ENABLED"
echo "- TLS 1.0: ENABLED" 
echo "- TLS 1.1: ENABLED"
echo "- All ciphers: ENABLED (including weak ones)"
echo "- Certificate verification: DISABLED"
echo "=========================================="
echo ""

# Set library path for our custom OpenSSL
export LD_LIBRARY_PATH=/opt/openssl-legacy/lib:$LD_LIBRARY_PATH

# Use our custom-built socat with legacy OpenSSL
# Accept modern TLS from browser, connect with legacy SSL to iDRAC
# ALL:!aNULL enables all ciphers including weak ones (3DES, RC4, etc)
exec /opt/socat/bin/socat -d -d \
    OPENSSL-LISTEN:${PROXY_PORT},cert=/opt/proxy.pem,verify=0,fork,reuseaddr \
    OPENSSL:${IDRAC_HOST}:${IDRAC_PORT},verify=0,cipher=ALL:!aNULL:!eNULL