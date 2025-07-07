### Step 1: Create and enable a 2 GiB swap file

# 1a. Turn off all swap (safe if no swap exists)
sudo swapoff -a

# 1b. Allocate a 2 GiB file at /swapfile (falls back to dd if fallocate isn’t available)
sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048

# 1c. Lock it down so only root can read/write
sudo chmod 600 /swapfile

# 1d. Format it as swap space and enable it immediately
sudo mkswap /swapfile
sudo swapon /swapfile

# 1e. Make it permanent across reboots
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 1f. Verify swap is active
swapon --show
free -h


### Step 2: Increase file-descriptor limit for lightningd

# 2a. Create a systemd drop-in directory for the lightningd service
sudo mkdir -p /etc/systemd/system/lightningd.service.d

# 2b. Add an override to bump the FD limit to 4096
sudo tee /etc/systemd/system/lightningd.service.d/override.conf > /dev/null <<EOF
[Service]
LimitNOFILE=4096
EOF

# 2c. Reload systemd so it picks up the new override
sudo systemctl daemon-reload

# 2d. (Optional) Check the override; once lightningd is installed, this will show 4096
systemctl show lightningd.service -p LimitNOFILE || echo "Override in place—service not installed yet."

