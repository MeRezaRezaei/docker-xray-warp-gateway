# ==============================================================================
# Survivor Module Makefile
# Handles auto-provisioning of configuration files and Docker operations.
# ==============================================================================

# Default target
.PHONY: all
all: up

# ------------------------------------------------------------------------------
# Core Operations
# ------------------------------------------------------------------------------

# Start the module (Auto-creates .env if missing)
.PHONY: up
up: .env
	@echo "[INFO] Starting Warp Proxy Module..."
	docker compose up -d --build
	@echo "[SUCCESS] Module is running. Test with: make test"

# Stop the module
.PHONY: down
down:
	@echo "[INFO] Stopping module..."
	docker compose down

# View logs
.PHONY: logs
logs:
	docker compose logs -f

# Verify connectivity (using the verify_network.sh script)
.PHONY: test
test:
	@echo "[INFO] Running Network Verification inside container..."
	docker exec -it warp_proxy_module /verify_network.sh

# ------------------------------------------------------------------------------
# Self-Healing Logic
# ------------------------------------------------------------------------------

# This target runs ONLY if .env does not exist
.env:
	@echo "[WARN] .env file not found. Creating from default template..."
	cp .env.example .env
	@echo "[INFO] .env created. You can edit it to add a License Key if needed."

# Ensure .env.example exists (prevents crash if git clone failed)
.env.example:
	@echo "# Auto-generated .env.example" > .env.example
	@echo "WARP_LICENSE_KEY=" >> .env.example
	@echo "WARP_PRIVATE_KEY=" >> .env.example
	@echo "WARP_ADDRESS_V4=" >> .env.example
	@echo "WARP_ADDRESS_V6=" >> .env.example