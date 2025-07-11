echo "Blockchain Info"
echo "======================"
echo 
sudo -u bitcoin bitcoin-cli -conf=/etc/bitcoin/bitcoin.conf -datadir=/var/lib/bitcoin getblockchaininfo
echo 
echo "======================"
echo 
echo "Bitcoin Network Info"

sudo -u bitcoin bitcoin-cli -conf=/etc/bitcoin/bitcoin.conf -datadir=/var/lib/bitcoin getnetworkinfo
