BINARY_NAME=i-cherri
DIST_DIR=dist
SHORTCUT_SOURCE=iphone_daily_backup.cherri
SHORTCUT_OUTPUT=iPhone Daily Backup.shortcut
BUILD_TIME=$(shell date "+%Y-%m-%d_%H:%M:%S")
SHORTCUT_TIME=$(shell TZ=Asia/Seoul date "+%Y-%m-%d %H:%M:%S KST")
SIGN_SERVER_PORT=38080
SIGN_SERVER_URL=http://localhost:$(SIGN_SERVER_PORT)
BACKUP_DIR=$(HOME)/Photos
DB_FILE=$(BACKUP_DIR)/.i-cherri.sqlite3
IOS_PROJECT=apps/ios/iCherri-ios.xcodeproj
IOS_SCHEME=iCherri-ios
IOS_BUNDLE_ID=com.yangeok.iCherri-ios
IOS_DERIVED_DATA=$(CURDIR)/.build/ios-derived
IOS_APP_PATH=$(IOS_DERIVED_DATA)/Build/Products/Debug-iphoneos/$(IOS_SCHEME).app

.PHONY: all go shortcut sign-server clean run reindex db-clean db-reset help init mac-app ios-app ios-run ios-console ios-dev mac-logs

all: go shortcut init

go:
	@echo "🚀 Building Go binary..."
	mkdir -p $(DIST_DIR)
	rm -f $(DIST_DIR)/$(BINARY_NAME)
	go build -ldflags="-X 'main.buildTime=$(BUILD_TIME)'" -o $(DIST_DIR)/$(BINARY_NAME) .
	@echo "✅ Go binary built: $(DIST_DIR)/$(BINARY_NAME)"

init:
	@echo "🚀 Building init CLI..."
	mkdir -p $(DIST_DIR)
	rm -f $(DIST_DIR)/init
	go build -o $(DIST_DIR)/init ./cmd/init
	@echo "✅ init built: $(DIST_DIR)/init"

SHORTCUT_NAME=iPhone Daily Backup

shortcut:
	@echo "🍒 Building Signed Cherri shortcut..."
	rm -f "$(SHORTCUT_OUTPUT)"
	sed "s/수정일시: [0-9-]* [0-9:]* KST/수정일시: $(SHORTCUT_TIME)/" $(SHORTCUT_SOURCE) > /tmp/_cherri_build.cherri
	cherri /tmp/_cherri_build.cherri
	mv "/tmp/$(SHORTCUT_OUTPUT)" "$(SHORTCUT_OUTPUT)"
	@echo "✅ Signed shortcut built: $(SHORTCUT_OUTPUT)"

sign-server:
	@echo "🔐 Starting local signing server on port $(SIGN_SERVER_PORT)..."
	@which shortcut-signing-server > /dev/null 2>&1 || go install github.com/scaxyz/shortcut-signing-server@latest
	$(shell go env GOPATH)/bin/shortcut-signing-server serve :$(SIGN_SERVER_PORT)

run: go
	@echo "🔄 Restarting server..."
	-pkill -f $(DIST_DIR)/$(BINARY_NAME) || true
	./$(DIST_DIR)/$(BINARY_NAME) &

reindex: go
	@echo "🔄 Reindexing backup directory..."
	-pkill -f $(DIST_DIR)/$(BINARY_NAME) || true
	$(DIST_DIR)/$(BINARY_NAME) --reindex
	@echo "✅ Reindex done"

db-clean:
	@echo "🗑️  Removing SQLite DB and WAL/SHM files..."
	rm -f "$(DB_FILE)" "$(DB_FILE)-wal" "$(DB_FILE)-shm"
	@echo "✅ DB removed: $(DB_FILE)"

db-reset: db-clean reindex

clean:
	@echo "🧹 Cleaning artifacts..."
	rm -rf $(DIST_DIR)
	rm -f "$(SHORTCUT_OUTPUT)"

mac-app:
	@echo "🖥️  Building macOS App..."
	xcodebuild build -project apps/mac/iCherri-Mac.xcodeproj -scheme iCherri-Mac -destination 'platform=macOS'

ios-app:
	@echo "📱 Building iOS App..."
	xcodebuild build -project apps/ios/iCherri-ios.xcodeproj -scheme iCherri-ios -destination 'generic/platform=iOS'

ios-run:
	@echo "📱 Building, installing, and launching iOS app..."
	@DEVICE_ID="$${IOS_DEVICE_ID:-$$(xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -showdestinations 2>/dev/null | sed -n "s/.*platform:iOS, arch:arm64, id:\\([^,}]*\\).*/\\1/p" | head -1)}"; \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "❌ No connected iOS device found. Connect and unlock a device, or run: IOS_DEVICE_ID=<udid> make ios-run"; \
		exit 1; \
	fi; \
	echo "📲 Using device $$DEVICE_ID"; \
	xcodebuild build -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "id=$$DEVICE_ID" -derivedDataPath "$(IOS_DERIVED_DATA)"; \
	xcrun devicectl device install app --device "$$DEVICE_ID" "$(IOS_APP_PATH)"; \
	xcrun devicectl device process launch --device "$$DEVICE_ID" --terminate-existing "$(IOS_BUNDLE_ID)"

ios-console:
	@echo "📟 Launching iOS app with console attached..."
	@DEVICE_ID="$${IOS_DEVICE_ID:-$$(xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -showdestinations 2>/dev/null | sed -n "s/.*platform:iOS, arch:arm64, id:\\([^,}]*\\).*/\\1/p" | head -1)}"; \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "❌ No connected iOS device found. Connect and unlock a device, or run: IOS_DEVICE_ID=<udid> make ios-console"; \
		exit 1; \
	fi; \
	echo "📲 Using device $$DEVICE_ID"; \
	xcrun devicectl device process launch --device "$$DEVICE_ID" --terminate-existing --console "$(IOS_BUNDLE_ID)"

ios-dev: ios-run
	@$(MAKE) ios-console

mac-logs:
	@echo "🖥️  Streaming macOS app logs..."
	/usr/bin/log stream --style compact --predicate 'process == "iCherri-Mac"'

help:
	@echo "Usage:"
	@echo "  make all         - Build Go binaries (server & init) and Signed shortcut"
	@echo "  make go          - Build Go server binary only"
	@echo "  make init        - Build init CLI only"
	@echo "  make shortcut    - Build Signed shortcut only"
	@echo "  make sign-server - Run local signing server (Docker)"
	@echo "  make run         - Rebuild Go binary and restart server in background"
	@echo "  make reindex     - Rebuild Go binary and reindex backup directory"
	@echo "  make db-clean    - Remove SQLite DB + WAL/SHM files"
	@echo "  make db-reset    - db-clean + reindex"
	@echo "  make mac-app     - Build macOS SwiftUI App"
	@echo "  make ios-app     - Build iOS SwiftUI App"
	@echo "  make ios-run     - Build + install + launch iOS app on a connected device"
	@echo "  make ios-console - Attach terminal to iOS app console on a connected device"
	@echo "  make ios-dev     - Build + install + launch iOS app, then attach console"
	@echo "  make mac-logs    - Stream macOS app logs in terminal"
	@echo "  make clean       - Remove all built artifacts"
