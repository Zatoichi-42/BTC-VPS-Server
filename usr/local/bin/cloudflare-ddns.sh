#!/bin/bash
echo "[DDNS] 🌐 Explicit Cloudflare DNS Update..."

# ======= CONFIGURATION (explicitly set these) =======
ZONE_ID="your_zone_id_here"
DOMAIN="subdomain.yourdomain.com"
API_TOKEN="your_api_token_here"

# ======= Explicitly retrieving your public IP =======
IP=$(curl -s https://ifconfig.me)
echo "✅ Current Public IP explicitly is: $IP"

#########################33
# TEST 
#IP="1.1.1.1"
#echo "TESTING WITH IP $IP"
###########################


# ======= Explicitly retrieving DNS Record ID via Cloudflare API =======
echo "[DDNS] 🔍 Explicitly retrieving DNS Record ID..."
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$DOMAIN" \
-H "Authorization: Bearer $API_TOKEN" \
-H "Content-Type: application/json" | jq -r '.result[0].id')

# Explicit check to ensure RECORD_ID was found
if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" == "null" ]; then
    echo "[DDNS] ⚠️ ERROR: Could not explicitly find DNS Record ID. Check DOMAIN and ZONE_ID."
    exit 1
else
    echo "✅ Explicitly found DNS Record ID: $RECORD_ID"
fi

# ======= Explicitly Updating DNS Record =======
echo "[DDNS] 🚀 Explicitly updating DNS record..."
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
-H "Authorization: Bearer $API_TOKEN" \
-H "Content-Type: application/json" \
--data '{"type":"A","name":"'"$DOMAIN"'","content":"'"$IP"'","ttl":120,"proxied":false}')

# ======= Explicitly Verify Cloudflare Response =======
echo "$RESPONSE" | jq -r '.success'
if [[ $(echo "$RESPONSE" | jq -r '.success') == "true" ]]; then
    echo "[DDNS] ✅ Explicit DNS update succeeded."
else
    echo "[DDNS] ⚠️ ERROR: Explicit DNS update failed!"
    echo "$RESPONSE" | jq
fi
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A" \
-H "Authorization: Bearer $API_TOKEN" \
-H "Content-Type: application/json" | jq '.result[] | {name, id, content}'

