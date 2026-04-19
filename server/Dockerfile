FROM alpine:3.20

RUN apk add --no-cache curl ca-certificates && \
    curl -so /etc/apk/keys/angie-signing.rsa https://angie.software/keys/angie-signing.rsa && \
    echo "https://download.angie.software/angie/alpine/v3.20/main" >> /etc/apk/repositories && \
    apk add --no-cache \
      angie \
      openssh-server \
      tini \
      bash

# Angie logs -> stdout/stderr for docker logs
RUN ln -sf /dev/stdout /var/log/angie/access.log && \
    ln -sf /dev/stderr /var/log/angie/error.log

COPY rootfs/ /

RUN chmod +x /usr/local/bin/entrypoint.sh && \
    adduser -D -s /sbin/nologin -h /home/mirror mirror && \
    passwd -u mirror && \
    mkdir -p /home/mirror/.ssh && \
    chown -R mirror:mirror /home/mirror/.ssh && \
    chmod 700 /home/mirror/.ssh && \
    mkdir -p /etc/ssh/keys

EXPOSE 80 443 2222

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
