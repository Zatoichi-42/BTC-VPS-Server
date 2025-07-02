#!/bin/bash
set -euo pipefail
set -x

# Default admin username
default_admin="admin"

function prompt_admin_user() {
    read -rp "Enter admin username [${default_admin}]: " admin_user
    admin_user=${admin_user:-$default_admin}
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
    prompt_admin_user
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
    systemctl restart sshd
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
    systemctl reload sshd
    echo "SSH key added for $admin_user."
}

function main_menu() {
    while true; do
        echo "\n==== Hezner VPS Server Setup Menu ===="
        echo "1) Setup Admin User"
        echo "2) Harden Server"
        echo "3) Add New Public SSH Key"
        echo "4) Exit"
        read -rp "Select an option [1-4]: " choice
        case $choice in
            1) setup_admin_user ;;
            2) harden_server ;;
            3) add_ssh_key ;;
            4) echo "Exiting."; exit 0 ;;
            *) echo "Invalid option. Please select 1-4." ;;
        esac
    done
}

main_menu 