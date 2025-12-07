#!/bin/sh
set -e

# ==============================================================================
# WARP-XRAY ENTRYPOINT (Final & Compatible Version)
# ==============================================================================

# Constants
TEMPLATE_FILE="/etc/xray/config.template.json"
CONFIG_FILE="/etc/xray/config.json"
WGCF_DIR="/etc/xray/wgcf"
WGCF_PROFILE="$WGCF_DIR/wgcf-profile.conf"
LOG_DIR="/var/log/xray"

# Defaults
DEFAULT_ENDPOINT="engage.cloudflareclient.com:2408"
DEFAULT_PUBKEY="bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="
export XRAY_PORT="${XRAY_PORT:-10808}"

# 1. Setup Environment
# ایجاد پوشه‌های ضروری برای لاگ و کانفیگ
mkdir -p "$WGCF_DIR" "$LOG_DIR"
touch "$LOG_DIR/access.log" "$LOG_DIR/error.log"

echo "########################################################"
echo "[INFO] ENTRYPOINT STARTED"
echo "[INFO] Port: $XRAY_PORT"
echo "########################################################"

# 2. Provision WGCF (Account Registration)
cd "$WGCF_DIR"
if [ ! -f "wgcf-account.toml" ]; then
    if [ -n "$WARP_LICENSE_KEY" ]; then
        echo "[INFO] Registering with License Key..."
        yes | wgcf register --license "$WARP_LICENSE_KEY" > /dev/null
    else
        echo "[INFO] Registering Free Account..."
        yes | wgcf register > /dev/null
    fi
fi

if [ ! -f "wgcf-profile.conf" ]; then
    echo "[INFO] Generating base profile..."
    wgcf generate > /dev/null
fi

# 3. Extract & Inject Variables (The Critical Part)
echo "[INFO] Resolving Configuration..."

# استخراج مقادیر پیش‌فرض از فایل تولید شده توسط wgcf
FILE_KEY=$(grep 'PrivateKey' "$WGCF_PROFILE" | cut -d = -f 2 | tr -d ' \n\r')
FILE_PUB=$(grep 'PublicKey' "$WGCF_PROFILE" | cut -d = -f 2 | tr -d ' \n\r')
# استخراج هوشمندانه IP ها
FILE_ADDRS=$(grep '^Address' "$WGCF_PROFILE" | sed 's/Address = //g' | tr -d ' ' | tr ',' '\n')
FILE_V4=$(echo "$FILE_ADDRS" | grep '\.' | head -n 1)
FILE_V6=$(echo "$FILE_ADDRS" | grep ':' | head -n 1)

# === منطق تزریق (Injection Logic) ===
# اگر متغیر در ENV باشد، از آن استفاده کن. اگر نباشد، از فایل wgcf بردار.

# Private Key
if [ -n "$WARP_PRIVATE_KEY" ]; then echo "[CTX] Using PRIVATE KEY from ENV"; else echo "[CTX] Using PRIVATE KEY from FILE"; fi
export FINAL_PRIVATE_KEY="${WARP_PRIVATE_KEY:-$FILE_KEY}"

# Endpoint
if [ -n "$WARP_PEER_ENDPOINT" ]; then echo "[CTX] Using ENDPOINT from ENV"; else echo "[CTX] Using ENDPOINT from FILE"; fi
export FINAL_PEER_ENDPOINT="${WARP_PEER_ENDPOINT:-$DEFAULT_ENDPOINT}"

# IPv4
if [ -n "$WARP_ADDRESS_V4" ]; then echo "[CTX] Using IPv4 from ENV"; else echo "[CTX] Using IPv4 from FILE"; fi
export FINAL_ADDRESS_V4="${WARP_ADDRESS_V4:-$FILE_V4}"

# IPv6 & Public Key
export FINAL_PEER_PUBLIC_KEY="${WARP_PEER_PUBLIC_KEY:-${FILE_PUB:-$DEFAULT_PUBKEY}}"
export FINAL_ADDRESS_V6="${WARP_ADDRESS_V6:-$FILE_V6}"

echo "--------------------------------------------------------"
echo " > FINAL IPv4: $FINAL_ADDRESS_V4"
echo " > FINAL IPv6: ${FINAL_ADDRESS_V6:-None}"
echo " > FINAL Endpoint: $FINAL_PEER_ENDPOINT"
echo "--------------------------------------------------------"

# بررسی نهایی برای جلوگیری از اجرای ناقص
if [ -z "$FINAL_PRIVATE_KEY" ] || [ -z "$FINAL_ADDRESS_V4" ]; then
    echo "[ERROR] Critical variables missing. Check .env or WGCF generation."
    exit 1
fi

# 4. Inject into Template (ساخت کانفیگ نهایی)
# جایگزینی متغیرهای ${VAR} در فایل تمپلیت
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"

# جایگزینی پورت (چون معمولاً عدد است و envsubst گاهی با آن مشکل دارد، با sed انجام می‌دهیم)
sed -i "s/54321/$XRAY_PORT/g" "$CONFIG_FILE"

# تمیزکاری JSON اگر IPv6 نداشتیم (حذف ویرگول‌های اضافه)
if [ -z "$FINAL_ADDRESS_V6" ]; then
    sed -i 's/, ""//g' "$CONFIG_FILE"
    sed -i 's/"", //g' "$CONFIG_FILE"
    sed -i 's/""//g' "$CONFIG_FILE"
fi

# 5. Debug & Start
echo "================ GENERATED CONFIG.JSON ================"
cat "$CONFIG_FILE"
echo "======================================================="

echo "[INFO] Starting Xray Core..."
# نمایش لاگ‌ها در خروجی داکر (چون Xray در فایل می‌نویسد، ما آن‌ها را می‌خوانیم)
tail -f "$LOG_DIR/error.log" &
exec /usr/bin/xray -config "$CONFIG_FILE"