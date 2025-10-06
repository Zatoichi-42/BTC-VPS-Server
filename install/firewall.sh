sudo ufw allow 4040/tcp comment 'DATUM API'
sudo ufw allow 23334/tcp comment 'DATUM Stratum'
sudo ufw allow 9889/tcp comment 'DATUM internal/alt'
sudo ufw allow 8333/tcp comment 'Bitcoin P2P'
sudo ufw deny 8332/tcp comment 'Block external RPC access'
sudo ufw allow in on lo comment 'Allow local loopback'

sudo ufw allow 4040/tcp comment 'DATUM API (v6)'
sudo ufw allow 23334/tcp comment 'DATUM Stratum (v6)'
sudo ufw allow 9889/tcp comment 'DATUM internal/alt (v6)'
sudo ufw allow 8333/tcp comment 'Bitcoin P2P (v6)'
sudo ufw deny 8332/tcp comment 'Block external RPC access (v6)'
sudo ufw allow in on lo comment 'Allow local loopback (v6)'

sudo ufw enable
sudo ufw status numbered
