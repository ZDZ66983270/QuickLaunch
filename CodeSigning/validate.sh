#!/bin/bash

# QuickLaunch Validation Script
# This script validates the app before submission to App Store

set -e

APP_NAME="QuickLaunch"
BUNDLE_ID="com.quicklaunch.macos"

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

check_app_bundle() {
    log_info "Checking app bundle structure..."

    if [ ! -d "build/$APP_NAME.app" ]; then
        log_error "App bundle not found!"
        return 1
    fi

    # Check required directories
    local required_dirs=(
        "build/$APP_NAME.app/Contents"
        "build/$APP_NAME.app/Contents/MacOS"
        "build/$APP_NAME.app/Contents/Resources"
    )

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "Required directory missing: $dir"
            return 1
        fi
    done

    # Check required files
    local required_files=(
        "build/$APP_NAME.app/Contents/Info.plist"
        "build/$APP_NAME.app/Contents/MacOS/$APP_NAME"
    )

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required file missing: $file"
            return 1
        fi
    done

    log_info "App bundle structure is valid"
}

check_info_plist() {
    log_info "Validating Info.plist..."

    local plist_path="build/$APP_NAME.app/Contents/Info.plist"

    # Check bundle identifier
    local bundle_id=$(plutil -extract CFBundleIdentifier raw "$plist_path")
    if [ "$bundle_id" != "$BUNDLE_ID" ]; then
        log_error "Bundle ID mismatch: expected $BUNDLE_ID, got $bundle_id"
        return 1
    fi

    # Check required keys
    local required_keys=(
        "CFBundleExecutable"
        "CFBundleIdentifier"
        "CFBundleName"
        "CFBundleVersion"
        "CFBundleShortVersionString"
        "LSMinimumSystemVersion"
    )

    for key in "${required_keys[@]}"; do
        if ! plutil -extract "$key" raw "$plist_path" >/dev/null 2>&1; then
            log_error "Required Info.plist key missing: $key"
            return 1
        fi
    done

    # Check minimum system version
    local min_version=$(plutil -extract LSMinimumSystemVersion raw "$plist_path")
    if [ "$min_version" != "14.0" ]; then
        log_warn "Minimum system version is $min_version (expected 14.0)"
    fi

    log_info "Info.plist validation passed"
}

check_code_signature() {
    log_info "Validating code signature..."

    local app_path="build/$APP_NAME.app"

    # Check if app is signed
    if ! codesign -dv "$app_path" >/dev/null 2>&1; then
        log_error "App is not code signed!"
        return 1
    fi

    # Verify signature
    if ! codesign --verify --deep --strict "$app_path" >/dev/null 2>&1; then
        log_error "Code signature verification failed!"
        return 1
    fi

    # Check entitlements
    if ! codesign -d --entitlements :- "$app_path" | grep -q "app-sandbox"; then
        log_warn "App Sandbox entitlement not found"
    fi

    log_info "Code signature validation passed"
}

check_executable_permissions() {
    log_info "Checking executable permissions..."

    local executable_path="build/$APP_NAME.app/Contents/MacOS/$APP_NAME"

    if [ ! -x "$executable_path" ]; then
        log_error "Main executable is not executable!"
        return 1
    fi

    log_info "Executable permissions are correct"
}

check_app_sandbox_compatibility() {
    log_info "Checking App Sandbox compatibility..."

    # This is a basic check - full sandbox testing requires running the app
    local entitlements=$(codesign -d --entitlements :- "build/$APP_NAME.app" 2>/dev/null)

    if echo "$entitlements" | grep -q "com.apple.security.app-sandbox.*true"; then
        log_info "App Sandbox is enabled"
    else
        log_warn "App Sandbox might not be properly configured"
    fi

    # Check for potentially problematic entitlements
    if echo "$entitlements" | grep -q "com.apple.security.temporary-exception"; then
        log_warn "Temporary exceptions found - ensure they are justified"
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."

    local executable_path="build/$APP_NAME.app/Contents/MacOS/$APP_NAME"

    # Check for external dependencies
    local external_deps=$(otool -L "$executable_path" | grep -v "^$executable_path:" | grep -v "@rpath" | grep -v "/System/" | grep -v "/usr/lib/")

    if [ -n "$external_deps" ]; then
        log_warn "External dependencies found:"
        echo "$external_deps"
    else
        log_info "No problematic external dependencies found"
    fi
}

run_basic_functionality_test() {
    log_info "Running basic functionality test..."

    # This launches the app briefly to check if it starts
    timeout 5s open "build/$APP_NAME.app" || true
    sleep 2

    # Check if the process started (basic test)
    if pgrep -x "$APP_NAME" >/dev/null; then
        log_info "App launches successfully"
        # Kill the test instance
        pkill -x "$APP_NAME" || true
    else
        log_warn "Could not verify app launch (this might be normal in some environments)"
    fi
}

validate_for_app_store() {
    log_info "Running App Store specific validations..."

    # Check for prohibited APIs or frameworks
    local executable_path="build/$APP_NAME.app/Contents/MacOS/$APP_NAME"

    # Check for private frameworks (basic check)
    if otool -L "$executable_path" | grep -q "PrivateFrameworks"; then
        log_error "Private frameworks detected - not allowed in App Store!"
        return 1
    fi

    # Check app category in Info.plist
    local plist_path="build/$APP_NAME.app/Contents/Info.plist"
    if plutil -extract LSApplicationCategoryType raw "$plist_path" >/dev/null 2>&1; then
        local category=$(plutil -extract LSApplicationCategoryType raw "$plist_path")
        log_info "App category: $category"
    fi

    log_info "App Store validation checks passed"
}

show_summary() {
    log_info "Validation Summary:"
    log_info "=================="

    local app_path="build/$APP_NAME.app"
    local plist_path="$app_path/Contents/Info.plist"

    echo "App Name: $(plutil -extract CFBundleName raw "$plist_path")"
    echo "Bundle ID: $(plutil -extract CFBundleIdentifier raw "$plist_path")"
    echo "Version: $(plutil -extract CFBundleShortVersionString raw "$plist_path")"
    echo "Build: $(plutil -extract CFBundleVersion raw "$plist_path")"
    echo "Min macOS: $(plutil -extract LSMinimumSystemVersion raw "$plist_path")"

    local size=$(du -sh "$app_path" | cut -f1)
    echo "App Size: $size"

    if codesign -dv "$app_path" 2>&1 | grep -q "Authority="; then
        echo "Signed with: $(codesign -dv "$app_path" 2>&1 | grep "Authority=" | head -1)"
    fi
}

# Main execution
log_info "Starting validation for $APP_NAME..."

# Run all validation checks
check_app_bundle || exit 1
check_info_plist || exit 1
check_executable_permissions || exit 1
check_code_signature || exit 1
check_app_sandbox_compatibility
check_dependencies
validate_for_app_store || exit 1
run_basic_functionality_test

show_summary

log_info "All validation checks completed successfully!"
log_info "The app appears ready for App Store submission."