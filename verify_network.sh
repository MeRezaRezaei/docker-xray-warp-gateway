#!/bin/sh

# ============================================================
# Robust Network Verification Script (IPv4 & IPv6)
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PROXY_PORT="${XRAY_PORT:-10808}"
PROXY_HOST="127.0.0.1"
PROXY_URL="socks5h://${PROXY_HOST}:${PROXY_PORT}"

echo -e "${CYAN}--- Starting Verification (Port: ${PROXY_PORT}) ---${NC}"

# Function to run curl with retry logic
fetch_with_retry() {
    local url=$1
    local ipv=$2 # -4 or -6
    local max_retries=3
    local count=0
    
    while [ $count -lt $max_retries ]; do
        # Use curl with proxy, specific IP version, and timeout
        RESPONSE=$(curl -s $ipv --max-time 5 -x "$PROXY_URL" "$url")
        RET=$?
        
        if [ $RET -eq 0 ] && [ -n "$RESPONSE" ]; then
            echo "$RESPONSE"
            return 0
        fi
        
        count=$((count + 1))
        echo -e "${YELLOW}   ...Attempt $count failed (Code $RET). Retrying in 2s...${NC}" >&2
        sleep 2
    done
    return 1
}

# 1. Internal Port Check
if netstat -unlt | grep -q ":${PROXY_PORT}"; then
    echo -e "${GREEN}[PASS] Port ${PROXY_PORT} is listening.${NC}"
else
    echo -e "${RED}[FAIL] Port ${PROXY_PORT} is NOT listening.${NC}"
    exit 1
fi

# 2. IPv4 Test (Cloudflare Trace)
echo -e "${YELLOW}[TEST] Checking IPv4 connectivity...${NC}"
TRACE_V4=$(fetch_with_retry "https://www.cloudflare.com/cdn-cgi/trace" "-4")

if [ $? -eq 0 ]; then
    WARP=$(echo "$TRACE_V4" | grep "warp=" | cut -d= -f2)
    IP=$(echo "$TRACE_V4" | grep "ip=" | cut -d= -f2)
    LOC=$(echo "$TRACE_V4" | grep "loc=" | cut -d= -f2)
    
    if [ "$WARP" = "on" ]; then
        echo -e "${GREEN}[PASS] IPv4 Warp is ON (IP: $IP, Loc: $LOC)${NC}"
    else
        echo -e "${RED}[FAIL] IPv4 Warp is OFF!${NC}"
    fi
else
    echo -e "${RED}[FAIL] IPv4 Connection Failed.${NC}"
fi

# 3. IPv6 Test (Cloudflare Trace)
echo -e "${YELLOW}[TEST] Checking IPv6 connectivity...${NC}"
# Note: Xray must handle the IPv6 routing via WireGuard even if container has no IPv6
TRACE_V6=$(fetch_with_retry "https://www.cloudflare.com/cdn-cgi/trace" "-6")

if [ $? -eq 0 ]; then
    WARP=$(echo "$TRACE_V6" | grep "warp=" | cut -d= -f2)
    IP=$(echo "$TRACE_V6" | grep "ip=" | cut -d= -f2)
    
    if [ "$WARP" = "on" ]; then
        echo -e "${GREEN}[PASS] IPv6 Warp is ON (IP: $IP)${NC}"
    else
        echo -e "${RED}[FAIL] IPv6 Warp is OFF!${NC}"
    fi
else
    # IPv6 failure is warning, not critical, as some hosts disable it completely
    echo -e "${YELLOW}[WARN] IPv6 Connection Failed (Expected if host has no IPv6 stack).${NC}"
fi

echo -e "${CYAN}--- Verification Finished ---${NC}"