APP_NAME = PWManager
BUNDLE = $(APP_NAME).app
BUILD_DIR = .build/release
BINARY = $(BUILD_DIR)/PWManagerApp

.PHONY: build bundle run clean debug

# Release build
build:
	swift build -c release --product PWManagerApp

# Debug build
debug:
	swift build --product PWManagerApp

# Create .app bundle with Touch ID entitlements
bundle: build
	@echo "Creating $(BUNDLE)..."
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	@cp $(BINARY) $(BUNDLE)/Contents/MacOS/PWManagerApp
	@cp Sources/PWManagerApp/Info.plist $(BUNDLE)/Contents/
	@echo "Signing with entitlements..."
	@codesign --force --sign - --entitlements entitlements.plist $(BUNDLE)/Contents/MacOS/PWManagerApp
	@echo "$(BUNDLE) created successfully"

# Build, bundle, and run
run: bundle
	@open $(BUNDLE)

# Run debug build directly (no Touch ID)
run-debug: debug
	@$(BUILD_DIR:release=debug)/PWManagerApp

# Install to /Applications
install: bundle
	@echo "Installing to /Applications/$(BUNDLE)..."
	@rm -rf /Applications/$(BUNDLE)
	@cp -R $(BUNDLE) /Applications/
	@echo "Installed. Launch from Applications or Spotlight."

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(BUNDLE)

# Run tests
test:
	swift test
