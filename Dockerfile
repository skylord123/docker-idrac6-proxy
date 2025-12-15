FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive \
    IDRAC_HOST=192.168.1.21 \
    IDRAC_PORT=443 \
    PROXY_PORT=8443

# Install build dependencies and runtime tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    ca-certificates \
    perl \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and compile OpenSSL 1.0.2u with SSLv3 enabled
RUN cd /tmp && \
    wget https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz && \
    tar xzf openssl-1.0.2u.tar.gz && \
    cd openssl-1.0.2u && \
    ./config --prefix=/opt/openssl-legacy \
             --openssldir=/opt/openssl-legacy/ssl \
             enable-ssl3 \
             enable-ssl3-method \
             enable-weak-ssl-ciphers \
             shared && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/openssl-1.0.2u*

# Download and compile socat with our custom OpenSSL
RUN cd /tmp && \
    wget http://www.dest-unreach.org/socat/download/socat-1.7.4.4.tar.gz && \
    tar xzf socat-1.7.4.4.tar.gz && \
    cd socat-1.7.4.4 && \
    CPPFLAGS="-I/opt/openssl-legacy/include" \
    LDFLAGS="-L/opt/openssl-legacy/lib -Wl,-rpath,/opt/openssl-legacy/lib" \
    ./configure --prefix=/opt/socat && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/socat-1.7.4.4*

# Clean up build dependencies
RUN apt-get purge -y build-essential wget && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Generate self-signed certificate for the proxy
RUN /opt/openssl-legacy/bin/openssl req -new -x509 -days 3650 -nodes \
    -out /opt/proxy.crt \
    -keyout /opt/proxy.key \
    -subj "/C=US/ST=State/L=City/O=iDRAC-Proxy/CN=localhost" && \
    cat /opt/proxy.crt /opt/proxy.key > /opt/proxy.pem

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8443

ENTRYPOINT ["/entrypoint.sh"]