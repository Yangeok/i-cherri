IOS_PROJECT=apps/ios/iCherri-ios.xcodeproj
IOS_SCHEME=iCherri-ios
IOS_BUNDLE_ID=com.yangeok.iCherri-ios
IOS_DERIVED_DATA=$(CURDIR)/.build/ios-derived
IOS_APP_PATH=$(IOS_DERIVED_DATA)/Build/Products/Debug-iphoneos/$(IOS_SCHEME).app
MAC_PROJECT=apps/mac/iCherri-Mac.xcodeproj
MAC_SCHEME=iCherri-Mac
MAC_DERIVED_DATA=$(CURDIR)/.build/mac-derived
MAC_APP_PATH=$(MAC_DERIVED_DATA)/Build/Products/Debug/$(MAC_SCHEME).app

.PHONY: all clean help mac-app mac-run mac-dev mac-logs ios-app ios-run ios-console ios-dev

all: mac-app ios-app

clean:
	@echo "🧹 Cleaning app build artifacts..."
	rm -rf .build

mac-app:
	@echo "🖥️  Building macOS App..."
	xcodebuild build -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -destination 'platform=macOS' -derivedDataPath $(MAC_DERIVED_DATA)

mac-run:
	@echo "🖥️  Building and launching macOS App..."
	xcodebuild build -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -destination 'platform=macOS' -derivedDataPath $(MAC_DERIVED_DATA)
	open $(MAC_APP_PATH)

ios-app:
	@echo "📱 Building iOS App..."
	xcodebuild build -project $(IOS_PROJECT) -scheme $(IOS_SCHEME) -destination 'generic/platform=iOS'

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

mac-dev: mac-run
	@$(MAKE) mac-logs

mac-logs:
	@echo "🖥️  Streaming macOS app logs..."
	/usr/bin/log stream --style compact --predicate 'process == "iCherri-Mac"'

help:
	@echo "Usage:"
	@echo "  make all         - Build both macOS and iOS apps"
	@echo "  make mac-app     - Build macOS SwiftUI App"
	@echo "  make mac-run     - Build and launch macOS SwiftUI App"
	@echo "  make mac-dev     - Build, launch, and stream macOS logs"
	@echo "  make ios-app     - Build iOS SwiftUI App"
	@echo "  make ios-run     - Build, install, and launch iOS app on a connected device"
	@echo "  make ios-console - Attach terminal to iOS app console on a connected device"
	@echo "  make ios-dev     - Build, launch, and attach iOS console"
	@echo "  make clean       - Remove app build artifacts"
