#!/bin/bash

echo "==============================================="
echo "🚀 Explicit WireGuard VPN Interactive Setup 🚀"
echo "==============================================="

echo "[1/10] 🔄 Updating system packages..."
sudo apt update -y

echo "[2/10] 📦 Installing required packages (wireguard qrencode ufw curl)..."
sudo apt install -y wireguard qrencode ufw curl

echo "[3/10] 🔑 Generating Server keys explicitly..."
umask 077
wg genkey | sudo tee /etc/wireguard/server_private.key >/dev/null
sudo cat /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key >/dev/null
SERVER_PRIV=$(sudo cat /etc/wireguard/server_private.key)
SERVER_PUB=$(sudo cat /etc/wireguard/server_public.key)
echo "✅ Server Public Key: $SERVER_PUB"

echo "[4/10] 🔑 Generating Android client keys explicitly..."
ANDROID_PRIV=$(wg genkey)
ANDROID_PUB=$(echo "$ANDROID_PRIV" | wg pubkey)
echo "✅ Android keys generated explicitly."
echo "📱 Android Public Key: $ANDROID_PUB"

echo "[5/10] 🌐 Detecting your public IP explicitly..."
SERVER_PUBLIC_IP=$(curl -s ifconfig.me)
echo "Detected Public IP: $SERVER_PUBLIC_IP"
read -rp "Use this IP? (Y/n): " confirm_ip
if [[ "$confirm_ip" == [nN]* ]]; then
    read -rp "Enter correct public IP or DDNS hostname explicitly: " SERVER_PUBLIC_IP
fi

echo "[6/10] 🛠️ Creating server config explicitly..."
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
echo "✅ Server config created at /etc/wireguard/wg0.conf"

echo "[7/10] 🛡️ Configuring UFW firewall explicitly..."
sudo ufw allow 51820/udp
sudo ufw enable
sudo ufw reload

echo "[8/10] 🚦 Enabling IP forwarding explicitly..."
if [ ! -f /etc/sysctl.conf ]; then
    echo "⚠️ sysctl.conf missing, explicitly creating..."
    echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.conf
else
    sudo sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -p /etc/sysctl.conf

echo "[9/10] 🚀 Starting WireGuard explicitly..."
sudo systemctl enable wg-quick@wg0
sudo systemctl restart wg-quick@wg0

echo "[10/10] 📱 Generating Android WireGuard config and QR Code explicitly..."

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

echo "✅ Explicitly scan the QR code above with your Android WireGuard app."

echo "🔑 Android Public Key (for explicit verification): $ANDROID_PUB"

echo "🔧 Explicit server peer status verification:"
sudo wg show
