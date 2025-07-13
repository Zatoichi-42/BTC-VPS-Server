#!/usr/bin/env bash
set -euo pipefail
echo "#############################"
echo "# INSTALLING WireGuard"
echo "#############################"

echo "🔍 Checking for root..."
if [[ $EUID -ne 0 ]]; then
  echo "⚠️ Must run as root" >&2
  exit 1
fi

WG_DIR="/etc/wireguard"
PRIKEY="$WG_DIR/server.key"
PUBKEY="$WG_DIR/server.pub"

echo "📁 WG_DIR=$WG_DIR"
echo "🔑 PRIKEY=$PRIKEY"
echo "🔑 PUBKEY=$PUBKEY"

echo "📂 Creating $WG_DIR"
mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

echo "🔑 Generating keypair"
wg genkey | tee "$PRIKEY" | wg pubkey > "$PUBKEY"

echo "🔒 Applying permissions"
chmod 600 "$PRIKEY" && chmod 644 "$PUBKEY"

echo "🔍 Verifying key files exist..."
if [[ -s "$PRIKEY" && -s "$PUBKEY" ]]; then
  echo "🎉 WireGuard keys created successfully!"
  ls -l "$PRIKEY" "$PUBKEY"
  exit 0
else
  echo "❌ Key generation failed." >&2
  exit 1
fi
