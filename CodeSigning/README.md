# Code Signing and Distribution Guide for QuickLaunch

This guide covers the code signing and distribution setup needed for App Store submission and notarization.

## Prerequisites

Before proceeding with code signing, ensure you have:

1. **Apple Developer Account**
   - Active Apple Developer Program membership ($99/year)
   - Access to Apple Developer Portal
   - Xcode installed with command line tools

2. **Certificates Required**
   - Mac Developer Certificate (for development)
   - Mac App Store Certificate (for App Store distribution)
   - Developer ID Certificate (for direct distribution outside App Store)

## Step 1: Certificate Setup

### Check Existing Certificates
```bash
# List all certificates in keychain
security find-identity -v -p codesigning

# Check for specific certificate types
security find-identity -v -p macappstore
security find-identity -v -p basic
```

### Create Certificates (if needed)
1. Open Xcode
2. Go to Xcode → Preferences → Accounts
3. Add your Apple ID and sign in
4. Select your team and click "Manage Certificates"
5. Create required certificates:
   - Mac Development
   - Mac App Distribution
   - Developer ID Application (optional, for non-App Store distribution)

## Step 2: App Store Connect Setup

1. **Create App Record**
   - Go to App Store Connect (https://appstoreconnect.apple.com)
   - Create new macOS app
   - Bundle ID: `com.quicklaunch.macos`
   - Name: `QuickLaunch`

2. **Configure App Information**
   - Set category: Productivity → System Tools
   - Age rating: 4+
   - Price: Free

## Step 3: Entitlements Configuration

Create the entitlements file for App Store distribution:

### File: `QuickLaunch.entitlements`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Sandbox (required for App Store) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Read-only access to user's Applications folder -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>

    <!-- Network access (if needed for future features) -->
    <key>com.apple.security.network.client</key>
    <false/>

    <!-- Hardened Runtime -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <false/>
</dict>
</plist>
```

## Step 4: Build Script for Code Signing

Create a build script for automated signing:

### File: `build_signed.sh`
```bash
#!/bin/bash

# Configuration
APP_NAME="QuickLaunch"
BUNDLE_ID="com.quicklaunch.macos"
ENTITLEMENTS="CodeSigning/QuickLaunch.entitlements"
CERTIFICATE_NAME="3rd Party Mac Developer Application"

# Clean and build
echo "Building $APP_NAME..."
swift build -c release

# Create app bundle
echo "Creating app bundle..."
make app

# Sign the application
echo "Code signing..."
codesign --force --verify --verbose --sign "$CERTIFICATE_NAME" \
    --entitlements "$ENTITLEMENTS" \
    "build/$APP_NAME.app"

# Verify signature
echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "build/$APP_NAME.app"
spctl -a -t exec -vv "build/$APP_NAME.app"

echo "Code signing completed successfully!"
```

## Step 5: Packaging for App Store

### Create PKG for App Store submission:
```bash
# Build and sign the app first
./build_signed.sh

# Create installer package
productbuild --component "build/QuickLaunch.app" /Applications \
    --sign "3rd Party Mac Developer Installer" \
    "QuickLaunch-1.3.0.pkg"
```

## Step 6: Notarization (for non-App Store distribution)

If distributing outside the App Store, notarization is required:

```bash
# Create app-specific password in Apple ID account first
# Store credentials in keychain
xcrun altool --store-password-in-keychain-item "AC_PASSWORD" \
    -u "your-apple-id@email.com" -p "app-specific-password"

# Submit for notarization
xcrun altool --notarize-app --primary-bundle-id "$BUNDLE_ID" \
    --username "your-apple-id@email.com" \
    --password "@keychain:AC_PASSWORD" \
    --file "QuickLaunch-1.3.0.pkg"

# Check status (replace REQUEST_UUID with actual UUID from submission)
xcrun altool --notarization-info REQUEST_UUID \
    --username "your-apple-id@email.com" \
    --password "@keychain:AC_PASSWORD"

# Staple notarization ticket (after approval)
xcrun stapler staple "QuickLaunch-1.3.0.pkg"
```

## Step 7: Validation and Testing

### Pre-submission Validation:
```bash
# Validate app structure
xcrun altool --validate-app -f "QuickLaunch-1.3.0.pkg" \
    --type osx --username "your-apple-id@email.com" \
    --password "@keychain:AC_PASSWORD"

# Check for common issues
spctl --assess --verbose "build/QuickLaunch.app"
codesign --verify --deep --strict "build/QuickLaunch.app"
```

### App Store Upload:
```bash
# Upload to App Store Connect
xcrun altool --upload-app -f "QuickLaunch-1.3.0.pkg" \
    --type osx --username "your-apple-id@email.com" \
    --password "@keychain:AC_PASSWORD"
```

## Common Issues and Solutions

### Issue: Code signing fails
**Solution**: Ensure certificates are properly installed and not expired

### Issue: Entitlements rejection
**Solution**: Review entitlements against App Store guidelines

### Issue: App Sandbox violations
**Solution**: Test thoroughly in sandbox environment

### Issue: Notarization fails
**Solution**: Check hardened runtime settings and avoid prohibited APIs

## Security Checklist

- [ ] App Sandbox enabled
- [ ] Minimal entitlements requested
- [ ] Hardened Runtime configured
- [ ] No prohibited APIs used
- [ ] All frameworks properly signed
- [ ] Bundle structure correct
- [ ] Info.plist properly configured

## Files to Create

1. `CodeSigning/QuickLaunch.entitlements` - Entitlements file
2. `CodeSigning/build_signed.sh` - Build and signing script
3. `CodeSigning/validate.sh` - Validation script
4. `CodeSigning/upload.sh` - Upload script

## Next Steps

1. Set up Apple Developer account certificates
2. Create entitlements file
3. Test code signing locally
4. Submit to App Store Connect
5. Complete App Store review process

## Resources

- [Apple Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)