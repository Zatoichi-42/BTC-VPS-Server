#!/bin/bash

echo "###########################################################"
echo "# Installing Bitcoin Knots w/ Zatoichi Config             #"
echo "###########################################################"
set -euo pipefail

# --- STEP 1: Add PPA and Install ---
echo "📦 Installing Bitcoin Knots from Luke-Jr PPA"
sudo add-apt-repository -y ppa:luke-jr/bitcoinknots
sudo apt update
sudo apt install -y bitcoind

echo "✅ Installed version:"
which bitcoind && bitcoind --version
which bitcoin-cli && bitcoin-cli --version

# --- STEP 2: Create bitcoin user ---
echo "👤 Creating system user 'bitcoin' (no shell login)"
sudo useradd --system --home /var/lib/bitcoin --shell /usr/sbin/nologin bitcoin || 
  echo "⚠️ User 'bitcoin' may already exist"

# --- STEP 3: Prepare Directories ---
echo "📁 Setting up /var/lib/bitcoin and /etc/bitcoin"
sudo mkdir -p /var/lib/bitcoin
sudo mkdir -p /etc/bitcoin
sudo chown -R bitcoin:bitcoin /var/lib/bitcoin
sudo chown -R bitcoin:bitcoin /etc/bitcoin
sudo chmod 755 /etc/bitcoin

# --- STEP 4: Download and apply bitcoin.conf ---
echo "⚙️ Installing bitcoin.conf from GitHub"
sudo curl -fsSL https://raw.githubusercontent.com/Zatoichi-42/BTC-VPS-Server/main/etc/bitcoin/bitcoin.conf \
  -o /etc/bitcoin/bitcoin.conf
sudo chown bitcoin:bitcoin /etc/bitcoin/bitcoin.conf
sudo chmod 600 /etc/bitcoin/bitcoin.conf

echo "✅ Config installed:"
sudo head -n 10 /etc/bitcoin/bitcoin.conf

# --- STEP 5: Download and install bitcoind.service ---
echo "🛠️ Installing bitcoind systemd service from GitHub"
sudo curl -fsSL https://raw.githubusercontent.com/Zatoichi-42/BTC-VPS-Server/main/etc/systemd/system/bitcoind.service \
  -o /etc/systemd/system/bitcoind.service
sudo chmod 644 /etc/systemd/system/bitcoind.service

# --- STEP 6: Enable + Start Service ---
echo "🚀 Enabling and starting bitcoind service"
sudo systemctl daemon-reload
sudo systemctl enable bitcoind
sudo systemctl start bitcoind

# --- STEP 7: Validation ---
echo "📋 bitcoind service status:"
sudo systemctl status bitcoind --no-pager

echo "📡 Recent logs (Ctrl+C to exit):"
sudo journalctl -u bitcoind -n 20 --no-pager
sleep 5

echo "🔄 Checking blockchain sync status:"
sudo -u bitcoin bitcoin-cli -conf=/etc/bitcoin/bitcoin.conf -datadir=/var/lib/bitcoin getblockchaininfo

# --- STEP 8: Configure UFW for Bitcoin P2P ---
echo "🛡️ STEP 8: Installing and configuring UFW firewall"
sudo apt install -y ufw
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 8333/tcp
sudo ufw reload

echo "🔒 UFW rules applied:"
sudo ufw status verbose

# --- STEP 9: Install helper scripts ---
echo "📂 STEP 9: Creating ~/scripts and installing helper scripts"
SCRIPT_DIR="$HOME/scripts"
mkdir -p "$SCRIPT_DIR"

# Download each helper script
for script in status-bitcoin.sh status-node.sh restart-node.sh; do
  echo "🔗 Downloading $script"
  sudo curl -fsSL https://raw.githubusercontent.com/Zatoichi-42/BTC-VPS-Server/main/scripts/$script \
    -o "$SCRIPT_DIR/$script"
  sudo chmod +x "$SCRIPT_DIR/$script"
done

echo "✅ Helper scripts installed in $SCRIPT_DIR"

# --- STEP 10: Port reachability checks ---
echo "🔍 STEP 10: Verifying bitcoind listens on port 8333"
if sudo ss -tlnp | grep -q ':8333\b'; then
  echo "✅ bitcoind is listening on port 8333"
else
  echo "❌ bitcoind is NOT listening on port 8333"
fi

echo "🔍 Testing local connectivity to port 8333"
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/8333" >/dev/null 2>&1; then
  echo "✅ Port 8333 is reachable locally"
else
  echo "❌ Port 8333 is NOT reachable locally"
fi

echo ""
echo "💡 To test externally, run from another machine:"
echo "   nc -vz <your.vps.ip> 8333"

echo "✅ Bitcoin Knots installed, syncing, P2P port open, helper scripts ready, and port checks complete!"
