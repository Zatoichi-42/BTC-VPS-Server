#!/bin/bash

echo "=================================================="
echo "🚀 WireGuard VPN Setup with UFW & IPTables Fixes 🚀"
echo "=================================================="

echo "[1/12] 🔄 Updating system..."
sudo apt update -y

echo "[2/12] 📦 Installing packages: wireguard, qrencode, ufw, curl, dos2unix..."
sudo apt install -y wireguard qrencode ufw curl dos2unix

echo "[3/12] 🔧 Checking wg-quick permissions..."
WGQUICK_PATH=$(which wg-quick)
if [[ -x "$WGQUICK_PATH" ]]; then
    echo "✅ wg-quick is executable: $WGQUICK_PATH"
else
    echo "⚠️ Fixing wg-quick permissions..."
    sudo chmod +x "$WGQUICK_PATH"
fi

echo "[4/12] 🔐 Generating WireGuard server keys..."
umask 077
wg genkey | sudo tee /etc/wireguard/server_private.key >/dev/null
sudo cat /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key >/dev/null
sudo chmod 600 /etc/wireguard/server_private.key /etc/wireguard/server_public.key
SERVER_PRIV=$(sudo cat /etc/wireguard/server_private.key)
SERVER_PUB=$(sudo cat /etc/wireguard/server_public.key)
echo "✅ Server public key: $SERVER_PUB"

echo "[5/12] 📱 Generating Android client keys..."
ANDROID_PRIV=$(wg genkey)
ANDROID_PUB=$(echo "$ANDROID_PRIV" | wg pubkey)
echo "✅ Android public key: $ANDROID_PUB"

echo "[6/12] 🌐 Detecting public IP..."
SERVER_PUBLIC_IP=$(curl -s https://ifconfig.me)
echo "Detected IP: $SERVER_PUBLIC_IP"
read -rp "Use this IP? (Y/n): " confirm_ip
if [[ "$confirm_ip" =~ ^[nN] ]]; then
    read -rp "Enter custom IP or DDNS hostname: " SERVER_PUBLIC_IP
fi

echo "[7/12] 📡 Detecting outbound network interface..."
NET_IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
echo "✅ Using interface: $NET_IFACE"

echo "[8/12] 🛠️ Creating /etc/wireguard/wg0.conf..."
sudo tee /etc/wireguard/wg0.conf >/dev/null <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIV
PostUp = iptables -t nat -A POSTROUTING -o $NET_IFACE -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o $NET_IFACE -j MASQUERADE

[Peer]
PublicKey = $ANDROID_PUB
AllowedIPs = 10.0.0.2/32
EOF

echo "✅ wg0.conf created."

echo "[9/12] 🔒 Fixing permissions on wg0.conf..."
sudo chown root:root /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf
sudo dos2unix /etc/wireguard/wg0.conf

echo "[10/12] 🛡️ Configuring UFW firewall rules..."
sudo ufw allow 51820/udp
sudo ufw route allow in on wg0 out on $NET_IFACE
sudo ufw enable
sudo ufw reload

echo "[11/12] 🔧 Enabling IP forwarding..."
if [ ! -f /etc/sysctl.conf ]; then
    echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.conf
else
    sudo sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
    grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -p /etc/sysctl.conf

echo "[12/12] 🚀 Starting WireGuard wg0 interface..."
sudo systemctl daemon-reexec
sudo systemctl enable wg-quick@wg0
sudo systemctl restart wg-quick@wg0

echo "✅ wg0 started. Showing interface status:"
sudo wg show

echo "📱 Generating Android config & QR code..."
ANDROID_CONFIG="[Interface]
PrivateKey = $ANDROID_PRIV
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
AllowedIPs = 0.0.0.0/0
Endpoint = $SERVER_PUBLIC_IP:51820
PersistentKeepalive = 25"

echo "$ANDROID_CONFIG" | qrencode -t ansiutf8

echo "✅ Scan this QR in your Android WireGuard app."
echo "📎 Android public key (for future reference): $ANDROID_PUB"
