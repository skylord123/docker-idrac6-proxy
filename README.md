# iDRAC6 Legacy SSL/TLS Proxy

[![Docker Build](https://github.com/skylord123/docker-idrac6-proxy/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/skylord123/docker-idrac6-proxy/actions/workflows/docker-publish.yml)
[![GitHub release](https://img.shields.io/github/v/release/skylord123/docker-idrac6-proxy)](https://github.com/skylord123/docker-idrac6-proxy/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Docker-based SSL/TLS proxy that enables modern browsers to connect to old Dell iDRAC6 interfaces by translating between modern and legacy SSL/TLS protocols.

## The Problem

iDRAC6 uses extremely outdated SSL/TLS:
- SSLv3 / TLS 1.0
- Weak ciphers (3DES, RC4, etc.)
- Self-signed certificates

Modern browsers reject these connections with `ERR_SSL_VERSION_OR_CIPHER_MISMATCH`.

## The Solution

This proxy:
1. Uses OpenSSL 1.0.2u with SSLv3 support explicitly enabled
2. Accepts TLS 1.2+ from your modern browser
3. Connects to iDRAC6 using SSLv3/TLS 1.0
4. Proxies all traffic transparently

```
Your Browser (TLS 1.2+)  →  Proxy (translation)  →  iDRAC6 (SSLv3/TLS 1.0)
https://localhost:8443                              https://192.168.1.21:443
```

## Quick Start

### Option 1: Docker Run (Fastest)

Single iDRAC:
```bash
docker run -d \
  --name idrac-proxy \
  -p 8443:8443 \
  -e IDRAC_HOST=192.168.1.21 \
  -e IDRAC_PORT=443 \
  --restart unless-stopped \
  ghcr.io/skylord123/docker-idrac6-proxy:latest
```

Then access: `https://localhost:8443`

Multiple iDRACs:
```bash
# iDRAC 1
docker run -d \
  --name idrac1-proxy \
  -p 8443:8443 \
  -e IDRAC_HOST=192.168.1.21 \
  ghcr.io/skylord123/docker-idrac6-proxy:latest

# iDRAC 2
docker run -d \
  --name idrac2-proxy \
  -p 8444:8443 \
  -e IDRAC_HOST=192.168.1.22 \
  ghcr.io/skylord123/docker-idrac6-proxy:latest
```

### Option 2: Docker Compose (Recommended)

1. **Download docker-compose.yml:**
```bash
wget https://raw.githubusercontent.com/skylord123/docker-idrac6-proxy/main/docker-compose.yml
```

2. **Edit your iDRAC IP:**
```yaml
environment:
  - IDRAC_HOST=192.168.1.21  # ← Change this to your iDRAC IP
```

3. **Start the proxy:**
```bash
docker compose up -d
```

4. **Access iDRAC:**
   Open your browser to `https://localhost:8443` and accept the certificate warning.

### Option 3: Build From Source

1. **Clone the repository:**
```bash
git clone https://github.com/skylord123/docker-idrac6-proxy.git
cd docker-idrac6-proxy
```

2. **Edit docker-compose.yml** to build locally:
```yaml
services:
  idrac-proxy:
    # Comment out the image line
    # image: ghcr.io/skylord123/docker-idrac6-proxy:latest
    build: .  # Uncomment this line
```

3. **Configure your iDRAC IP in docker-compose.yml:**
```yaml
environment:
  - IDRAC_HOST=192.168.1.21  # ← Change this
```

4. **Build and start:**
```bash
docker compose build  # Takes 5-10 minutes
docker compose up -d
```

5. **Access iDRAC:**
   Open your browser to `https://localhost:8443`

## Configuration

### Change iDRAC IP Address

Edit `docker-compose.yml`:
```yaml
environment:
  - IDRAC_HOST=10.0.1.100  # Your iDRAC IP
  - IDRAC_PORT=443
```

Then restart:
```bash
docker compose restart
```

### Change Proxy Port

Edit `docker-compose.yml`:
```yaml
ports:
  - "9443:8443"  # Access via port 9443
environment:
  - PROXY_PORT=8443  # Keep internal port as 8443
```

Then access via `https://localhost:9443`

### Multiple iDRACs

Create multiple service entries in `docker-compose.yml`:
```yaml
services:
  idrac1-proxy:
    build: .
    container_name: idrac1-proxy
    ports:
      - "8443:8443"
    environment:
      - IDRAC_HOST=192.168.1.21
      
  idrac2-proxy:
    build: .
    container_name: idrac2-proxy
    ports:
      - "8444:8443"
    environment:
      - IDRAC_HOST=192.168.1.22
```

## Troubleshooting

### Check Logs
```bash
docker logs idrac-proxy
```

Look for:
- `OpenSSL version: OpenSSL 1.0.2u` - Confirms legacy OpenSSL
- `listening on AF=2 0.0.0.0:8443` - Proxy is running
- SSL connection messages when you access it

### Test iDRAC Connectivity

From your host, verify the iDRAC is reachable:
```bash
# Basic connectivity
ping 192.168.1.21

# Check if HTTPS port is open
nc -zv 192.168.1.21 443
```

### Test with OpenSSL directly

```bash
# Test what SSL/TLS versions the iDRAC supports
docker exec idrac-proxy /opt/openssl-legacy/bin/openssl s_client \
  -connect 192.168.1.21:443 -ssl3
```

### Common Issues

**"Connection refused"**
- Check that your iDRAC IP is correct
- Verify the iDRAC is powered on and accessible

**"SSL handshake failed"**
- The iDRAC might be using an even more restricted protocol
- Check the logs for specific SSL errors

**Browser shows "This site can't provide a secure connection"**
- Make sure you're using `https://` not `http://`
- The proxy only speaks SSL/TLS

**Still getting certificate errors after accepting**
- Clear your browser cache
- Try a different browser
- Check docker logs for backend connection errors

## Technical Details

### Pre-Built Images

Pre-built Docker images are automatically published to GitHub Container Registry on every release:
- Latest stable: `ghcr.io/skylord123/docker-idrac6-proxy:latest`
- Specific version: `ghcr.io/skylord123/docker-idrac6-proxy:v1.0.0`
- Branch builds: `ghcr.io/skylord123/docker-idrac6-proxy:branch-feature-name`

Images are built for both `linux/amd64` and `linux/arm64` platforms.

### What Gets Compiled (When Building From Source)

1. **OpenSSL 1.0.2u** with:
   - `enable-ssl3` - SSLv3 support
   - `enable-ssl3-method` - SSLv3 methods
   - `enable-weak-ssl-ciphers` - Old ciphers (3DES, RC4, etc.)

2. **socat 1.7.4.4** linked against the custom OpenSSL

### SSL/TLS Configuration

**Frontend (Browser → Proxy):**
- TLS 1.2+ (modern protocols)
- Modern cipher suites
- Self-signed certificate (you'll see a warning)

**Backend (Proxy → iDRAC6):**
- SSLv3 / TLS 1.0 / TLS 1.1
- ALL ciphers enabled (including weak ones)
- Certificate verification disabled

### Why This Works

Modern OpenSSL (1.1.1+) has SSLv3 and many old ciphers completely removed from the codebase. By compiling OpenSSL 1.0.2u from source with explicit legacy options, we get full support for the ancient protocols iDRAC6 requires.

## Security Warning

⚠️ **This proxy intentionally enables insecure protocols:**

- SSLv3 has known vulnerabilities (POODLE, etc.)
- Weak ciphers can be broken
- Certificate validation is disabled

**Only use this on isolated management networks. Never expose to the internet.**

This is a necessary evil for accessing legacy hardware that can't be updated.

## Files

- `Dockerfile` - Builds OpenSSL 1.0.2u and socat from source
- `docker-compose.yml` - Service configuration
- `entrypoint.sh` - Proxy startup script
- `README.md` - This file

## License

MIT - Use at your own risk for managing legacy hardware.

## Automated Builds

Docker images are automatically built and published to GitHub Container Registry:
- **Master/Main branch** → `:latest` tag
- **Release tags** (e.g., `v1.0.0`) → `:v1.0.0` and `:latest` tags
- **Other branches** → `:branch-<branch-name>` tag
- Multi-architecture support (amd64, arm64)

See [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml) for the build configuration.

## Support

If this still doesn't work:
1. Check `docker logs idrac-proxy` for errors
2. Verify your iDRAC IP is correct
3. Try accessing iDRAC directly from the container:
   ```bash
   docker exec -it idrac-proxy /opt/openssl-legacy/bin/openssl s_client \
     -connect 192.168.1.21:443 -ssl3 -showcerts
   ```
4. Open an issue with:
   - Docker version
   - Host OS
   - Full error logs
   - Output from the OpenSSL test above

## Acknowledgments

- OpenSSL team for maintaining the 1.0.2 branch
- socat developers for the flexible relay tool
- Dell for... making hardware that lasts decades (even if the software doesn't)