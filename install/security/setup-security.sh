#!/bin/bash

echo "###############################################################"
echo "# Ubuntu VPS Secure Init: SSH + Admin + Fail2Ban + UFW + Auto Updates #"
echo "###############################################################"
set -euo pipefail

# --- STEP 0: Ask for SSH port ---
while true; do
  read -p "🔧 Enter desired SSH port (e.g. 2222): " ssh_port
  if [[ "$ssh_port" =~ ^[0-9]+$ ]] && [ "$ssh_port" -ge 1024 ] && [ "$ssh_port" -le 65535 ]; then
    echo "✅ SSH will be set to use port $ssh_port"
    break
  else
    echo "❌ Invalid port. Must be numeric between 1024–65535."
  fi
done

# --- STEP 1: Update & Upgrade system ---
echo "📦 STEP 1: Updating system packages"
apt update && apt -y upgrade

# --- STEP 2: Ask for admin username ---
while true; do
  read -p "👤 Enter the name for your admin user (e.g. zatoichi): " admin_user
  if [[ "$admin_user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "✅ Admin user will be named '$admin_user'"
    break
  else
    echo "❌ Invalid username. Must start with a letter or underscore and contain only lowercase letters, numbers, hyphens or underscores."
  fi
done

# --- STEP 3: Ask for admin password ---
echo "🔐 STEP 3: Set password for '$admin_user'"
while true; do
    read -s -p "Enter password for new admin user '$admin_user': " admin_pass1
    echo
    read -s -p "Confirm password: " admin_pass2
    echo
    if [[ "$admin_pass1" == "$admin_pass2" && -n "$admin_pass1" ]]; then
        break
    else
        echo "❌ Passwords do not match or empty. Try again."
    fi
done

# --- STEP 4: Create or update admin user ---
if id "$admin_user" &>/dev/null; then
  echo "⚠️ User '$admin_user' already exists. Updating password and ensuring sudo access."
  echo "$admin_user:${admin_pass1}" | chpasswd
else
  echo "✅ Creating user '$admin_user' with home directory and bash shell"
  useradd -m -s /bin/bash "$admin_user"
  echo "$admin_user:${admin_pass1}" | chpasswd
fi
usermod -aG sudo "$admin_user"
echo "✅ '$admin_user' is in the sudo group"

# --- STEP 5: Prompt for SSH public key and install ---
echo "🔑 STEP 5: Install SSH public key for '$admin_user'"
read -p "Paste your public SSH key (one line, e.g. ssh-ed25519 AAAA…): " pubkey
su - "$admin_user" -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
echo "$pubkey" | tee /home/"$admin_user"/.ssh/authorized_keys >/dev/null
chown "$admin_user":"$admin_user" /home/"$admin_user"/.ssh/authorized_keys
chmod 600 /home/"$admin_user"/.ssh/authorized_keys
echo "✅ SSH key installed for '$admin_user'"

# --- STEP 6: Harden SSH config ---
SSHD_FILE="/etc/ssh/sshd_config"
echo "🔧 STEP 6: Configuring $SSHD_FILE"
cp "$SSHD_FILE" "${SSHD_FILE}.bak.$(date +%s)"

declare -A sshd_settings=(
  ["Port"]="$ssh_port"
  ["PermitRootLogin"]="no"
  ["PubkeyAuthentication"]="yes"
  ["PasswordAuthentication"]="no"
  ["ChallengeResponseAuthentication"]="no"
  ["AllowTcpForwarding"]="yes"
  ["GatewayPorts"]="yes"
  ["ClientAliveInterval"]="300"
  ["ClientAliveCountMax"]="720"
)
for key in "${!sshd_settings[@]}"; do
  val="${sshd_settings[$key]}"
  if grep -qE "^\s*#?\s*${key}\b" "$SSHD_FILE"; then
    sed -ri "s|^\s*#?\s*${key}\b.*|${key} ${val}|" "$SSHD_FILE"
  else
    echo "${key} ${val}" >> "$SSHD_FILE"
  fi
  echo "🔧 Set $key to $val"
done

# --- STEP 7: Remove root login password ---
echo "🔒 Locking root password to disable login"
passwd -l root

# --- STEP 8: Install fail2ban ---
echo "🛡️ STEP 8: Installing and configuring fail2ban"
apt install -y fail2ban
cat <<EOF >/etc/fail2ban/jail.local
[sshd]
enabled = true
EOF

# --- STEP 9: Install unattended-upgrades ---
echo "🔄 STEP 9: Installing unattended-upgrades for auto security updates"
apt install -y unattended-upgrades apt-listchanges
# Enable only security updates
dpkg-reconfigure --frontend=noninteractive --priority=low unattended-upgrades
echo "✅ Unattended-upgrades configured"

# --- STEP 10: Configure UFW firewall ---
echo "🛡️ STEP 10: Configuring UFW firewall"
apt install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "${ssh_port}/tcp"
ufw limit "${ssh_port}/tcp"
ufw --force enable
echo "✅ UFW rules set (SSH on $ssh_port)"

# --- STEP 11: Reload and restart services ---
echo "🔁 STEP 11: Reloading daemon, restarting SSH & fail2ban"
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable fail2ban
systemctl restart fail2ban
systemctl restart ssh

echo "BONUS - SETUP SWAP FILE - can reduce to 4GB"
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
sudo fallocate -l 20G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab


# --- STEP 12: Final verification ---
echo "✅ Final status checks:"
echo -n "🔍 SSH config syntax: " && sshd -t && echo "OK"
echo "🔍 fail2ban active: $(systemctl is-active fail2ban)"
echo "🔍 SSH service active: $(systemctl is-active ssh)"
echo "🔍 UFW status:" && ufw status verbose
echo "🔍 unattended-upgrades active: $(systemctl is-active unattended-upgrades)"
echo "👥 Sudo group members: $(getent group sudo)"
echo "📁 Home dir for $admin_user: $(ls -ld /home/$admin_user)"
echo "🔐 Root account status: $(passwd -S root | awk '{print $2}')"

echo ""
echo "✅ Everything’s set! Connect with:"
echo "   ssh -i ~/.ssh/id_ed25519 -p $ssh_port $admin_user@<your.vps.ip>"
