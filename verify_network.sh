#!/bin/sh

# ============================================================
# Network Verification Script for Xray-Warp Gateway
# Checks: Socks5 Port -> Cloudflare Trace -> IP Geolocation
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Read port from Env or default to 10808
PROXY_PORT="${XRAY_PORT:-10808}"
PROXY_HOST="127.0.0.1"
PROXY_URL="socks5h://${PROXY_HOST}:${PROXY_PORT}"

echo -e "${CYAN}--- Starting Network Verification (Port: ${PROXY_PORT}) ---${NC}"

# 1. Check if Xray port is listening
if netstat -tuln | grep -q ":${PROXY_PORT} "; then
    echo -e "${GREEN}[PASS] Port ${PROXY_PORT} is listening.${NC}"
else
    echo -e "${RED}[FAIL] Port ${PROXY_PORT} is NOT listening. Xray might be down.${NC}"
    exit 1
fi

# 2. Check Connection to Cloudflare (Warp Status)
echo -e "${YELLOW}[INFO] Checking Cloudflare Warp Status...${NC}"
CF_TRACE=$(curl -s --max-time 10 -x "$PROXY_URL" https://www.cloudflare.com/cdn-cgi/trace)

if [ $? -eq 0 ]; then
    WARP_STATUS=$(echo "$CF_TRACE" | grep "warp=" | cut -d= -f2)
    IP_STATUS=$(echo "$CF_TRACE" | grep "ip=" | cut -d= -f2)
    LOC_STATUS=$(echo "$CF_TRACE" | grep "loc=" | cut -d= -f2)

    if [ "$WARP_STATUS" = "on" ]; then
        echo -e "${GREEN}[PASS] Cloudflare Warp is ON.${NC}"
    else
        echo -e "${RED}[FAIL] Cloudflare Warp is OFF (warp=off).${NC}"
    fi
    echo -e "       Edge IP: ${IP_STATUS}"
    echo -e "       Location: ${LOC_STATUS}"
else
    echo -e "${RED}[FAIL] Could not connect to Cloudflare Trace. Check internet or proxy config.${NC}"
    echo -e "${RED}       Error Detail: Failed to curl https://www.cloudflare.com/cdn-cgi/trace${NC}"
fi

# 3. Check Public IP (External View)
echo -e "${YELLOW}[INFO] Checking Public IP via ipinfo.io...${NC}"
IP_INFO=$(curl -s --max-time 10 -x "$PROXY_URL" https://ipinfo.io/json)

if [ $? -eq 0 ]; then
    PUBLIC_IP=$(echo "$IP_INFO" | grep '"ip":' | cut -d '"' -f 4)
    ORG=$(echo "$IP_INFO" | grep '"org":' | cut -d '"' -f 4)
    COUNTRY=$(echo "$IP_INFO" | grep '"country":' | cut -d '"' -f 4)

    echo -e "${GREEN}[PASS] External Connection Successful.${NC}"
    echo -e "       Public IP: ${PUBLIC_IP}"
    echo -e "       ISP/Org:   ${ORG}"
    echo -e "       Country:   ${COUNTRY}"
    
    # Simple check to see if it's Cloudflare
    if echo "$ORG" | grep -qi "Cloudflare"; then
        echo -e "${GREEN}[SUCCESS] Traffic is routed through Cloudflare Network.${NC}"
    else
        echo -e "${YELLOW}[WARN] ISP does not look like Cloudflare. Verify routing.${NC}"
    fi
else
    echo -e "${RED}[FAIL] Could not fetch IP info from ipinfo.io.${NC}"
fi

echo -e "${CYAN}--- Verification Finished ---${NC}"