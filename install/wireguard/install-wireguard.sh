#!/bin/bash

echo "==============================================="
echo "🚀 WireGuard VPN Setup with Permission Fixes 🚀"
echo "==============================================="

echo "[1/12] 🔄 Updating system..."
sudo apt update -y

echo "[2/12] 📦 Installing WireGuard and QR tools..."
sudo apt install -y wireguard qrencode ufw curl dos2unix

echo "[3/12] 🔧 Ensuring wg-quick is executable..."
WGQUICK_PATH=$(which wg-quick)
if [[ -x "$WGQUICK_PATH" ]]; then
    echo "✅ wg-quick is executable: $WGQUICK_PATH"
else
    echo "⚠️ Fixing wg-quick permissions..."
    sudo chmod +x "$WGQUICK_PATH"
fi

echo "[4/12] 🔑 Generating server keys..."
umask 077
wg genkey | sudo tee /etc/wireguard/server_private.key >/dev/null
sudo cat /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key >/dev/null
sudo chmod 600 /etc/wireguard/server_private.key /etc/wireguard/server_public.key
SERVER_PRIV=$(sudo cat /etc/wireguard/server_private.key)
SERVER_PUB=$(sudo cat /etc/wireguard/server_public.key)
echo "✅ Server Public Key: $SERVER_PUB"

echo "[5/12] 🔑 Generating Android client keys..."
ANDROID_PRIV=$(wg genkey)
ANDROID_PUB=$(echo "$ANDROID_PRIV" | wg pubkey)
echo "✅ Android Public Key: $ANDROID_PUB"

echo "[6/12] 🌐 Getting your public IP..."
SERVER_PUBLIC_IP=$(curl -s https://ifconfig.me)
echo "🌍 Detected IP: $SERVER_PUBLIC_IP"
read -rp "Use this IP? (Y/n): " confirm_ip
if [[ "$confirm_ip" =~ ^[nN] ]]; then
    read -rp "Enter custom IP or DDNS name: " SERVER_PUBLIC_IP
fi

echo "[7/12] 🛠️ Creating wg0.conf..."
sudo tee /etc/wireguard/wg0.conf >/dev/null <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIV
PostUp = ufw route allow in on wg0 out on eth0; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = ufw route delete allow in on wg0 out on eth0; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $ANDROID_PUB
AllowedIPs = 10.0.0.2/32
EOF

echo "[8/12] 🔒 Fixing permissions on wg0.conf..."
sudo chown root:root /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf
sudo dos2unix /etc/wireguard/wg0.conf

echo "[9/12] 🛡️ Configuring UFW firewall..."
sudo ufw allow 51820/udp
sudo ufw enable
sudo ufw reload

echo "[10/12] 🔧 Enabling IP forwarding..."
if [ ! -f /etc/sysctl.conf ]; then
    echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.conf
else
    sudo sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
    grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -p /etc/sysctl.conf

echo "[11/12] 🚀 Starting WireGuard interface wg0..."
sudo systemctl daemon-reexec
sudo systemctl enable wg-quick@wg0
sudo systemctl restart wg-quick@wg0

echo "[12/12] 📱 Generating QR code for Android..."
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

echo "✅ Scan the QR code above in the WireGuard Android app."
echo "✅ Android Public Key: $ANDROID_PUB"
echo "✅ Server Public Key: $SERVER_PUB"

echo "🔍 Running: sudo wg show"
sudo wg show
