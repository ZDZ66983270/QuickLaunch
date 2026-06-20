#!/bin/bash

# QuickLaunch Code Signing and Build Script
# This script builds, signs, and packages QuickLaunch for distribution

set -e  # Exit on any error

# Configuration
APP_NAME="QuickLaunch"
BUNDLE_ID="com.quicklaunch.macos"
VERSION="1.3.0"
BUILD_NUMBER="130"
ENTITLEMENTS="CodeSigning/QuickLaunch.entitlements"

# Certificate names (adjust based on your certificates)
APP_STORE_CERT="3rd Party Mac Developer Application"
INSTALLER_CERT="3rd Party Mac Developer Installer"
DEVELOPER_ID_APP="Developer ID Application"
DEVELOPER_ID_INSTALLER="Developer ID Installer"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_certificates() {
    log_info "Checking available certificates..."

    if ! security find-identity -v -p codesigning | grep -q "Mac Developer\|3rd Party Mac Developer"; then
        log_error "No Mac Developer certificates found!"
        log_info "Please install certificates from Apple Developer Portal"
        exit 1
    fi

    log_info "Certificates found:"
    security find-identity -v -p codesigning | grep "Mac Developer\|3rd Party Mac Developer"
}

clean_build() {
    log_info "Cleaning previous builds..."
    make clean
    rm -rf build/
    rm -f *.pkg
    rm -f *.dmg
}

build_app() {
    log_info "Building $APP_NAME..."

    # Build with Swift Package Manager
    swift build -c release

    # Create app bundle
    make app

    if [ ! -d "build/$APP_NAME.app" ]; then
        log_error "App bundle not created!"
        exit 1
    fi

    log_info "App bundle created successfully"
}

sign_app() {
    local cert_name="$1"
    local build_type="$2"

    log_info "Code signing with certificate: $cert_name"

    # Sign the main executable and any embedded frameworks
    find "build/$APP_NAME.app" -type f -name "*.dylib" -exec codesign --force --verify --verbose --sign "$cert_name" --entitlements "$ENTITLEMENTS" {} \;
    find "build/$APP_NAME.app" -type f -name "*.framework" -exec codesign --force --verify --verbose --sign "$cert_name" --entitlements "$ENTITLEMENTS" {} \;

    # Sign the main app bundle
    codesign --force --verify --verbose --sign "$cert_name" \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        "build/$APP_NAME.app"

    log_info "Code signing completed"
}

verify_signature() {
    log_info "Verifying signature..."

    # Verify the signature
    codesign --verify --deep --strict --verbose=2 "build/$APP_NAME.app"

    # Check with spctl
    if spctl -a -t exec -vv "build/$APP_NAME.app" 2>/dev/null; then
        log_info "Signature verification passed"
    else
        log_warn "spctl verification failed (this is normal for some certificate types)"
    fi
}

create_installer_pkg() {
    local cert_name="$1"
    local output_name="$2"

    log_info "Creating installer package: $output_name"

    productbuild --component "build/$APP_NAME.app" /Applications \
        --sign "$cert_name" \
        --version "$VERSION" \
        "$output_name"

    if [ -f "$output_name" ]; then
        log_info "Installer package created: $output_name"

        # Verify the package
        pkgutil --check-signature "$output_name"
    else
        log_error "Failed to create installer package"
        exit 1
    fi
}

create_dmg() {
    local dmg_name="$APP_NAME-$VERSION.dmg"

    log_info "Creating DMG: $dmg_name"

    # Create temporary directory for DMG contents
    mkdir -p "dmg_temp"
    cp -R "build/$APP_NAME.app" "dmg_temp/"

    # Create symbolic link to Applications
    ln -s /Applications "dmg_temp/Applications"

    # Create DMG
    hdiutil create -volname "$APP_NAME" -srcfolder "dmg_temp" -ov -format UDZO "$dmg_name"

    # Clean up
    rm -rf "dmg_temp"

    log_info "DMG created: $dmg_name"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --app-store     Build for App Store (default)"
    echo "  --developer-id  Build with Developer ID for direct distribution"
    echo "  --clean         Clean build directory first"
    echo "  --dmg          Create DMG after building"
    echo "  --help         Show this help message"
}

# Parse command line arguments
BUILD_TYPE="app-store"
CLEAN_FIRST=false
CREATE_DMG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --app-store)
            BUILD_TYPE="app-store"
            shift
            ;;
        --developer-id)
            BUILD_TYPE="developer-id"
            shift
            ;;
        --clean)
            CLEAN_FIRST=true
            shift
            ;;
        --dmg)
            CREATE_DMG=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
log_info "Starting build process for $APP_NAME v$VERSION"
log_info "Build type: $BUILD_TYPE"

# Check prerequisites
check_certificates

# Clean if requested
if [ "$CLEAN_FIRST" = true ]; then
    clean_build
fi

# Build the app
build_app

# Sign based on build type
if [ "$BUILD_TYPE" = "app-store" ]; then
    sign_app "$APP_STORE_CERT" "app-store"
    verify_signature
    create_installer_pkg "$INSTALLER_CERT" "$APP_NAME-$VERSION-AppStore.pkg"
elif [ "$BUILD_TYPE" = "developer-id" ]; then
    sign_app "$DEVELOPER_ID_APP" "developer-id"
    verify_signature
    create_installer_pkg "$DEVELOPER_ID_INSTALLER" "$APP_NAME-$VERSION-DeveloperID.pkg"
fi

# Create DMG if requested
if [ "$CREATE_DMG" = true ]; then
    create_dmg
fi

log_info "Build process completed successfully!"
log_info "Output files:"
ls -la *.pkg *.dmg 2>/dev/null || true