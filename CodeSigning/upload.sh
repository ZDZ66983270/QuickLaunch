#!/bin/bash

# QuickLaunch App Store Upload Script
# This script uploads the signed app to App Store Connect

set -e

APP_NAME="QuickLaunch"
VERSION="1.3.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if xcrun is available
    if ! command -v xcrun &> /dev/null; then
        log_error "xcrun not found. Please install Xcode command line tools."
        exit 1
    fi

    # Check if altool is available
    if ! xcrun altool --help &> /dev/null; then
        log_error "altool not found. Please ensure Xcode is properly installed."
        exit 1
    fi

    log_info "Prerequisites check passed"
}

setup_credentials() {
    log_info "Setting up App Store Connect credentials..."

    if [ -z "$APPLE_ID" ]; then
        echo -n "Enter your Apple ID email: "
        read APPLE_ID
    fi

    if [ -z "$APP_SPECIFIC_PASSWORD" ]; then
        echo "You need an app-specific password for your Apple ID."
        echo "Generate one at: https://appleid.apple.com/account/manage"
        echo -n "Enter app-specific password: "
        read -s APP_SPECIFIC_PASSWORD
        echo
    fi

    # Store in keychain for security
    log_info "Storing credentials in keychain..."
    xcrun altool --store-password-in-keychain-item "AC_PASSWORD" \
        -u "$APPLE_ID" -p "$APP_SPECIFIC_PASSWORD"

    export APPLE_ID
}

validate_package() {
    local pkg_file="$1"

    log_info "Validating package: $pkg_file"

    if [ ! -f "$pkg_file" ]; then
        log_error "Package file not found: $pkg_file"
        exit 1
    fi

    # Validate the package
    xcrun altool --validate-app -f "$pkg_file" \
        --type osx \
        --username "$APPLE_ID" \
        --password "@keychain:AC_PASSWORD"

    log_info "Package validation completed"
}

upload_to_app_store() {
    local pkg_file="$1"

    log_info "Uploading to App Store Connect: $pkg_file"

    # Upload to App Store Connect
    xcrun altool --upload-app -f "$pkg_file" \
        --type osx \
        --username "$APPLE_ID" \
        --password "@keychain:AC_PASSWORD"

    log_info "Upload completed successfully!"
    log_info "Your app will appear in App Store Connect within a few minutes."
}

notarize_package() {
    local pkg_file="$1"

    log_info "Submitting for notarization: $pkg_file"

    # Submit for notarization (for non-App Store distribution)
    local request_uuid=$(xcrun altool --notarize-app \
        --primary-bundle-id "com.quicklaunch.macos" \
        --username "$APPLE_ID" \
        --password "@keychain:AC_PASSWORD" \
        --file "$pkg_file" | grep "RequestUUID" | awk '{print $3}')

    if [ -n "$request_uuid" ]; then
        log_info "Notarization submitted. RequestUUID: $request_uuid"
        log_info "You can check status with:"
        log_info "xcrun altool --notarization-info $request_uuid --username '$APPLE_ID' --password '@keychain:AC_PASSWORD'"

        # Wait for notarization (this can take several minutes)
        log_info "Waiting for notarization to complete..."
        local status="in progress"
        local attempts=0
        local max_attempts=20

        while [ "$status" = "in progress" ] && [ $attempts -lt $max_attempts ]; do
            sleep 30
            attempts=$((attempts + 1))
            log_info "Checking notarization status... (attempt $attempts/$max_attempts)"

            local result=$(xcrun altool --notarization-info "$request_uuid" \
                --username "$APPLE_ID" \
                --password "@keychain:AC_PASSWORD" 2>/dev/null || true)

            if echo "$result" | grep -q "Status: success"; then
                status="success"
                log_info "Notarization completed successfully!"

                # Staple the notarization
                log_info "Stapling notarization ticket..."
                xcrun stapler staple "$pkg_file"
                log_info "Notarization stapled successfully"
                break
            elif echo "$result" | grep -q "Status: invalid"; then
                status="invalid"
                log_error "Notarization failed!"
                echo "$result"
                exit 1
            fi
        done

        if [ "$status" = "in progress" ]; then
            log_warn "Notarization is still in progress. Check status manually."
        fi
    else
        log_error "Failed to submit for notarization"
        exit 1
    fi
}

show_usage() {
    echo "Usage: $0 [OPTIONS] <package-file>"
    echo "Options:"
    echo "  --validate-only    Only validate, don't upload"
    echo "  --notarize        Notarize for direct distribution (non-App Store)"
    echo "  --help            Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  APPLE_ID                 Your Apple ID email"
    echo "  APP_SPECIFIC_PASSWORD    App-specific password"
}

# Parse command line arguments
VALIDATE_ONLY=false
NOTARIZE=false

while [[ $# -gt 1 ]]; do
    case $1 in
        --validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        --notarize)
            NOTARIZE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -eq 0 ]; then
    log_error "No package file specified"
    show_usage
    exit 1
fi

PKG_FILE="$1"

# Main execution
log_info "Starting upload process for $APP_NAME v$VERSION"

check_prerequisites
setup_credentials
validate_package "$PKG_FILE"

if [ "$VALIDATE_ONLY" = true ]; then
    log_info "Validation completed. Skipping upload as requested."
    exit 0
fi

if [ "$NOTARIZE" = true ]; then
    notarize_package "$PKG_FILE"
else
    upload_to_app_store "$PKG_FILE"
    log_info ""
    log_info "Next steps:"
    log_info "1. Go to App Store Connect (https://appstoreconnect.apple.com)"
    log_info "2. Navigate to your app"
    log_info "3. Go to the TestFlight tab to test the build"
    log_info "4. Submit for App Store review when ready"
fi