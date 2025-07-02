#!/bin/bash
set -euo pipefail

# Default admin username
default_admin="admin"

function prompt_admin_user() {
    read -rp "Enter admin username [${default_admin}]: " admin_user
    admin_user=${admin_user:-$default_admin}
    export LAST_ADMIN_USER="$admin_user"
}

function setup_admin_user() {
    prompt_admin_user
    if id "$admin_user" &>/dev/null; then
        echo "User $admin_user already exists."
    else
        adduser --disabled-password --gecos "" "$admin_user"
        echo "User $admin_user created."
    fi
    echo "Set password for $admin_user (will be used for root):"
    passwd "$admin_user"
    usermod -aG sudo "$admin_user"
    echo "$admin_user added to sudoers."
}

function harden_server() {
    # Use previously set admin user as default if available
    current_default_admin="${LAST_ADMIN_USER:-$default_admin}"
    read -rp "Enter admin username to harden for [${current_default_admin}]: " admin_user
    admin_user=${admin_user:-$current_default_admin}
    export LAST_ADMIN_USER="$admin_user"
    echo "Selected admin user: $admin_user"
    read -rp "Proceed with hardening for user '$admin_user'? [y/N]: " confirm_user
    if [[ ! "$confirm_user" =~ ^[Yy]$ ]]; then
        echo "Cancelled. Returning to menu."
        return
    fi
    echo "Hardening server for admin user: $admin_user"
    # Disable root SSH login
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    # Disable password authentication
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    # Ensure admin user is allowed
    if ! grep -q "^AllowUsers" /etc/ssh/sshd_config; then
        echo "AllowUsers $admin_user" >> /etc/ssh/sshd_config
    else
        sed -i "s/^AllowUsers.*/AllowUsers $admin_user/" /etc/ssh/sshd_config
    fi
    # Install fail2ban
    apt-get update && apt-get install -y fail2ban
    systemctl enable --now fail2ban
    systemctl restart ssh
    systemctl restart fail2ban
    echo "Server hardened. SSH root login and password login disabled. Only $admin_user can login via SSH. Fail2ban enabled."
}

function add_ssh_key() {
    prompt_admin_user
    read -rp "Enter the public SSH key: " pubkey
    user_home=$(eval echo ~$admin_user)
    mkdir -p "$user_home/.ssh"
    echo "$pubkey" >> "$user_home/.ssh/authorized_keys"
    chmod 700 "$user_home/.ssh"
    chmod 600 "$user_home/.ssh/authorized_keys"
    chown -R "$admin_user:$admin_user" "$user_home/.ssh"
    systemctl reload ssh
    echo "SSH key added for $admin_user."
}

function unharden_server() {
    # Re-enable root SSH login
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    # Re-enable password authentication
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    # Remove AllowUsers restriction
    sed -i '/^AllowUsers/d' /etc/ssh/sshd_config
    # Remove fail2ban if installed
    if dpkg -l | grep -qw fail2ban; then
        systemctl stop fail2ban || true
        apt-get remove --purge -y fail2ban
    fi
    systemctl restart ssh
    echo "Server unhardened: root login and password login enabled, AllowUsers restriction removed, fail2ban removed."
    # Ask user if they want to harden again
    read -rp "Do you want to harden the server again? [y/N]: " reharden
    if [[ "$reharden" =~ ^[Yy]$ ]]; then
        harden_server
    fi
}

function remove_all_users_except_root() {
    for user in $(awk -F: '($3>=1000)&&($1!="root") {print $1}' /etc/passwd); do
        echo "Removing user: $user"
        deluser --remove-home "$user"
    done
    echo "All users except root have been removed."
}

function main_menu() {
    while true; do
        echo "\n==== Hezner VPS Server Setup Menu ===="
        echo "1) Setup Admin User"
        echo "2) Harden Server"
        echo "3) Add New Public SSH Key"
        echo "4) Remove All Users Except Root"
        echo "5) Unharden Server"
        echo "6) Exit"
        read -rp "Select an option [1-6]: " choice
        case $choice in
            1) setup_admin_user ;;
            2) harden_server ;;
            3) add_ssh_key ;;
            4) remove_all_users_except_root ;;
            5) unharden_server ;;
            6) echo "Exiting."; exit 0 ;;
            *) echo "Invalid option. Please select 1-6." ;;
        esac
    done
}

main_menu 