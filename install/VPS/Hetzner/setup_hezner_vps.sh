#!/bin/bash

echo "###########################################################"
echo "# Secure VPS Setup: SSH Hardening + Admin Setup + Fail2Ban #"
echo "###########################################################"
set -euo pipefail

# --- Check if root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run as root (or with sudo)"
  exit 1
fi

# --- Ask for new admin password ---
echo "🔐 STEP 1: Create admin user 'zatoichi' (ask for password)"
while true; do
    read -s -p "Enter password for new admin user 'zatoichi': " admin_pass1
    echo
    read -s -p "Confirm password: " admin_pass2
    echo
    if [[ "$admin_pass1" == "$admin_pass2" && -n "$admin_pass1" ]]; then
        break
    else
        echo "❌ Passwords do not match or empty. Try again."
    fi
done

# --- Create new admin user ---
echo "👤 STEP 2: Creating user 'zatoichi' with sudo privileges"
if id zatoichi &>/dev/null; then
    echo "⚠️  User 'zatoichi' already exists, skipping creation"
else
    useradd -m -s /bin/bash zatoichi
    echo "zatoichi:${admin_pass1}" | chpasswd
    usermod -aG sudo zatoichi
    echo "✅ User 'zatoichi' created and added to sudo group"
fi

# --- SSH config ---
echo "🔐 STEP 3: Hardening /etc/ssh/sshd_config"
SSHD_FILE="/etc/ssh/sshd_config"

# Backup first
cp "$SSHD_FILE" "${SSHD_FILE}.bak.$(date +%s)"

# Update or append settings
declare -A sshd_settings=(
    ["PermitRootLogin"]="no"
    ["PubkeyAuthentication"]="yes"
    ["PasswordAuthentication"]="no"
    ["ChallengeResponseAuthentication"]="no"
    ["AllowTcpForwarding"]="yes"
    ["GatewayPorts"]="yes"
)

for key in "${!sshd_settings[@]}"; do
    val="${sshd_settings[$key]}"
    if grep -q "^$key" "$SSHD_FILE"; then
        sed -i "s/^$key.*/$key $val/" "$SSHD_FILE"
    else
        echo "$key $val" >> "$SSHD_FILE"
    fi
    echo "🔧 Set $key to $val"
done

# --- STEP 4: Remove root password ---
echo "🔑 Removing root password to prevent login"
passwd -l root

# --- STEP 5: Install fail2ban ---
echo "🛡️ STEP 5: Installing fail2ban"
apt update
apt install -y fail2ban

# --- Optional: Create basic jail.local ---
echo "📄 Creating minimal fail2ban config"
cat <<EOF >/etc/fail2ban/jail.local
[sshd]
enabled = true
EOF

# --- STEP 6: Reload systemd + restart SSH ---
echo "🔁 Reloading services and restarting SSH"
systemctl daemon-reexec
systemctl daemon-reload
systemctl restart ssh
systemctl enable fail2ban
systemctl restart fail2ban

# --- STEP 7: Verify everything ---
echo "✅ Verifying system status..."

echo -n "🔍 SSH config syntax: "
sshd -t && echo OK

echo "🔍 fail2ban status:"
systemctl status fail2ban --no-pager | grep Active

echo "🔍 SSH status:"
systemctl status ssh --no-pager | grep Active

echo "👥 Users with sudo access:"
getent group sudo

echo "📁 Home for zatoichi:"
ls -ld /home/zatoichi

echo "✅ VPS hardening complete. Test login via SSH as 'zatoichi' with your SSH key."

echo "NOTE: This scripts assumes that you already added the keys during the server creation (recommended)"
echo "if not, you must add the pub key in ~/.ssh/authorized_keys or you will be locked out"

