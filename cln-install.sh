# 1a. Update apt and install prerequisites
sudo apt-get update
sudo apt-get install -y software-properties-common jq net-tools python3 python3-pip \
                       libsqlite3-dev zlib1g-dev libsodium-dev  :contentReference[oaicite:0]{index=0}

# 1b. Pick the latest stable CLN version (check https://github.com/ElementsProject/lightning/releases)
export CLN_VER=v24.05.0

# 1c. Download & extract to /usr/local/bin
wget https://github.com/ElementsProject/lightning/releases/download/$CLN_VER/lightning-$CLN_VER-x86_64-linux-gnu.tar.xz
sudo tar -xvf lightning-$CLN_VER-x86_64-linux-gnu.tar.xz \
     -C /usr/local --strip-components=2

# 1d. Verify installation
which lightningd lightning-cli
lightningd --version
