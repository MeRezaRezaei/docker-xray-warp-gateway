# ==============================================================================
# Survivor Module Makefile
# Handles auto-provisioning, deployment, and automated testing.
# ==============================================================================

# Default target: Build, Run, Wait, and Test automatically
.PHONY: all
all: deploy

# ------------------------------------------------------------------------------
# Automation Logic
# ------------------------------------------------------------------------------

.PHONY: deploy
deploy: up
	@echo "[INFO] Waiting 5 seconds for Xray to initialize..."
	@sleep 5
	@echo "[INFO] Starting Automated Tests..."
	@$(MAKE) test

# ------------------------------------------------------------------------------
# Core Operations
# ------------------------------------------------------------------------------

.PHONY: up
up: .env
	@echo "[INFO] Starting Warp Proxy Module..."
	docker compose up -d --build
	@echo "[SUCCESS] Container started in background."

.PHONY: down
down:
	@echo "[INFO] Stopping module..."
	docker compose down

.PHONY: logs
logs:
	docker compose logs -f

# ------------------------------------------------------------------------------
# Granular Testing Suite
# ------------------------------------------------------------------------------

.PHONY: test
test: test-1-config test-2-process test-3-ports test-4-network
	@echo "\n[SUCCESS] ALL SYSTEMS GO! Module is ready."

.PHONY: test-1-config
test-1-config:
	@echo "\n[TEST 1/4] Verifying Configuration File..."
	@docker exec warp_proxy_module grep '"port":' /etc/xray/config.json || (echo "[FAIL] Config read error"; exit 1)

.PHONY: test-2-process
test-2-process:
	@echo "\n[TEST 2/4] Verifying Xray Process..."
	@docker exec warp_proxy_module ps aux | grep xray | grep -v grep || (echo "[FAIL] Xray not running"; exit 1)

.PHONY: test-3-ports
test-3-ports:
	@echo "\n[TEST 3/4] Verifying Listening Ports..."
	@docker exec warp_proxy_module netstat -an | grep LISTEN | grep ":" || (echo "[FAIL] No ports listening"; exit 1)

.PHONY: test-4-network
test-4-network:
	@echo "\n[TEST 4/4] Verifying Network Connectivity..."
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