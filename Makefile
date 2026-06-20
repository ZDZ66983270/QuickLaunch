.PHONY: build run clean app icons generate-png dist dmg

build:
	@echo "Building QuickLaunch..."
	swift build -c release --build-path build-temp
	@echo "Copying build results to visible directory..."
	@mkdir -p build
	@cp -r build-temp/release/* build/ 2>/dev/null || true
	@echo "Build results available in build/ directory"

run:
	@echo "Running QuickLaunch..."
	swift run --build-path build-temp

generate-png:
	@echo "Generating PNG icons from SVG..."
	@if [ -f "Resources/AppIcon.iconset/icon_512x512@2x.png" ]; then \
		echo "Existing iconset detected, skipping PNG regeneration."; \
	elif [ -f "icon.svg" ]; then \
		./generate_icons.sh; \
	else \
		echo "Error: icon.svg not found in current directory"; \
		echo "Please place your icon.svg file in the project root"; \
		exit 1; \
	fi

icons:
	@echo "Generating app icon..."
	@if [ -f "Resources/AppIcon.icns" ]; then \
		echo "Existing AppIcon.icns detected, skipping icon generation."; \
	elif [ -d "Resources/AppIcon.iconset" ]; then \
		iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns; \
		echo "Icon generated: Resources/AppIcon.icns"; \
	elif [ -f "icon.svg" ]; then \
		$(MAKE) generate-png; \
		iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns; \
		echo "Icon generated: Resources/AppIcon.icns"; \
	else \
		echo "Error: no icon resources available"; \
		exit 1; \
	fi

app: icons
	@echo "Creating macOS app bundle..."
	@mkdir -p build/QuickLaunch.app/Contents/MacOS
	@mkdir -p build/QuickLaunch.app/Contents/Resources
	@cp Info.plist build/QuickLaunch.app/Contents/
	@cp Resources/AppIcon.icns build/QuickLaunch.app/Contents/Resources/
	@echo "Building Swift project..."
	@rm -rf build-temp
	@swift build -c release --build-path build-temp
	@cp build-temp/release/QuickLaunch build/QuickLaunch.app/Contents/MacOS/
	@echo "App bundle created at build/QuickLaunch.app"
	@echo "You can run it with: open build/QuickLaunch.app"

dist: app
	@echo "Creating portable distribution..."
	@./package_portable.sh

dmg: dist
	@echo "Creating DMG distribution..."
	@./package_dmg.sh

clean:
	@echo "Cleaning build files..."
	rm -rf build/QuickLaunch.app
	rm -rf build-temp
	rm -rf dist
	rm -rf dmg-temp

install: app
	@echo "Installing to /Applications..."
	@cp -r build/QuickLaunch.app /Applications/
	@echo "QuickLaunch installed to /Applications"
