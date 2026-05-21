BINARY_NAME=cherri-sync
DIST_DIR=dist
SHORTCUT_SOURCE=iphone_daily_backup.cherri
SHORTCUT_OUTPUT=iPhone Daily Backup.shortcut
BUILD_TIME=$(shell date "+%Y-%m-%d_%H:%M:%S")
SHORTCUT_TIME=$(shell TZ=Asia/Seoul date "+%Y-%m-%d %H:%M:%S KST")
SIGN_SERVER_PORT=38080
SIGN_SERVER_URL=http://localhost:$(SIGN_SERVER_PORT)
BACKUP_DIR=$(HOME)/Photos
DB_FILE=$(BACKUP_DIR)/.iphone-backup-index.sqlite3

.PHONY: all go shortcut sign-server clean run reindex db-clean db-reset help organize

all: go shortcut organize

go:
	@echo "🚀 Building Go binary..."
	mkdir -p $(DIST_DIR)
	rm -f $(DIST_DIR)/$(BINARY_NAME)
	go build -ldflags="-X 'main.buildTime=$(BUILD_TIME)'" -o $(DIST_DIR)/$(BINARY_NAME) .
	@echo "✅ Go binary built: $(DIST_DIR)/$(BINARY_NAME)"

organize:
	@echo "🚀 Building organize-by-month CLI..."
	mkdir -p $(DIST_DIR)
	rm -f $(DIST_DIR)/organize-by-month
	go build -o $(DIST_DIR)/organize-by-month ./cmd/organize-by-month
	@echo "✅ organize-by-month built: $(DIST_DIR)/organize-by-month"

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

help:
	@echo "Usage:"
	@echo "  make all         - Build Go binaries (server & organizer) and Signed shortcut"
	@echo "  make go          - Build Go server binary only"
	@echo "  make organize    - Build organize-by-month Go binary only"
	@echo "  make shortcut    - Build Signed shortcut only"
	@echo "  make sign-server - Run local signing server (Docker)"
	@echo "  make run         - Rebuild Go binary and restart server in background"
	@echo "  make reindex     - Rebuild Go binary and reindex backup directory"
	@echo "  make db-clean    - Remove SQLite DB + WAL/SHM files"
	@echo "  make db-reset    - db-clean + reindex"
	@echo "  make clean       - Remove all built artifacts"
