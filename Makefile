# ==============================================================================
# Survivor Module Makefile
# Handles auto-provisioning and granular testing.
# ==============================================================================

# Default target
.PHONY: all
all: up

# ------------------------------------------------------------------------------
# Core Operations
# ------------------------------------------------------------------------------

.PHONY: up
up: .env
	@echo "[INFO] Starting Warp Proxy Module..."
	docker compose up -d --build
	@echo "[SUCCESS] Module started."

.PHONY: down
down:
	@echo "[INFO] Stopping module..."
	docker compose down

.PHONY: logs
logs:
	docker compose logs -f

# ------------------------------------------------------------------------------
# Granular Testing Suite (The Puzzle Pieces)
# ------------------------------------------------------------------------------

# Test 1: Inspect the generated JSON config inside the container
.PHONY: test-1-config
test-1-config:
	@echo "[TEST] dumping /etc/xray/config.json..."
	@docker exec warp_proxy_module cat /etc/xray/config.json
	@echo "\n[INFO] Check above: Is 'port' a number? Is 'address' filled?"

# Test 2: Check if the Xray process is actually alive
.PHONY: test-2-process
test-2-process:
	@echo "[TEST] Checking running processes..."
	@docker exec warp_proxy_module ps aux
	@echo "[INFO] You should see '/usr/bin/xray -config ...' above."

# Test 3: Check network listening ports (Internal View)
.PHONY: test-3-ports
test-3-ports:
	@echo "[TEST] Checking listening ports..."
	@docker exec warp_proxy_module netstat -an | grep LISTEN
	@echo "[INFO] You should see your XRAY_PORT (e.g., 10809) above."

# Test 4: Full connectivity verification
.PHONY: test-4-network
test-4-network:
	@echo "[TEST] Running connectivity script..."
	@docker exec -it warp_proxy_module /verify_network.sh

# ------------------------------------------------------------------------------
# Self-Healing Logic
# ------------------------------------------------------------------------------

.env:
	@echo "[WARN] .env file not found. Creating from default template..."
	cp .env.example .env

.env.example:
	@echo "# Auto-generated .env.example" > .env.example
	@echo "WARP_LICENSE_KEY=" >> .env.example
	@echo "WARP_PRIVATE_KEY=" >> .env.example
	@echo "WARP_ADDRESS_V4=" >> .env.example
	@echo "WARP_ADDRESS_V6=" >> .env.example
	@echo "XRAY_PORT=10808" >> .env.example