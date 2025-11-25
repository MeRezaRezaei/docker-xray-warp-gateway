#!/bin/sh
set -e

# ==============================================================================
# WARP-XRAY ENTRYPOINT (Domain Endpoint Fixed)
# ==============================================================================

TEMPLATE_FILE="/etc/xray/config.template.json"
CONFIG_FILE="/etc/xray/config.json"
WGCF_DIR="/etc/xray/wgcf"
WGCF_PROFILE="$WGCF_DIR/wgcf-profile.conf"
LOG_DIR="/var/log/xray"

# 1. Setup Environment
mkdir -p "$WGCF_DIR" "$LOG_DIR"
touch "$LOG_DIR/access.log" "$LOG_DIR/error.log"

# Defaults
export XRAY_PORT="${XRAY_PORT:-10808}"
# Reverted to Domain as requested. Xray's 'domainStrategy' will handle resolution.
DEFAULT_ENDPOINT="engage.cloudflareclient.com:2408"
DEFAULT_PUBKEY="bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="

sanitize() {
    tr -d ' \n\r'
}

echo "[INFO] Starting Module on Port: $XRAY_PORT"

# 2. Provision WGCF
cd "$WGCF_DIR"
if [ ! -f "wgcf-account.toml" ]; then
    echo "[INFO] Registering account..."
    if [ -n "$WARP_LICENSE_KEY" ]; then
        yes | wgcf register --license "$WARP_LICENSE_KEY" > /dev/null
    else
        yes | wgcf register > /dev/null
    fi
fi

if [ ! -f "wgcf-profile.conf" ]; then
    echo "[INFO] Generating profile..."
    wgcf generate > /dev/null
fi

# 3. Extract Variables
echo "[INFO] Extracting credentials..."

# Private Key
RAW_KEY=$(grep 'PrivateKey' "$WGCF_PROFILE" | cut -d = -f 2 | sanitize)
export FINAL_PRIVATE_KEY="$RAW_KEY"

# Public Key & Endpoint
RAW_PUB=$(grep 'PublicKey' "$WGCF_PROFILE" | cut -d = -f 2 | sanitize)
export FINAL_PEER_PUBLIC_KEY="${RAW_PUB:-$DEFAULT_PUBKEY}"
export FINAL_PEER_ENDPOINT="${WARP_PEER_ENDPOINT:-$DEFAULT_ENDPOINT}"

# IP Addresses (Robust Parsing)
RAW_ADDRS=$(grep '^Address' "$WGCF_PROFILE" | sed 's/Address = //g' | tr -d ' ' | tr ',' '\n')

# Extract IPv4 (Contains dot)
export FINAL_ADDRESS_V4=$(echo "$RAW_ADDRS" | grep '\.' | head -n 1 | sanitize)

# Extract IPv6 (Contains colon)
export FINAL_ADDRESS_V6=$(echo "$RAW_ADDRS" | grep ':' | head -n 1 | sanitize)

echo "   > IPv4: $FINAL_ADDRESS_V4"
echo "   > IPv6: ${FINAL_ADDRESS_V6:-None}"
echo "   > Endpoint: $FINAL_PEER_ENDPOINT"

if [ -z "$FINAL_PRIVATE_KEY" ] || [ -z "$FINAL_ADDRESS_V4" ]; then
    echo "[ERROR] Critical variables missing. Check WGCF profile."
    exit 1
fi

# 4. Inject into Template
echo "[INFO] Generating config..."

# A. Substitute Variables (${FINAL_...})
# This fills in FINAL_PEER_ENDPOINT with the domain
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"

# B. Replace Port Placeholder (54321)
sed -i "s/54321/$XRAY_PORT/g" "$CONFIG_FILE"

# C. Cleanup Empty IPv6
# If FINAL_ADDRESS_V6 is empty, JSON becomes: "address": [ "1.2.3.4", "" ]
if [ -z "$FINAL_ADDRESS_V6" ]; then
    echo "[INFO] Cleaning up empty IPv6 entry..."
    sed -i 's/, ""//g' "$CONFIG_FILE"
    sed -i 's/"", //g' "$CONFIG_FILE"
    sed -i 's/""//g' "$CONFIG_FILE"
fi

# 5. Start Xray
echo "[INFO] Starting Xray..."
tail -f "$LOG_DIR/error.log" &
exec /usr/bin/xray -config "$CONFIG_FILE"