#!/bin/sh
set -e

TEMPLATE_FILE="/etc/xray/config.template.json"
CONFIG_FILE="/etc/xray/config.json"
WGCF_DIR="/etc/xray/wgcf"

mkdir -p "$WGCF_DIR"

# تنظیمات پیش‌فرض برای عبور از فیلترینگ
# این IP معمولاً از دامین engage.cloudflareclient.com بهتر کار می‌کند
DEFAULT_PEER_END="162.159.193.10:2408"
DEFAULT_PEER_PUB="bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="

sanitize() {
    tr -d ' \n\r'
}

echo "[INFO] Starting Warp Proxy Module..."

# --- Logic: Determine Config Source ---

if [ -n "$WARP_PRIVATE_KEY" ]; then
    echo "[INFO] Mode: Manual Static Configuration"
    export FINAL_PRIVATE_KEY="$WARP_PRIVATE_KEY"
    export FINAL_ADDRESS_V4="$WARP_ADDRESS_V4"
    # اگر اندپوینت دستی ست نشده بود، از IP سالم پیش‌فرض استفاده کن
    export FINAL_PEER_ENDPOINT="${WARP_PEER_ENDPOINT:-$DEFAULT_PEER_END}"
    export FINAL_PEER_PUBLIC_KEY="${WARP_PEER_PUBLIC_KEY:-$DEFAULT_PEER_PUB}"
else
    echo "[INFO] Mode: WGCF Auto-Provisioning"
    cd "$WGCF_DIR"

    # ثبت نام فقط در صورت نبود اکانت
    if [ ! -f "wgcf-account.toml" ]; then
        if [ -n "$WARP_LICENSE_KEY" ]; then
            echo "[INFO] Registering with License Key..."
            yes | wgcf register --license "$WARP_LICENSE_KEY"
        else
            echo "[INFO] Registering Free Account..."
            yes | wgcf register
        fi
    fi

    wgcf generate > /dev/null

    # استخراج هوشمند اطلاعات
    AUTO_PRIVATE_KEY=$(grep 'PrivateKey' wgcf-profile.conf | cut -d = -f 2 | sanitize)
    
    # استخراج IPv4 با نادیده گرفتن خطوط IPv6 برای جلوگیری از کرش
    RAW_ADDR_LINE=$(grep 'Address' wgcf-profile.conf | grep '\.' | head -n 1 | cut -d = -f 2)
    AUTO_ADDR_V4=$(echo "$RAW_ADDR_LINE" | tr ',' ' ' | awk '{print $1}' | sanitize)
    
    # اندپوینت را فورس می‌کنیم روی IP سالم مگر اینکه کاربر دستی تغییر داده باشد
    AUTO_PEER_END="$DEFAULT_PEER_END"
    AUTO_PEER_PUB=$(grep 'PublicKey' wgcf-profile.conf | cut -d = -f 2 | sanitize)

    export FINAL_PRIVATE_KEY="$AUTO_PRIVATE_KEY"
    export FINAL_ADDRESS_V4="$AUTO_ADDR_V4"
    export FINAL_PEER_ENDPOINT="$AUTO_PEER_END"
    export FINAL_PEER_PUBLIC_KEY="$AUTO_PEER_PUB"
fi

# --- Config Injection ---

if [ -z "$FINAL_PRIVATE_KEY" ] || [ -z "$FINAL_ADDRESS_V4" ]; then
    echo "[ERROR] Failed to obtain PrivateKey or IPv4 Address."
    exit 1
fi

echo "[INFO] Using Endpoint: $FINAL_PEER_ENDPOINT"
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"

echo "[INFO] Starting Xray..."
exec /usr/bin/xray -config "$CONFIG_FILE"