FROM teddysun/xray:latest


RUN apk add --no-cache curl gettext grep sed


RUN curl -fsSL https://github.com/ViRb3/wgcf/releases/download/v2.2.18/wgcf_2.2.18_linux_amd64 -o /usr/bin/wgcf \
    && chmod +x /usr/bin/wgcf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY config.template.json /etc/xray/config.template.json

ENTRYPOINT ["/entrypoint.sh"]