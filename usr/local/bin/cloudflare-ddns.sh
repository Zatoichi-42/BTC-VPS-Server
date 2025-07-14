#!/bin/bash
echo "[DDNS] Explicitly Updating Cloudflare DNS..."

ZONE_ID="YOUR_ZONE_ID"
RECORD_ID="YOUR_DNS_RECORD_ID"
DOMAIN="home.yourdomain.com"
API_TOKEN="YOUR_API_TOKEN"

# Get current IP explicitly
IP=$(curl -s https://ifconfig.me)
echo "🌐 Explicit Current IP: $IP"

# Update Cloudflare DNS explicitly
curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"type":"A","name":"'"$DOMAIN"'","content":"'"$IP"'","ttl":120,"proxied":false}' \
  | jq

echo "[DDNS] Explicit update complete."
