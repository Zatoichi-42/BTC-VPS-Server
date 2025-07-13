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

# --- STEP 5: Harden SSH config ---
SSHD_FILE="/etc/ssh/sshd_config"
echo "🔧 STEP 5: Configuring $SSHD_FILE"

cp "$SSHD_FILE" "${SSHD_FILE}.bak.$(date +%s)"

declare -A sshd_settings=(
  ["Port"]="$ssh_port"
  ["PermitRootLogin"]="no"
  ["PubkeyAuthentication"]="yes"
  ["PasswordAuthentication"]="no"
  ["ChallengeResponseAuthentication"]="no"
  ["AllowTcpForwarding"]="yes"
  ["GatewayPorts"]="yes"
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

# --- STEP 6: Remove root login password ---
echo "🔒 Locking root password to disable login"
passwd -l root

# --- STEP 7: Install fail2ban ---
echo "🛡️ STEP 7: Installing and configuring fail2ban"
apt install -y fail2ban
cat <<EOF >/etc/fail2ban/jail.local
[sshd]
enabled = true
EOF

# --- STEP 8: Install unattended-upgrades ---
echo "🔄 STEP 8: Installing unattended-upgrades for auto security updates"
apt install -y unattended-upgrades apt-listchanges
# Enable only security updates
dpkg-reconfigure --frontend=noninteractive --priority=low unattended-upgrades
echo "✅ Unattended-upgrades configured"

# --- STEP 9: Configure UFW firewall ---
echo "🛡️ STEP 9: Configuring UFW firewall"
apt install -y ufw

# Reset to defaults
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH and rate-limit it
ufw allow "${ssh_port}/tcp"
ufw limit "${ssh_port}/tcp"

# Allow Bitcoin node incoming connections on port 8333
ufw allow 8333/tcp
echo "🔧 Allowed SSH port $ssh_port and Bitcoin port 8333"

# Enable UFW
ufw --force enable
echo "✅ UFW is active"

# --- STEP 10: Reload and restart services ---
echo "🔁 STEP 10: Reloading daemon, restarting SSH & fail2ban"
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable fail2ban
systemctl restart fail2ban
systemctl restart ssh

# --- STEP 11: Final verification ---
echo "✅ Final status checks:"
echo -n "🔍 SSH config syntax: " && sshd -t && echo "OK"
echo "🔍 fail2ban active: $(systemctl is-active fail2ban)"
echo "🔍 ssh service active: $(systemctl is-active ssh)"
echo "🔍 UFW status:" && ufw status verbose
echo "🔍 unattended-upgrades status: $(systemctl is-active unattended-upgrades)"
echo "🔍 SSH port now: $ssh_port"
echo "👥 Sudo group members: $(getent group sudo)"
echo "📁 Home dir for $admin_user: $(ls -ld /home/$admin_user)"
echo "🔐 Root account status: $(passwd -S root | awk '{print $2}')"

echo ""
echo "⚠️ Don’t forget to add your public SSH key to /home/$admin_user/.ssh/authorized_keys"
echo "⚠️ Then connect with: ssh -p $ssh_port $admin_user@your.vps.ip"
echo ""
echo "✅ Fully hardened VPS setup complete."
echo "Firewall Setup:"
ufw status

