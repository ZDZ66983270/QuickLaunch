# Certificate Setup Guide for QuickLaunch

This guide walks you through setting up the necessary certificates for code signing and App Store distribution.

## Prerequisites

1. **Apple Developer Account**: Active Apple Developer Program membership ($99/year)
2. **Xcode**: Latest version installed from Mac App Store
3. **Command Line Tools**: `xcode-select --install`

## Step 1: Apple Developer Portal Setup

### Access Developer Portal
1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Sign in with your Apple ID
3. Navigate to "Certificates, Identifiers & Profiles"

### Create App ID
1. Go to "Identifiers" → "App IDs"
2. Click "+" to create new App ID
3. Fill in details:
   - **Description**: QuickLaunch
   - **Bundle ID**: `com.quicklaunch.macos`
   - **Platform**: macOS
4. Select capabilities (if needed):
   - App Sandbox (required for App Store)
5. Click "Continue" and "Register"

## Step 2: Create Certificates

### For App Store Distribution

1. **Mac App Distribution Certificate**
   - Go to "Certificates" → "Production"
   - Click "+" to add new certificate
   - Select "Mac App Distribution"
   - Upload Certificate Signing Request (CSR)
   - Download and install the certificate

2. **Mac Installer Distribution Certificate**
   - Select "Mac Installer Distribution"
   - Upload CSR and install certificate

### For Development and Testing

1. **Mac Development Certificate**
   - Go to "Certificates" → "Development"
   - Select "Mac Development"
   - Upload CSR and install certificate

### For Direct Distribution (Optional)

1. **Developer ID Application Certificate**
   - Go to "Certificates" → "Production"
   - Select "Developer ID Application"
   - Upload CSR and install certificate

2. **Developer ID Installer Certificate**
   - Select "Developer ID Installer"
   - Upload CSR and install certificate

## Step 3: Generate Certificate Signing Request (CSR)

If you need to create a CSR:

1. Open **Keychain Access** (Applications → Utilities)
2. Go to **Keychain Access** → **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
3. Fill in:
   - **User Email Address**: Your Apple ID email
   - **Common Name**: Your name or organization
   - **CA Email Address**: Leave blank
   - Select "Saved to disk"
4. Save the CSR file to your desktop
5. Use this CSR file when creating certificates in the Developer Portal

## Step 4: Install Certificates

### Automatic Installation (Recommended)
1. Open **Xcode**
2. Go to **Xcode** → **Preferences** → **Accounts**
3. Click "+" and add your Apple ID
4. Select your team/account
5. Click **"Manage Certificates..."**
6. Click "+" and select the certificate types you need:
   - Mac Development
   - Mac App Distribution
   - Developer ID Application (optional)

### Manual Installation
1. Download certificates from Developer Portal
2. Double-click each certificate file
3. Choose to install in "login" keychain
4. Verify installation in Keychain Access

## Step 5: Verify Certificate Installation

Run this command to check installed certificates:

```bash
# Check all code signing certificates
security find-identity -v -p codesigning

# Check specifically for Mac App Store certificates
security find-identity -v -p macappstore

# Check for Developer ID certificates
security find-identity -v -p basic
```

You should see output like:
```
1) ABCD1234... "Mac Developer: Your Name (TEAM123456)"
2) EFGH5678... "3rd Party Mac Developer Application: Your Name (TEAM123456)"
3) IJKL9012... "3rd Party Mac Developer Installer: Your Name (TEAM123456)"
```

## Step 6: Configure Xcode Project (If Using Xcode)

If you're using Xcode instead of command-line tools:

1. Open your project in Xcode
2. Select the project in navigator
3. Go to **Signing & Capabilities**
4. Set:
   - **Team**: Your Apple Developer team
   - **Bundle Identifier**: `com.quicklaunch.macos`
   - **Signing Certificate**: Automatic or select specific certificate

## Step 7: Test Code Signing

Test that certificates work correctly:

```bash
# Build the app first
make app

# Test signing with App Store certificate
codesign --force --verify --verbose \
    --sign "3rd Party Mac Developer Application" \
    --entitlements CodeSigning/QuickLaunch.entitlements \
    build/QuickLaunch.app

# Verify the signature
codesign --verify --deep --strict --verbose=2 build/QuickLaunch.app
```

## Common Issues and Solutions

### Issue: Certificate not found
**Solution**:
- Ensure certificates are installed in the correct keychain
- Check certificate names match exactly
- Verify certificates haven't expired

### Issue: "No matching provisioning profiles found"
**Solution**:
- macOS apps don't typically use provisioning profiles
- This error usually indicates certificate issues

### Issue: "Certificate has expired"
**Solution**:
- Renew certificate in Developer Portal
- Download and install new certificate
- Update references in build scripts

### Issue: "Keychain access denied"
**Solution**:
```bash
# Unlock the keychain
security unlock-keychain ~/Library/Keychains/login.keychain
```

## Certificate Types Summary

| Certificate Type | Purpose | Location |
|-----------------|---------|----------|
| Mac Development | Development & testing | Development section |
| Mac App Distribution | App Store submission | Production section |
| Mac Installer Distribution | App Store PKG creation | Production section |
| Developer ID Application | Direct distribution | Production section |
| Developer ID Installer | Direct distribution PKG | Production section |

## Security Best Practices

1. **Protect Private Keys**: Never share or export private keys
2. **Use Keychain**: Store certificates in macOS keychain
3. **Regular Updates**: Renew certificates before expiration
4. **Team Management**: Use team certificates for organizations
5. **Backup Strategy**: Keep secure backups of certificates

## Next Steps

After setting up certificates:

1. Test the build script: `./CodeSigning/build_signed.sh --app-store`
2. Validate the app: `./CodeSigning/validate.sh`
3. Create test builds for internal testing
4. Prepare for App Store submission

## Resources

- [Apple Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Certificates Overview](https://help.apple.com/developer-account/#/dev04fd06d56)
- [App Store Connect Guide](https://developer.apple.com/app-store-connect/)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)