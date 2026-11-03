#!/bin/sh
set -eu

GLOBAL_CONFIG="/usr/share/nginx/html/assets/assets/config/global_config.json"
SSL_DIR="/etc/nginx/ssl"
CERT_FILE="${TLS_CERT_FILE:-${SSL_DIR}/cert.pem}"
KEY_FILE="${TLS_KEY_FILE:-${SSL_DIR}/key.pem}"
TLS_SELF_SIGNED="${TLS_SELF_SIGNED:-false}"
TLS_HOSTNAME="${TLS_HOSTNAME:-commet.local}"
HTTPS_PORT="${HTTPS_PORT:-443}"
TLS_PUBLIC_PORT="${TLS_PUBLIC_PORT:-${HTTPS_PORT}}"

apply_default_homeserver() {
  homeserver="${DEFAULT_HOMESERVER:-${default_homeserver:-}}"
  if [ -z "$homeserver" ]; then
    return 0
  fi

  homeserver="${homeserver#https://}"
  homeserver="${homeserver#http://}"
  homeserver="${homeserver%%/*}"

  if ! printf '%s' "$homeserver" | grep -Eq '^[A-Za-z0-9.-]+$'; then
    echo "Invalid DEFAULT_HOMESERVER value; expected hostname like matrix.example.com" >&2
    exit 1
  fi

  printf '{\n    "default_homeserver": "%s"\n}\n' "$homeserver" > "$GLOBAL_CONFIG"
}

ensure_tls_material() {
  if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    return 0
  fi

  case "$TLS_SELF_SIGNED" in
    true|TRUE|1|yes|YES)
      mkdir -p "$SSL_DIR"
      if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        echo "Generating self-signed TLS certificate for ${TLS_HOSTNAME} ..."
        if printf '%s' "$TLS_HOSTNAME" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
          SAN="IP:${TLS_HOSTNAME}"
        else
          SAN="DNS:${TLS_HOSTNAME}"
        fi
        openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
          -keyout "$KEY_FILE" \
          -out "$CERT_FILE" \
          -subj "/CN=${TLS_HOSTNAME}" \
          -addext "subjectAltName=${SAN},IP:127.0.0.1"
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

configure_nginx() {
  rm -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/ssl.conf

  if ensure_tls_material; then
    cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;
    return 301 https://\$host:${TLS_PUBLIC_PORT}\$request_uri;
}
EOF

    cat > /etc/nginx/conf.d/ssl.conf <<EOF
server {
    listen ${HTTPS_PORT} ssl;
    listen [::]:${HTTPS_PORT} ssl;
    server_name _;
    ssl_certificate ${CERT_FILE};
    ssl_certificate_key ${KEY_FILE};
    ssl_protocols TLSv1.2 TLSv1.3;
    include /etc/nginx/snippets/commet-app.conf;
}
EOF
  else
    cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;
    include /etc/nginx/snippets/commet-app.conf;
}
EOF
  fi
}

apply_default_homeserver
configure_nginx

exec nginx -g "daemon off;"
