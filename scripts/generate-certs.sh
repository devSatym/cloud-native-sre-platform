#!/usr/bin/env bash
# Generates a self-signed TLS certificate for local ingress development.
# Output defaults to .local/certs/tls.key + tls.crt (gitignored, do not commit).
# The GKE path uses the Helm Ingress TLS values; this helper is local-only.
set -euo pipefail

REPOSITORY_ROOT="$(git rev-parse --show-toplevel)"
CERT_DIR="${CERT_DIR:-${REPOSITORY_ROOT}/.local/certs}"
DOMAIN="${DOMAIN:-cloud-native-sre-platform.local}"

mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout "$CERT_DIR/tls.key" \
  -out    "$CERT_DIR/tls.crt" \
  -subj   "/CN=$DOMAIN/O=cloud-native-sre-platform" \
  -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN"

chmod 600 "$CERT_DIR/tls.key"
echo "Certs generated in $CERT_DIR"
