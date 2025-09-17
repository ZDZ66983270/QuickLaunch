.PHONY: build run clean app

build:
	@echo "Building LaunchPad Clone..."
	swift build -c release
	@echo "Copying build results to visible directory..."
	@mkdir -p build
	@cp -r .build/release/* build/ 2>/dev/null || true
	@echo "Build results available in build/ directory"

run:
	@echo "Running LaunchPad Clone..."
	swift run

app:
	@echo "Creating macOS app bundle..."
	@mkdir -p build/LaunchPadClone.app/Contents/MacOS
	@mkdir -p build/LaunchPadClone.app/Contents/Resources
	@cp Info.plist build/LaunchPadClone.app/Contents/
	@swift build -c release
	@cp .build/release/LaunchPadClone build/LaunchPadClone.app/Contents/MacOS/
	@echo "App bundle created at build/LaunchPadClone.app"
	@echo "You can run it with: open build/LaunchPadClone.app"

clean:
	@echo "Cleaning build files..."
	rm -rf .build
	rm -rf build

install: app
	@echo "Installing to /Applications..."
	@cp -r build/LaunchPadClone.app /Applications/
	@echo "LaunchPad Clone installed to /Applications"