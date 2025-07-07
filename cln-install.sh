#!/usr/bin/env bash
set -euo pipefail

# Full installation of Core Lightning v25.05 on Ubuntu 24.04 (amd64)
# Steps: extract binaries, install deps, stop service, install binaries, create config, install service, start daemon, verify CLI

# Variables
CLN_VER="v25.05"
TARBALL_URL="https://github.com/ElementsProject/lightning/releases/download/${CLN_VER}/clightning-${CLN_VER}-Ubuntu-24.04-amd64.tar.xz"
TARBALL_PATH="/tmp/cln.tar.xz"
EXTRACT_DIR="/tmp/cln_extract"
INSTALL_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/lightningd.service"
DATADIR="/var/lib/cln"
BITCOIN_DATADIR="/var/lib/bitcoin"
RPC_FILE="${DATADIR}/bitcoin/lightning-rpc"

# 1. Download and extract the tarball
sudo rm -f "${TARBALL_PATH}"
sudo curl -fSL "${TARBALL_URL}" -o "${TARBALL_PATH}"
sudo rm -rf "${EXTRACT_DIR}"
sudo mkdir -p "${EXTRACT_DIR}"
sudo tar -xJf "${TARBALL_PATH}" -C "${EXTRACT_DIR}"

# Identify binaries under usr/bin
BIN_SRC=$(find "${EXTRACT_DIR}" -type f -path '*/usr/bin/lightningd' -printf '%h')
if [[ -z "${BIN_SRC}" ]]; then
  echo "Extraction failed: cannot find usr/bin directory"
  exit 1
fi

# 2. Install required runtime dependencies
sudo chmod 1777 /tmp
sudo apt-get update
sudo apt-get install -y libpq5 libsodium23 libsqlite3-0 zlib1g libgmp10

# 3. Stop existing service to avoid file busy errors
if sudo systemctl is-active --quiet lightningd.service; then
  echo "Stopping lightningd service..."
  sudo systemctl stop lightningd.service
fi

# 4. Install binaries
echo "Copying new binaries to ${INSTALL_DIR}..."
sudo cp "${BIN_SRC}"/* "${INSTALL_DIR}/"

# 5. Create CLN data directory and config
sudo rm -rf "${DATADIR}"
sudo mkdir -p "${DATADIR}"
sudo chown bitcoin:bitcoin "${DATADIR}"

sudo tee "${DATADIR}/config" > /dev/null <<EOF
network=bitcoin
log-level=info

# Bitcoin Knots data directory for cookie auth
bitcoin-datadir=${BITCOIN_DATADIR}
bitcoin-rpcconnect=127.0.0.1
bitcoin-rpcport=8332

# Enable BOLT12 offers
experimental-offers
EOF

sudo chown bitcoin:bitcoin "${DATADIR}/config"
sudo chmod 600 "${DATADIR}/config"

# 6. Install (or update) systemd service
sudo tee "${SERVICE_FILE}" > /dev/null <<EOF
[Unit]
Description=Core Lightning Daemon
After=bitcoind.service
Wants=bitcoind.service

[Service]
User=bitcoin
Group=bitcoin
LimitNOFILE=4096
ExecStart=/usr/local/bin/lightningd \
  --network=bitcoin \
  --lightning-dir=${DATADIR} \
  --conf=${DATADIR}/config
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 7. Reload systemd, enable, and start service
sudo systemctl daemon-reload
sudo systemctl enable lightningd.service
sudo systemctl start lightningd.service

# 8. Wait for RPC socket
echo "Waiting for lightning-rpc socket at ${RPC_FILE}..."
for i in {1..10}; do
  if sudo test -S "${RPC_FILE}"; then
    echo "RPC socket available."
    break
  fi
  sleep 1
done
if ! sudo test -S "${RPC_FILE}"; then
  echo "ERROR: lightning-rpc socket not found at ${RPC_FILE}." >&2
  exit 1
fi

# 9. Verify installation and health
echo "Installed version: $(/usr/local/bin/lightningd --version)"

echo "=== CLI getinfo via RPC socket ==="
sudo -u bitcoin lightning-cli --rpc-file=${RPC_FILE} getinfo

echo "Core Lightning ${CLN_VER#v} installation complete."
