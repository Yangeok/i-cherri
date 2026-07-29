IOS_PROJECT=apps/ios/iCherri-ios.xcodeproj
IOS_SCHEME=iCherri-ios
IOS_BUNDLE_ID=com.yangeok.iCherri-ios
IOS_DERIVED_DATA=$(CURDIR)/.build/ios-derived
IOS_APP_PATH=$(IOS_DERIVED_DATA)/Build/Products/Debug-iphoneos/$(IOS_SCHEME).app
MAC_PROJECT=apps/mac/iCherri-Mac.xcodeproj
MAC_SCHEME=iCherri-Mac
MAC_DERIVED_DATA=$(CURDIR)/.build/mac-derived
MAC_APP_PATH=$(MAC_DERIVED_DATA)/Build/Products/Debug/$(MAC_SCHEME).app
MAC_RELEASE_VERSION ?= v0.1.11
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
MAC_RELEASE_SIGN_IDENTITY ?=
MAC_RELEASE_TEAM_ID ?=
MAC_NOTARYTOOL_PROFILE ?=
MAC_NOTARY_APPLE_ID ?=
MAC_NOTARY_TEAM_ID ?=
MAC_NOTARY_APP_PASSWORD ?=
MAC_NOTARY_PRIMARY_BUNDLE_ID ?= com.yangeok.iCherri-Mac

.PHONY: all clean help mac-app mac-run mac-dev mac-logs ios-app ios-run ios-console ios-dev dist-reset-release mac-release-arm64 mac-release-x86_64 mac-release-assets mac-notarize-arm64 mac-notarize-x86_64 mac-notarized-release-assets mac-package-dmg-arm64 mac-package-dmg-x86_64 mac-dmg-arm64 mac-dmg-x86_64 mac-dmg-assets mac-dmg-notarized-arm64 mac-dmg-notarized-x86_64 mac-dmg-notarized-assets

all: mac-app ios-app

clean:
	@echo "🧹 Cleaning app build artifacts..."
	rm -rf .build dist

dist-reset-release:
	@echo "🧹 Resetting release artifacts..."
	rm -rf "$(MAC_RELEASE_DIST)"
	mkdir -p "$(MAC_RELEASE_DIST)"

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
	xcodebuild build -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath "$(MAC_RELEASE_ARM64_DERIVED_DATA)" ONLY_ACTIVE_ARCH=NO ARCHS=arm64 CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS=--timestamp $(if $(MAC_RELEASE_SIGN_IDENTITY),CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$(MAC_RELEASE_SIGN_IDENTITY)") $(if $(MAC_RELEASE_TEAM_ID),DEVELOPMENT_TEAM="$(MAC_RELEASE_TEAM_ID)")
	rm -f "$(MAC_RELEASE_ARM64_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(MAC_RELEASE_ARM64_APP_PATH)" "$(MAC_RELEASE_ARM64_ZIP)"

mac-release-x86_64:
	@echo "📦 Building macOS Release App (x86_64)..."
	rm -rf "$(MAC_RELEASE_X86_64_DERIVED_DATA)"
	mkdir -p "$(MAC_RELEASE_DIST)"
	xcodebuild build -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -configuration Release -destination 'platform=macOS,arch=x86_64' -derivedDataPath "$(MAC_RELEASE_X86_64_DERIVED_DATA)" ONLY_ACTIVE_ARCH=NO ARCHS=x86_64 CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS=--timestamp $(if $(MAC_RELEASE_SIGN_IDENTITY),CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$(MAC_RELEASE_SIGN_IDENTITY)") $(if $(MAC_RELEASE_TEAM_ID),DEVELOPMENT_TEAM="$(MAC_RELEASE_TEAM_ID)")
	rm -f "$(MAC_RELEASE_X86_64_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(MAC_RELEASE_X86_64_APP_PATH)" "$(MAC_RELEASE_X86_64_ZIP)"

mac-release-assets:
	@$(MAKE) dist-reset-release
	@$(MAKE) mac-release-arm64
	@$(MAKE) mac-release-x86_64
	@echo "✅ Release assets ready in $(MAC_RELEASE_DIST)"

mac-notarize-arm64: mac-release-arm64
	@echo "🔐 Notarizing macOS Release App (arm64)..."
	@if [ -z "$(MAC_RELEASE_SIGN_IDENTITY)" ]; then \
		echo "❌ Set MAC_RELEASE_SIGN_IDENTITY to your Developer ID Application certificate."; \
		exit 1; \
	fi
	@echo "📨 Submitting zip for notarization..."
	@if [ -n "$(MAC_NOTARYTOOL_PROFILE)" ]; then \
		xcrun notarytool submit "$(MAC_RELEASE_ARM64_ZIP)" --keychain-profile "$(MAC_NOTARYTOOL_PROFILE)" --wait; \
	elif [ -n "$(MAC_NOTARY_APPLE_ID)" ] && [ -n "$(MAC_NOTARY_TEAM_ID)" ] && [ -n "$(MAC_NOTARY_APP_PASSWORD)" ]; then \
		xcrun notarytool submit "$(MAC_RELEASE_ARM64_ZIP)" --apple-id "$(MAC_NOTARY_APPLE_ID)" --team-id "$(MAC_NOTARY_TEAM_ID)" --password "$(MAC_NOTARY_APP_PASSWORD)" --wait; \
	else \
		echo "❌ Configure MAC_NOTARYTOOL_PROFILE or MAC_NOTARY_APPLE_ID + MAC_NOTARY_TEAM_ID + MAC_NOTARY_APP_PASSWORD."; \
		exit 1; \
	fi
	@echo "📎 Stapling app..."
	xcrun stapler staple -v "$(MAC_RELEASE_ARM64_APP_PATH)"
	@echo "🔎 Validating stapled app..."
	xcrun stapler validate -v "$(MAC_RELEASE_ARM64_APP_PATH)"
	spctl -a -vv -t exec "$(MAC_RELEASE_ARM64_APP_PATH)"
	rm -f "$(MAC_RELEASE_ARM64_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(MAC_RELEASE_ARM64_APP_PATH)" "$(MAC_RELEASE_ARM64_ZIP)"
	@echo "✅ Notarized app + zip ready: $(MAC_RELEASE_ARM64_APP_PATH)"

mac-notarize-x86_64: mac-release-x86_64
	@echo "🔐 Notarizing macOS Release App (x86_64)..."
	@if [ -z "$(MAC_RELEASE_SIGN_IDENTITY)" ]; then \
		echo "❌ Set MAC_RELEASE_SIGN_IDENTITY to your Developer ID Application certificate."; \
		exit 1; \
	fi
	@echo "📨 Submitting zip for notarization..."
	@if [ -n "$(MAC_NOTARYTOOL_PROFILE)" ]; then \
		xcrun notarytool submit "$(MAC_RELEASE_X86_64_ZIP)" --keychain-profile "$(MAC_NOTARYTOOL_PROFILE)" --wait; \
	elif [ -n "$(MAC_NOTARY_APPLE_ID)" ] && [ -n "$(MAC_NOTARY_TEAM_ID)" ] && [ -n "$(MAC_NOTARY_APP_PASSWORD)" ]; then \
		xcrun notarytool submit "$(MAC_RELEASE_X86_64_ZIP)" --apple-id "$(MAC_NOTARY_APPLE_ID)" --team-id "$(MAC_NOTARY_TEAM_ID)" --password "$(MAC_NOTARY_APP_PASSWORD)" --wait; \
	else \
		echo "❌ Configure MAC_NOTARYTOOL_PROFILE or MAC_NOTARY_APPLE_ID + MAC_NOTARY_TEAM_ID + MAC_NOTARY_APP_PASSWORD."; \
		exit 1; \
	fi
	@echo "📎 Stapling app..."
	xcrun stapler staple -v "$(MAC_RELEASE_X86_64_APP_PATH)"
	@echo "🔎 Validating stapled app..."
	xcrun stapler validate -v "$(MAC_RELEASE_X86_64_APP_PATH)"
	spctl -a -vv -t exec "$(MAC_RELEASE_X86_64_APP_PATH)"
	rm -f "$(MAC_RELEASE_X86_64_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(MAC_RELEASE_X86_64_APP_PATH)" "$(MAC_RELEASE_X86_64_ZIP)"
	@echo "✅ Notarized app + zip ready: $(MAC_RELEASE_X86_64_APP_PATH)"

mac-notarized-release-assets:
	@$(MAKE) dist-reset-release
	@$(MAKE) mac-notarize-arm64
	@$(MAKE) mac-notarize-x86_64
	@echo "✅ Notarized release assets ready in $(MAC_RELEASE_DIST)"

mac-package-dmg-arm64:
	@echo "📀 Packaging macOS DMG (arm64)..."
	rm -rf "$(MAC_RELEASE_DMG_STAGING)/arm64"
	mkdir -p "$(MAC_RELEASE_DMG_STAGING)/arm64"
	cp -R "$(MAC_RELEASE_ARM64_APP_PATH)" "$(MAC_RELEASE_DMG_STAGING)/arm64/"
	ln -s /Applications "$(MAC_RELEASE_DMG_STAGING)/arm64/Applications"
	rm -f "$(MAC_RELEASE_ARM64_DMG)"
	hdiutil create -volname "$(MAC_RELEASE_DMG_VOLUME_NAME)" -srcfolder "$(MAC_RELEASE_DMG_STAGING)/arm64" -ov -format UDZO "$(MAC_RELEASE_ARM64_DMG)"

mac-package-dmg-x86_64:
	@echo "📀 Packaging macOS DMG (x86_64)..."
	rm -rf "$(MAC_RELEASE_DMG_STAGING)/x86_64"
	mkdir -p "$(MAC_RELEASE_DMG_STAGING)/x86_64"
	cp -R "$(MAC_RELEASE_X86_64_APP_PATH)" "$(MAC_RELEASE_DMG_STAGING)/x86_64/"
	ln -s /Applications "$(MAC_RELEASE_DMG_STAGING)/x86_64/Applications"
	rm -f "$(MAC_RELEASE_X86_64_DMG)"
	hdiutil create -volname "$(MAC_RELEASE_DMG_VOLUME_NAME)" -srcfolder "$(MAC_RELEASE_DMG_STAGING)/x86_64" -ov -format UDZO "$(MAC_RELEASE_X86_64_DMG)"

mac-dmg-arm64: mac-release-arm64
	@$(MAKE) mac-package-dmg-arm64

mac-dmg-x86_64: mac-release-x86_64
	@$(MAKE) mac-package-dmg-x86_64

mac-dmg-assets:
	@$(MAKE) dist-reset-release
	@$(MAKE) mac-dmg-arm64
	@$(MAKE) mac-dmg-x86_64
	@echo "✅ DMG assets ready in $(MAC_RELEASE_DIST)"

mac-dmg-notarized-arm64: mac-notarize-arm64
	@$(MAKE) mac-package-dmg-arm64
	@echo "🔏 Signing DMG (arm64)..."
	codesign --force --sign "$(MAC_RELEASE_SIGN_IDENTITY)" --timestamp "$(MAC_RELEASE_ARM64_DMG)"
	@echo "📀 Notarizing macOS DMG (arm64)..."
	@$(MAKE) mac-notarize-file FILE="$(MAC_RELEASE_ARM64_DMG)" KIND=dmg
	@echo "✅ Notarized DMG ready: $(MAC_RELEASE_ARM64_DMG)"

mac-dmg-notarized-x86_64: mac-notarize-x86_64
	@$(MAKE) mac-package-dmg-x86_64
	@echo "🔏 Signing DMG (x86_64)..."
	codesign --force --sign "$(MAC_RELEASE_SIGN_IDENTITY)" --timestamp "$(MAC_RELEASE_X86_64_DMG)"
	@echo "📀 Notarizing macOS DMG (x86_64)..."
	@$(MAKE) mac-notarize-file FILE="$(MAC_RELEASE_X86_64_DMG)" KIND=dmg
	@echo "✅ Notarized DMG ready: $(MAC_RELEASE_X86_64_DMG)"

mac-dmg-notarized-assets:
	@$(MAKE) dist-reset-release
	@$(MAKE) mac-dmg-notarized-arm64
	@$(MAKE) mac-dmg-notarized-x86_64
	@echo "✅ Notarized DMG assets ready in $(MAC_RELEASE_DIST)"

mac-notarize-file:
	@echo "📨 Submitting $(FILE) for notarization..."
	@if [ -z "$(FILE)" ]; then \
		echo "❌ FILE is required."; \
		exit 1; \
	fi
	@if [ -n "$(MAC_NOTARYTOOL_PROFILE)" ]; then \
		xcrun notarytool submit "$(FILE)" --keychain-profile "$(MAC_NOTARYTOOL_PROFILE)" --wait; \
	elif [ -n "$(MAC_NOTARY_APPLE_ID)" ] && [ -n "$(MAC_NOTARY_TEAM_ID)" ] && [ -n "$(MAC_NOTARY_APP_PASSWORD)" ]; then \
		xcrun notarytool submit "$(FILE)" --apple-id "$(MAC_NOTARY_APPLE_ID)" --team-id "$(MAC_NOTARY_TEAM_ID)" --password "$(MAC_NOTARY_APP_PASSWORD)" --wait; \
	else \
		echo "❌ Configure MAC_NOTARYTOOL_PROFILE or MAC_NOTARY_APPLE_ID + MAC_NOTARY_TEAM_ID + MAC_NOTARY_APP_PASSWORD."; \
		exit 1; \
	fi
	@echo "📎 Stapling $(FILE)..."
	xcrun stapler staple -v "$(FILE)"
	@echo "🔎 Validating stapled $(FILE)..."
	xcrun stapler validate -v "$(FILE)"
	@if [ "$(KIND)" = "app" ]; then \
		spctl -a -vv -t exec "$(FILE)"; \
	elif [ "$(KIND)" = "dmg" ]; then \
		spctl -a -vv -t open --context context:primary-signature "$(FILE)"; \
	else \
		echo "❌ KIND must be app or dmg."; \
		exit 1; \
	fi

ios-app:
	@echo "📱 Building iOS App..."
	xcodebuild build -workspace iCherri.xcworkspace -scheme $(IOS_SCHEME) -destination 'generic/platform=iOS' -derivedDataPath $(IOS_DERIVED_DATA)

ios-run:
	@echo "📱 Building, installing, and launching iOS app..."
	@DEVICE_ID="$${IOS_DEVICE_ID:-$$(xcodebuild -workspace iCherri.xcworkspace -scheme "$(IOS_SCHEME)" -showdestinations 2>/dev/null | grep "platform:iOS, arch:arm64" | sed -n "s/.*id:\([^,}]*\).*/\1/p" | head -1)}"; \
	if [ -z "$$DEVICE_ID" ]; then \
		DEVICE_ID="$$(xcrun devicectl list devices 2>/dev/null | grep -E "iPhone|iPad" | awk '{for(i=1;i<=NF;i++) if($$i ~ /^[0-9A-FA-F-]{36}$$/) {print $$i; exit}}')"; \
	fi; \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "❌ No connected iOS device found. Connect and unlock a device, or run: IOS_DEVICE_ID=<udid> make ios-run"; \
		exit 1; \
	fi; \
	echo "📲 Using device $$DEVICE_ID"; \
	xcodebuild build -workspace iCherri.xcworkspace -scheme "$(IOS_SCHEME)" -destination "id=$$DEVICE_ID" -derivedDataPath "$(IOS_DERIVED_DATA)" || exit 1; \
	xcrun devicectl device install app --device "$$DEVICE_ID" "$(IOS_APP_PATH)"; \
	xcrun devicectl device process launch --device "$$DEVICE_ID" --terminate-existing "$(IOS_BUNDLE_ID)"

ios-console:
	@echo "📟 Launching iOS app with console attached..."
	@DEVICE_ID="$${IOS_DEVICE_ID:-$$(xcodebuild -workspace iCherri.xcworkspace -scheme "$(IOS_SCHEME)" -showdestinations 2>/dev/null | grep "platform:iOS, arch:arm64" | sed -n "s/.*id:\([^,}]*\).*/\1/p" | head -1)}"; \
	if [ -z "$$DEVICE_ID" ]; then \
		DEVICE_ID="$$(xcrun devicectl list devices 2>/dev/null | grep -E "iPhone|iPad" | awk '{for(i=1;i<=NF;i++) if($$i ~ /^[0-9A-FA-F-]{36}$$/) {print $$i; exit}}')"; \
	fi; \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "❌ No connected iOS device found. Connect and unlock a device, or run: IOS_DEVICE_ID=<udid> make ios-console"; \
		exit 1; \
	fi; \
	echo "📲 Using device $$DEVICE_ID"; \
	xcrun devicectl device process launch --device "$$DEVICE_ID" --terminate-existing --console "$(IOS_BUNDLE_ID)"

ios-dev:
	@DEVICE_ID="$${IOS_DEVICE_ID:-$$(xcodebuild -workspace iCherri.xcworkspace -scheme "$(IOS_SCHEME)" -showdestinations 2>/dev/null | grep "platform:iOS, arch:arm64" | sed -n "s/.*id:\([^,}]*\).*/\1/p" | head -1)}"; \
	IOS_DEVICE_ID="$$DEVICE_ID" $(MAKE) ios-run; \
	IOS_DEVICE_ID="$$DEVICE_ID" $(MAKE) ios-console

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
	@echo "  make mac-notarize-arm64 - Build, notarize, staple, and re-zip Apple Silicon macOS app"
	@echo "  make mac-notarize-x86_64 - Build, notarize, staple, and re-zip Intel macOS app"
	@echo "  make mac-notarized-release-assets - Build notarized zip assets for both macOS arches"
	@echo "  make mac-dmg-arm64      - Build and package Apple Silicon macOS DMG"
	@echo "  make mac-dmg-x86_64     - Build and package Intel macOS DMG"
	@echo "  make mac-dmg-assets     - Build both macOS DMG assets"
	@echo "  make mac-dmg-notarized-arm64 - Build, notarize, staple, and verify Apple Silicon DMG"
	@echo "  make mac-dmg-notarized-x86_64 - Build, notarize, staple, and verify Intel DMG"
	@echo "  make mac-dmg-notarized-assets - Build notarized DMG assets for both macOS arches"
	@echo "  make ios-app     - Build iOS SwiftUI App"
	@echo "  make ios-run     - Build, install, and launch iOS app on a connected device"
	@echo "  make ios-console - Attach terminal to iOS app console on a connected device"
	@echo "  make ios-dev     - Build, launch, and attach iOS console"
	@echo "  make clean       - Remove app build artifacts"
