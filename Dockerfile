# syntax=docker/dockerfile:1

FROM nginx:alpine AS commet-web

ARG COMMET_VERSION
ARG COMMET_RELEASE_BASE=https://github.com/commetchat/commet/releases/download

RUN test -n "$COMMET_VERSION"

RUN apk add --no-cache curl gnupg

WORKDIR /tmp/commet

COPY commet-signing-key.asc /tmp/commet-signing-key.asc

RUN gpg --batch --import /tmp/commet-signing-key.asc \
    && curl -fsSL -o commet-web.tar.gz \
        "${COMMET_RELEASE_BASE}/${COMMET_VERSION}/commet-web.tar.gz" \
    && curl -fsSL -o commet-web.tar.gz.asc \
        "${COMMET_RELEASE_BASE}/${COMMET_VERSION}/commet-web.tar.gz.asc" \
    && gpg --batch --verify commet-web.tar.gz.asc commet-web.tar.gz \
    && tar -xzf commet-web.tar.gz \
    && test -d web

FROM nginx:alpine

ARG COMMET_VERSION
LABEL org.opencontainers.image.title="commet-unraid" \
    org.opencontainers.image.description="Self-hosted Commet Matrix web client (official release artifacts)" \
    org.opencontainers.image.source="https://github.com/commetchat/commet" \
    org.opencontainers.image.version="${COMMET_VERSION}" \
    org.opencontainers.image.licenses="AGPL-3.0"

RUN apk add --no-cache openssl

COPY --from=commet-web /tmp/commet/web /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY nginx/snippets/commet-app.conf /etc/nginx/snippets/commet-app.conf
COPY scripts/docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

ENV DEFAULT_HOMESERVER="" \
    TLS_SELF_SIGNED="false" \
    TLS_HOSTNAME="commet.local" \
    TLS_CERT_FILE="/etc/nginx/ssl/cert.pem" \
    TLS_KEY_FILE="/etc/nginx/ssl/key.pem" \
    HTTPS_PORT="443" \
    TLS_PUBLIC_PORT="443"

EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD sh -c 'wget -q -O /dev/null http://127.0.0.1/ 2>/dev/null || wget -q -O /dev/null --no-check-certificate https://127.0.0.1:443/'

ENTRYPOINT ["/docker-entrypoint.sh"]
