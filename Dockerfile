FROM teddysun/xray:latest

# Install dependencies
RUN apk add --no-cache curl gettext grep sed

# Install wgcf
RUN curl -fsSL https://github.com/ViRb3/wgcf/releases/download/v2.2.18/wgcf_2.2.18_linux_amd64 -o /usr/bin/wgcf \
    && chmod +x /usr/bin/wgcf

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY verify_network.sh /verify_network.sh
COPY config.template.json /etc/xray/config.template.json

# Set permissions
RUN chmod +x /entrypoint.sh
RUN chmod +x /verify_network.sh

ENTRYPOINT ["/entrypoint.sh"]