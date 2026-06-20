#!/bin/bash

# SVG to PNG Icon Generator for macOS App
# This script generates all required PNG sizes from a single SVG file

set -e

# Configuration
SVG_SOURCE="icon.svg"
ICONSET_DIR="Resources/AppIcon.iconset"

# Check if SVG source exists
if [ ! -f "$SVG_SOURCE" ]; then
    echo "❌ Error: SVG file not found at $SVG_SOURCE"
    echo "Please place your icon.svg file in the current directory"
    exit 1
fi

# Check if rsvg-convert is available
if ! command -v rsvg-convert &> /dev/null; then
    echo "❌ Error: rsvg-convert not found"
    echo "Please install librsvg: brew install librsvg"
    exit 1
fi

echo "🎨 Generating PNG icons from SVG..."
echo "📁 Source: $SVG_SOURCE"
echo "📂 Output: $ICONSET_DIR"

# Create iconset directory
mkdir -p "$ICONSET_DIR"

# Define all required sizes for macOS icons
declare -a sizes=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

# Generate each size
for size_info in "${sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    output_path="$ICONSET_DIR/$filename"

    echo "  📏 Generating ${size}x${size} → $filename"

    # Use rsvg-convert for better SVG color rendering
    rsvg-convert \
        --width="$size" \
        --height="$size" \
        --keep-aspect-ratio \
        --background-color=transparent \
        --format=png \
        "$SVG_SOURCE" \
        -o "$output_path"

    # Verify the output file was created and has correct size
    if [ -f "$output_path" ]; then
        file_size=$(stat -f%z "$output_path" 2>/dev/null || echo "0")
        if [ "$file_size" -gt 0 ]; then
            echo "  ✅ Created: $filename (${file_size} bytes)"
        else
            echo "  ❌ Failed: $filename (empty file)"
            exit 1
        fi
    else
        echo "  ❌ Failed: $filename (file not created)"
        exit 1
    fi
done

echo ""
echo "🎉 Successfully generated all PNG icons!"
echo "📊 Generated files:"
ls -la "$ICONSET_DIR"/*.png 2>/dev/null | awk '{print "   " $9 " (" $5 " bytes)"}'

echo ""
echo "🔄 Next steps:"
echo "   • Run 'make icons' to generate .icns file"
echo "   • Run 'make app' to build app with new icons"