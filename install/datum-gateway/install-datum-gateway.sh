#!/bin/bash
echo "###############################################################"
echo "# Installing Datum Gateway with best practices and validation #"
echo "###############################################################"
set -euo pipefail

# ——————————————————————————————————————————————
# Make sure we’re running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ This installer must be run as root."
  echo "   Please re-run with sudo: sudo bash $0" >&2
  exit 1
fi
# ——————————————————————————————————————————————

# --- Variables ---
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "! WARNING! USING HARDCODED ADMIN USER ZATOICHI. CHANGE THE SCRIPT IF THIS IS WRONG"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

ADMIN_USER="zatoichi"
ADMIN_HOME="/home/$ADMIN_USER"
CONFIG_URL="https://raw.githubusercontent.com/Zatoichi-42/BTC-VPS-Server/main/etc/datum-gateway/config.json"
SERVICE_URL="https://raw.githubusercontent.com/Zatoichi-42/BTC-VPS-Server/main/etc/systemd/system/datum-gateway.service"
LIBS=(cmake pkgconf libcurl4-openssl-dev libjansson-dev libmicrohttpd-dev libsodium-dev psmisc)
PKG="datum-gateway"
PPA="ppa:ocean-xyz/datum-gateway"

echo "🛠️  STEP 1: Installing required libraries: ${LIBS[*]}"
apt update
apt install -y "${LIBS[@]}"
echo "✅ Libraries installed."

echo "📦 STEP 2: Adding PPA & installing $PKG"
add-apt-repository -y "$PPA"
apt update
apt install -y "$PKG"
echo "✅ $PKG installed."

echo "📂 STEP 3: Creating directories"
for DIR in /etc/datum-gateway /var/lib/datum-gateway; do
  echo "   • Creating $DIR"
  mkdir -p "$DIR"
done
echo "✅ Directories created."

echo "🔧 STEP 4: Setting ownership & permissions on /var/lib/datum-gateway"
chown -R "$ADMIN_USER":"$ADMIN_USER" /var/lib/datum-gateway
chmod -R 700 /var/lib/datum-gateway
echo "✅ /var/lib/datum-gateway → $ADMIN_USER:$ADMIN_USER, mode 700"

echo "🧐 STEP 5: Verifying binary install"
echo "   • which datum_gateway → $(which datum_gateway || echo 'NOT FOUND')"
echo "   • datum_gateway --version → $(datum_gateway --version || echo 'ERROR')"
echo "✅ Binary checks complete."

echo "⚙️ STEP 6: Downloading default config.json"
curl -fsSL "$CONFIG_URL" -o /etc/datum-gateway/config.json
echo "✅ Config fetched to /etc/datum-gateway/config.json"

echo "🔐 STEP 7: Securing config.json"
chown root:bitcoin /etc/datum-gateway/config.json
chmod 640 /etc/datum-gateway/config.json
echo "✅ /etc/datum-gateway/config.json → root:bitcoin, mode 640"

echo "📜 STEP 8: Installing systemd service unit"
curl -fsSL "$SERVICE_URL" -o /etc/systemd/system/datum-gateway.service
chmod 644 /etc/systemd/system/datum-gateway.service
echo "✅ Service unit installed at /etc/systemd/system/datum-gateway.service"

echo "⚔️ STEP 9: Ensuring 'killall' is available"
if ! command -v killall >/dev/null; then
  echo "   • Installing psmisc for killall"
  apt install -y psmisc
else
  echo "   • killall already present"
fi
echo "✅ killall ready."

echo "🚀 STEP 10: Enabling & starting datum-gateway service"
systemctl daemon-reload
systemctl enable --now datum-gateway
echo "✅ Service enabled and started."

echo "🔍 STEP 11: Final validation"
echo "   • Service status:"
systemctl status datum-gateway --no-pager
echo
echo "   • Check journal for errors (last 20 lines):"
journalctl -u datum-gateway -n20 --no-pager
echo
echo "   • Verify listening port (if configured):"
ss -tlnp | grep datum_gateway || echo "   → No listening socket detected (check config)."
echo

echo "📂 STEP 12: Installing Datum helper scripts"
SCRIPT_DIR="${ADMIN_HOME}/scripts"
echo "   • Creating $SCRIPT_DIR"
mkdir -p "$SCRIPT_DIR"
chown "$ADMIN_USER":"$ADMIN_USER" "$SCRIPT_DIR"
for script in restartDatum.sh statusDatum.sh; do
  echo "   • Downloading $script"
  curl -fsSL "https://raw.githubusercontent.com/Zatoichi-42/BTC-VPS-Server/main/scripts/$script" \
    -o "$SCRIPT_DIR/$script"
  chmod +x "$SCRIPT_DIR/$script"
  chown "$ADMIN_USER":"$ADMIN_USER" "$SCRIPT_DIR/$script"
done
echo "✅ Datum helper scripts installed in $SCRIPT_DIR"

echo "🛡️ STEP 13: Configuring UFW firewall for Datum Gateway"
apt install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 4040/tcp      # stats endpoint
ufw allow 23334/tcp     # Stratum P2P
ufw --force enable
echo "✅ UFW rules applied (ports 4040, 23334 allowed)"

echo "📋 Post-install summary:"
echo "   • /etc/datum-gateway/config.json (root:bitcoin, 640)"
echo "   • /var/lib/datum-gateway (owned by $ADMIN_USER:$ADMIN_USER, 700)"
echo "   • /etc/systemd/system/datum-gateway.service"
echo "   • datum_gateway binary at $(which datum_gateway)"
echo "   • Service 'datum-gateway' is $(systemctl is-active datum-gateway)"
echo "   • Helper scripts in $SCRIPT_DIR: $(ls $SCRIPT_DIR)"
echo "   • UFW status:" && ufw status verbose
echo

echo "✅ INSTALLATION COMPLETE — Datum Gateway is up, running, and helper scripts are in $SCRIPT_DIR"
