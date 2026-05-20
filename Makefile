BINARY_NAME=cherri-sync
DIST_DIR=dist
SHORTCUT_SOURCE=iphone_daily_backup.cherri
SHORTCUT_OUTPUT=iPhone Daily Backup.shortcut
BUILD_TIME=$(shell date "+%Y-%m-%d_%H:%M:%S")

.PHONY: all go shortcut clean run help

all: go shortcut

go:
	@echo "🚀 Building Go binary..."
	mkdir -p $(DIST_DIR)
	rm -f $(DIST_DIR)/$(BINARY_NAME)
	go build -ldflags "-X main.buildTime=$(BUILD_TIME)" -o $(DIST_DIR)/$(BINARY_NAME) .
	@echo "✅ Go binary built: $(DIST_DIR)/$(BINARY_NAME)"

shortcut:
	@echo "🍒 Building Signed Cherri shortcut..."
	rm -f "$(SHORTCUT_OUTPUT)"
	cherri $(SHORTCUT_SOURCE) --hubsign -o "$(SHORTCUT_OUTPUT)"
	@rm -f "*_unsigned.shortcut"
	@echo "✅ Signed shortcut built: $(SHORTCUT_OUTPUT)"

run: go
	@echo "🔄 Restarting server..."
	-pkill -f $(DIST_DIR)/$(BINARY_NAME) || true
	./$(DIST_DIR)/$(BINARY_NAME) &

clean:
	@echo "🧹 Cleaning artifacts..."
	rm -rf $(DIST_DIR)
	rm -f "$(SHORTCUT_OUTPUT)"
	rm -f "*_unsigned.shortcut"

help:
	@echo "Usage:"
	@echo "  make all      - Build both Go binary and Signed shortcut"
	@echo "  make go       - Build Go binary only"
	@echo "  make shortcut - Build Signed shortcut only"
	@echo "  make run      - Rebuild Go binary and restart server in background"
	@echo "  make clean    - Remove all built artifacts"
