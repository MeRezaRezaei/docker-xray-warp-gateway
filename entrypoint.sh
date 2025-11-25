#!/bin/sh
set -e

TEMPLATE_FILE="/etc/xray/config.template.json"
CONFIG_FILE="/etc/xray/config.json"
WGCF_DIR="/etc/xray/wgcf"
LOG_DIR="/var/log/xray"

mkdir -p "$WGCF_DIR"
mkdir -p "$LOG_DIR"
touch "$LOG_DIR/access.log" "$LOG_DIR/error.log"

# Defaults
DEFAULT_PEER_END="engage.cloudflareclient.com:2408"
DEFAULT_PEER_PUB="bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="

export XRAY_PORT="${XRAY_PORT:-10808}"

sanitize() {
    tr -d ' \n\r'
}

echo "[INFO] Starting Warp Proxy Module on Port: $XRAY_PORT"

# --- Logic: Determine Config Source ---

if [ -n "$WARP_PRIVATE_KEY" ]; then
    echo "[INFO] Mode: Manual Static Configuration"
    export FINAL_PRIVATE_KEY="$WARP_PRIVATE_KEY"
    export FINAL_ADDRESS_V4="$WARP_ADDRESS_V4"
    export FINAL_PEER_ENDPOINT="${WARP_PEER_ENDPOINT:-$DEFAULT_PEER_END}"
    export FINAL_PEER_PUBLIC_KEY="${WARP_PEER_PUBLIC_KEY:-$DEFAULT_PEER_PUB}"
else
    echo "[INFO] Mode: WGCF Auto-Provisioning"
    cd "$WGCF_DIR"

    if [ ! -f "wgcf-account.toml" ]; then
        if [ -n "$WARP_LICENSE_KEY" ]; then
            yes | wgcf register --license "$WARP_LICENSE_KEY"
        else
            yes | wgcf register
        fi
    fi

    if [ ! -f "wgcf-profile.conf" ]; then
        wgcf generate > /dev/null
    fi

    echo "[INFO] Extracting credentials..."
    
    AUTO_PRIVATE_KEY=$(grep 'PrivateKey' wgcf-profile.conf | cut -d = -f 2 | sanitize)
    
    RAW_ADDR_LINE=$(grep 'Address' wgcf-profile.conf | grep '\.' | head -n 1 | cut -d = -f 2)
    AUTO_ADDR_V4=$(echo "$RAW_ADDR_LINE" | tr ',' ' ' | awk '{print $1}' | sanitize)
    
    AUTO_PEER_PUB=$(grep 'PublicKey' wgcf-profile.conf | cut -d = -f 2 | sanitize)
    
    # Simple Endpoint Logic
    AUTO_PEER_END="$DEFAULT_PEER_END"

    export FINAL_PRIVATE_KEY="$AUTO_PRIVATE_KEY"
    export FINAL_ADDRESS_V4="$AUTO_ADDR_V4"
    export FINAL_PEER_ENDPOINT="$AUTO_PEER_END"
    export FINAL_PEER_PUBLIC_KEY="$AUTO_PEER_PUB"
fi

if [ -z "$FINAL_PRIVATE_KEY" ] || [ -z "$FINAL_ADDRESS_V4" ]; then
    echo "[ERROR] Failed to obtain PrivateKey or IPv4 Address."
    exit 1
fi

echo "[INFO] Using Endpoint: $FINAL_PEER_ENDPOINT"

# Step A: Inject Strings
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"

# Step B: Replace Integer Port
sed -i "s/54321/$XRAY_PORT/g" "$CONFIG_FILE"

echo "[INFO] Starting Xray..."
tail -f "$LOG_DIR/error.log" &
exec /usr/bin/xray -config "$CONFIG_FILE"