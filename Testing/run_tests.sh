#!/bin/bash

# QuickLaunch Automated Testing Script
# This script runs automated tests and basic functionality checks

set -e

# Configuration
APP_NAME="QuickLaunch"
TEST_RESULTS_DIR="Testing/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$TEST_RESULTS_DIR/test_run_$TIMESTAMP.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$LOG_FILE"
}

start_test() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Starting: $1"
}

pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log_info "✓ PASS: $1"
}

fail_test() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_error "✗ FAIL: $1"
}

skip_test() {
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    log_warn "○ SKIP: $1"
}

setup_test_environment() {
    log_info "Setting up test environment..."

    # Create results directory
    mkdir -p "$TEST_RESULTS_DIR"

    # Initialize log file
    echo "QuickLaunch Test Run - $(date)" > "$LOG_FILE"
    echo "======================================" >> "$LOG_FILE"

    # System information
    echo "System Information:" >> "$LOG_FILE"
    echo "macOS Version: $(sw_vers -productVersion)" >> "$LOG_FILE"
    echo "Hardware: $(sysctl -n hw.model)" >> "$LOG_FILE"
    echo "Architecture: $(uname -m)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    log_info "Test environment ready"
}

test_build_system() {
    start_test "Build System"

    # Test clean build
    if make clean >/dev/null 2>&1; then
        log_info "Clean build successful"
    else
        fail_test "Clean build failed"
        return 1
    fi

    # Test Swift build
    if swift build -c release >/dev/null 2>&1; then
        log_info "Swift build successful"
    else
        fail_test "Swift build failed"
        return 1
    fi

    # Test app bundle creation
    if make app >/dev/null 2>&1; then
        log_info "App bundle creation successful"
        pass_test "Build System"
    else
        fail_test "App bundle creation failed"
        return 1
    fi
}

test_app_bundle_structure() {
    start_test "App Bundle Structure"

    local app_path="build/$APP_NAME.app"

    # Check if app bundle exists
    if [ ! -d "$app_path" ]; then
        fail_test "App bundle not found: $app_path"
        return 1
    fi

    # Check required directories
    local required_dirs=(
        "$app_path/Contents"
        "$app_path/Contents/MacOS"
        "$app_path/Contents/Resources"
    )

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            fail_test "Required directory missing: $dir"
            return 1
        fi
    done

    # Check required files
    local required_files=(
        "$app_path/Contents/Info.plist"
        "$app_path/Contents/MacOS/$APP_NAME"
    )

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            fail_test "Required file missing: $file"
            return 1
        fi
    done

    # Check executable permissions
    if [ ! -x "$app_path/Contents/MacOS/$APP_NAME" ]; then
        fail_test "Main executable is not executable"
        return 1
    fi

    pass_test "App Bundle Structure"
}

test_info_plist() {
    start_test "Info.plist Validation"

    local plist_path="build/$APP_NAME.app/Contents/Info.plist"

    # Check if Info.plist exists and is valid
    if ! plutil -lint "$plist_path" >/dev/null 2>&1; then
        fail_test "Info.plist is not valid"
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
            fail_test "Required Info.plist key missing: $key"
            return 1
        fi
    done

    # Check specific values
    local bundle_id=$(plutil -extract CFBundleIdentifier raw "$plist_path")
    if [ "$bundle_id" != "com.quicklaunch.macos" ]; then
        fail_test "Incorrect bundle identifier: $bundle_id"
        return 1
    fi

    local min_version=$(plutil -extract LSMinimumSystemVersion raw "$plist_path")
    if [ "$min_version" != "14.0" ]; then
        log_warn "Minimum system version is $min_version (expected 14.0)"
    fi

    pass_test "Info.plist Validation"
}

test_app_launch() {
    start_test "Application Launch"

    local app_path="build/$APP_NAME.app"

    # Launch app in background
    log_info "Launching $APP_NAME for testing..."
    open "$app_path" &

    # Wait for app to start
    sleep 5

    # Check if app is running
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        log_info "Application launched successfully"

        # Try to terminate gracefully
        if pkill -x "$APP_NAME"; then
            log_info "Application terminated gracefully"
            pass_test "Application Launch"
        else
            log_warn "Application termination required force kill"
            pass_test "Application Launch (with warnings)"
        fi
    else
        fail_test "Application failed to launch or exited immediately"
        return 1
    fi
}

test_memory_usage() {
    start_test "Memory Usage"

    local app_path="build/$APP_NAME.app"

    # Launch app and wait for it to start
    open "$app_path" &
    sleep 5

    # Wait for app to appear in process list
    local timeout=10
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Check if app is running
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        local memory_usage=$(ps -o rss= -p "$(pgrep -x "$APP_NAME")" 2>/dev/null || echo "0")
        memory_usage=$((memory_usage / 1024)) # Convert to MB

        log_info "Memory usage: ${memory_usage}MB"

        # Check if memory usage is reasonable (under 100MB for a simple launcher)
        if [ "$memory_usage" -lt 100 ]; then
            pass_test "Memory Usage (${memory_usage}MB)"
        elif [ "$memory_usage" -lt 200 ]; then
            log_warn "Memory usage is high but acceptable: ${memory_usage}MB"
            pass_test "Memory Usage (${memory_usage}MB - High)"
        else
            fail_test "Excessive memory usage: ${memory_usage}MB"
        fi

        # Clean up
        pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    else
        fail_test "Application not running for memory test"
    fi
}

test_file_permissions() {
    start_test "File Permissions"

    local app_path="build/$APP_NAME.app"

    # Check app bundle permissions
    if [ ! -r "$app_path" ]; then
        fail_test "App bundle is not readable"
        return 1
    fi

    # Check executable permissions
    local executable_path="$app_path/Contents/MacOS/$APP_NAME"
    if [ ! -x "$executable_path" ]; then
        fail_test "Main executable lacks execute permissions"
        return 1
    fi

    # Check for excessive permissions
    local permissions=$(stat -f "%Mp%Lp" "$executable_path")
    if [[ "$permissions" == *"w"* ]]; then
        log_warn "Executable has write permissions - potential security issue"
    fi

    pass_test "File Permissions"
}

test_icon_resources() {
    start_test "Icon Resources"

    local resources_path="build/$APP_NAME.app/Contents/Resources"

    # Check if app icon exists (could be in various formats)
    local icon_found=false

    if [ -f "$resources_path/AppIcon.icns" ]; then
        icon_found=true
        log_info "Found AppIcon.icns"
    fi

    # Check for icon sets in bundle resources
    if find "$resources_path" -name "*.png" | grep -q icon; then
        icon_found=true
        log_info "Found icon PNG resources"
    fi

    # Check resource bundle
    if ls build/*_*.bundle >/dev/null 2>&1; then
        if find build/*_*.bundle -name "*.png" | head -1 | xargs file | grep -q "PNG image"; then
            icon_found=true
            log_info "Found icon resources in bundle"
        fi
    fi

    if [ "$icon_found" = true ]; then
        pass_test "Icon Resources"
    else
        log_warn "No app icons found - app will use default icon"
        skip_test "Icon Resources (not found)"
    fi
}

test_dependencies() {
    start_test "Dependencies Check"

    local executable_path="build/$APP_NAME.app/Contents/MacOS/$APP_NAME"

    # Check for external dependencies
    local external_deps=$(otool -L "$executable_path" | grep -v "^$executable_path:" | grep -v "@rpath" | grep -v "/System/" | grep -v "/usr/lib/" | wc -l)

    if [ "$external_deps" -eq 0 ]; then
        log_info "No external dependencies found"
        pass_test "Dependencies Check"
    else
        log_warn "External dependencies found:"
        otool -L "$executable_path" | grep -v "^$executable_path:" | grep -v "@rpath" | grep -v "/System/" | grep -v "/usr/lib/" | tee -a "$LOG_FILE"
        pass_test "Dependencies Check (with external deps)"
    fi
}

run_performance_benchmark() {
    start_test "Performance Benchmark"

    local app_path="build/$APP_NAME.app"

    # Measure launch time
    log_info "Measuring launch time..."
    local start_time=$(date +%s%N)

    open "$app_path" &

    # Wait for app to appear in process list
    local launch_timeout=100
    local elapsed=0
    while [ $elapsed -lt $launch_timeout ]; do
        if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
        elapsed=$((elapsed + 1))
    done

    local end_time=$(date +%s%N)
    local launch_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds

    log_info "Launch time: ${launch_time}ms"

    # Clean up
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true

    # Evaluate performance
    if [ "$launch_time" -lt 2000 ]; then
        pass_test "Performance Benchmark (${launch_time}ms - Excellent)"
    elif [ "$launch_time" -lt 5000 ]; then
        pass_test "Performance Benchmark (${launch_time}ms - Good)"
    else
        log_warn "Launch time is slower than expected: ${launch_time}ms"
        pass_test "Performance Benchmark (${launch_time}ms - Slow)"
    fi
}

generate_test_report() {
    log_info "Generating test report..."

    local report_file="$TEST_RESULTS_DIR/test_report_$TIMESTAMP.html"

    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>QuickLaunch Test Report - $TIMESTAMP</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .pass { color: green; }
        .fail { color: red; }
        .skip { color: orange; }
        .log { background: #f9f9f9; padding: 10px; font-family: monospace; white-space: pre-wrap; }
    </style>
</head>
<body>
    <div class="header">
        <h1>QuickLaunch Test Report</h1>
        <p>Generated: $(date)</p>
        <p>System: macOS $(sw_vers -productVersion) ($(uname -m))</p>
    </div>

    <div class="summary">
        <h2>Test Summary</h2>
        <p>Total Tests: $TESTS_TOTAL</p>
        <p class="pass">Passed: $TESTS_PASSED</p>
        <p class="fail">Failed: $TESTS_FAILED</p>
        <p class="skip">Skipped: $TESTS_SKIPPED</p>
    </div>

    <div class="details">
        <h2>Test Details</h2>
        <div class="log">$(cat "$LOG_FILE")</div>
    </div>
</body>
</html>
EOF

    log_info "Test report saved to: $report_file"
}

show_test_summary() {
    echo ""
    echo "======================================"
    echo "           TEST SUMMARY"
    echo "======================================"
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed:      ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:      ${RED}$TESTS_FAILED${NC}"
    echo -e "Skipped:     ${YELLOW}$TESTS_SKIPPED${NC}"
    echo ""

    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo "The application appears ready for further testing."
    else
        echo -e "${RED}✗ Some tests failed.${NC}"
        echo "Please review the failures before proceeding."
    fi

    echo ""
    echo "Detailed log: $LOG_FILE"
    echo "======================================"
}

# Main execution
main() {
    log_info "Starting QuickLaunch test suite..."

    setup_test_environment

    # Run all tests
    test_build_system
    test_app_bundle_structure
    test_info_plist
    test_file_permissions
    test_icon_resources
    test_dependencies
    test_memory_usage
    run_performance_benchmark
    test_app_launch

    # Generate reports
    generate_test_report
    show_test_summary

    # Exit with appropriate code
    if [ "$TESTS_FAILED" -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Check if script should show usage
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "This script runs automated tests for QuickLaunch."
    echo "Results are saved in the Testing/results directory."
    exit 0
fi

# Run main function
main "$@"