IOS_PROJECT=apps/ios/iCherri-ios.xcodeproj
IOS_SCHEME=iCherri-ios
IOS_BUNDLE_ID=com.yangeok.iCherri-ios
IOS_DERIVED_DATA=$(CURDIR)/.build/ios-derived
IOS_APP_PATH=$(IOS_DERIVED_DATA)/Build/Products/Debug-iphoneos/$(IOS_SCHEME).app
MAC_PROJECT=apps/mac/iCherri-Mac.xcodeproj
MAC_SCHEME=iCherri-Mac
MAC_DERIVED_DATA=$(CURDIR)/.build/mac-derived
MAC_APP_PATH=$(MAC_DERIVED_DATA)/Build/Products/Debug/$(MAC_SCHEME).app
MAC_RELEASE_VERSION ?= v0.1.3
MAC_RELEASE_DIST=$(CURDIR)/dist
MAC_RELEASE_ARM64_DERIVED_DATA=$(CURDIR)/.build/mac-release-arm64-derived
MAC_RELEASE_X86_64_DERIVED_DATA=$(CURDIR)/.build/mac-release-x86_64-derived
MAC_RELEASE_ARM64_APP_PATH=$(MAC_RELEASE_ARM64_DERIVED_DATA)/Build/Products/Release/$(MAC_SCHEME).app
MAC_RELEASE_X86_64_APP_PATH=$(MAC_RELEASE_X86_64_DERIVED_DATA)/Build/Products/Release/$(MAC_SCHEME).app
MAC_RELEASE_ARM64_ZIP=$(MAC_RELEASE_DIST)/iCherri-Mac-$(MAC_RELEASE_VERSION)-arm64.zip
MAC_RELEASE_X86_64_ZIP=$(MAC_RELEASE_DIST)/iCherri-Mac-$(MAC_RELEASE_VERSION)-x86_64.zip
MAC_RELEASE_ARM64_DMG=$(MAC_RELEASE_DIST)/iCherri-Mac-$(MAC_RELEASE_VERSION)-arm64.dmg
MAC_RELEASE_X86_64_DMG=$(MAC_RELEASE_DIST)/iCherri-Mac-$(MAC_RELEASE_VERSION)-x86_64.dmg
MAC_RELEASE_DMG_VOLUME_NAME=iCherri-Mac
MAC_RELEASE_DMG_STAGING=$(CURDIR)/.build/mac-dmg-staging

.PHONY: all clean help mac-app mac-run mac-dev mac-logs ios-app ios-run ios-console ios-dev mac-release-arm64 mac-release-x86_64 mac-release-assets mac-dmg-arm64 mac-dmg-x86_64 mac-dmg-assets

all: mac-app ios-app

clean:
	@echo "🧹 Cleaning app build artifacts..."
	rm -rf .build dist

mac-app:
	@echo "🖥️  Building macOS App..."
	xcodebuild build -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -destination 'platform=macOS' -derivedDataPath $(MAC_DERIVED_DATA)

mac-run:
	@echo "🖥️  Building and launching macOS App..."
	xcodebuild build -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -destination 'platform=macOS' -derivedDataPath $(MAC_DERIVED_DATA)
	open $(MAC_APP_PATH)

mac-release-arm64:
	@echo "📦 Building macOS Release App (arm64)..."
	rm -rf "$(MAC_RELEASE_ARM64_DERIVED_DATA)"
	mkdir -p "$(MAC_RELEASE_DIST)"
	xcodebuild build -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath "$(MAC_RELEASE_ARM64_DERIVED_DATA)" ONLY_ACTIVE_ARCH=NO ARCHS=arm64
	rm -f "$(MAC_RELEASE_ARM64_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(MAC_RELEASE_ARM64_APP_PATH)" "$(MAC_RELEASE_ARM64_ZIP)"

mac-release-x86_64:
	@echo "📦 Building macOS Release App (x86_64)..."
	rm -rf "$(MAC_RELEASE_X86_64_DERIVED_DATA)"
	mkdir -p "$(MAC_RELEASE_DIST)"
	xcodebuild build -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -configuration Release -destination 'platform=macOS,arch=x86_64' -derivedDataPath "$(MAC_RELEASE_X86_64_DERIVED_DATA)" ONLY_ACTIVE_ARCH=NO ARCHS=x86_64
	rm -f "$(MAC_RELEASE_X86_64_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(MAC_RELEASE_X86_64_APP_PATH)" "$(MAC_RELEASE_X86_64_ZIP)"

mac-release-assets: mac-release-arm64 mac-release-x86_64
	@echo "✅ Release assets ready in $(MAC_RELEASE_DIST)"

mac-dmg-arm64: mac-release-arm64
	@echo "📀 Packaging macOS DMG (arm64)..."
	rm -rf "$(MAC_RELEASE_DMG_STAGING)/arm64"
	mkdir -p "$(MAC_RELEASE_DMG_STAGING)/arm64"
	cp -R "$(MAC_RELEASE_ARM64_APP_PATH)" "$(MAC_RELEASE_DMG_STAGING)/arm64/"
	ln -s /Applications "$(MAC_RELEASE_DMG_STAGING)/arm64/Applications"
	rm -f "$(MAC_RELEASE_ARM64_DMG)"
	hdiutil create -volname "$(MAC_RELEASE_DMG_VOLUME_NAME)" -srcfolder "$(MAC_RELEASE_DMG_STAGING)/arm64" -ov -format UDZO "$(MAC_RELEASE_ARM64_DMG)"

mac-dmg-x86_64: mac-release-x86_64
	@echo "📀 Packaging macOS DMG (x86_64)..."
	rm -rf "$(MAC_RELEASE_DMG_STAGING)/x86_64"
	mkdir -p "$(MAC_RELEASE_DMG_STAGING)/x86_64"
	cp -R "$(MAC_RELEASE_X86_64_APP_PATH)" "$(MAC_RELEASE_DMG_STAGING)/x86_64/"
	ln -s /Applications "$(MAC_RELEASE_DMG_STAGING)/x86_64/Applications"
	rm -f "$(MAC_RELEASE_X86_64_DMG)"
	hdiutil create -volname "$(MAC_RELEASE_DMG_VOLUME_NAME)" -srcfolder "$(MAC_RELEASE_DMG_STAGING)/x86_64" -ov -format UDZO "$(MAC_RELEASE_X86_64_DMG)"

mac-dmg-assets: mac-dmg-arm64 mac-dmg-x86_64
	@echo "✅ DMG assets ready in $(MAC_RELEASE_DIST)"

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
	@echo "  make mac-release-arm64  - Build and zip macOS Release app for Apple Silicon"
	@echo "  make mac-release-x86_64 - Build and zip macOS Release app for Intel Mac"
	@echo "  make mac-release-assets - Build both macOS Release zip assets"
	@echo "  make mac-dmg-arm64      - Build and package Apple Silicon macOS DMG"
	@echo "  make mac-dmg-x86_64     - Build and package Intel macOS DMG"
	@echo "  make mac-dmg-assets     - Build both macOS DMG assets"
	@echo "  make ios-app     - Build iOS SwiftUI App"
	@echo "  make ios-run     - Build, install, and launch iOS app on a connected device"
	@echo "  make ios-console - Attach terminal to iOS app console on a connected device"
	@echo "  make ios-dev     - Build, launch, and attach iOS console"
	@echo "  make clean       - Remove app build artifacts"
