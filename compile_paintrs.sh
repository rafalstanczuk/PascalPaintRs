#!/bin/bash

# PaintRs Compilation Script
# Graphics painting program compilation (Keyboard-driven interface)

echo "PaintRs - Graphics Painting Program (Keyboard Interface)"
echo "Compilation script for reconstructed Pascal source"
echo "========================================================"

# Check if Free Pascal is available
if command -v fpc &> /dev/null; then
    echo "Using Free Pascal Compiler (fpc)..."

    # Compile the detailed version (complete reconstruction)
    echo "Compiling PaintRs_Detailed.pas (keyboard-driven interface)..."
    fpc -o PaintRs_Detailed PaintRs_Detailed.pas

    if [ $? -eq 0 ]; then
        echo "✅ Compilation completed successfully!"
        echo "Executable created:"
        echo "- PaintRs_Detailed (Complete keyboard-driven version)"
    else
        echo "❌ Compilation failed!"
        exit 1
    fi

elif command -v gpc &> /dev/null; then
    echo "Using GNU Pascal Compiler (gpc)..."

    # Compile the detailed version
    echo "Compiling PaintRs_Detailed.pas (keyboard-driven interface)..."
    gpc -o PaintRs_Detailed PaintRs_Detailed.pas

    if [ $? -eq 0 ]; then
        echo "✅ Compilation completed successfully!"
        echo "Executable created:"
        echo "- PaintRs_Detailed (Complete keyboard-driven version)"
    else
        echo "❌ Compilation failed!"
        exit 1
    fi

else
    echo "❌ No Pascal compiler found!"
    echo "Please install Free Pascal (fpc) or GNU Pascal (gpc)"
    echo ""
    echo "Ubuntu/Debian: sudo apt install fpc"
    echo "Fedora: sudo dnf install fpc"
    echo "Arch: sudo pacman -S fpc"
    exit 1
fi

echo ""
echo "Usage:"
echo "./PaintRs_Detailed - Complete graphics painting program"
echo ""
echo "Interface: MOUSE-DRIVEN (with complete button interface)"
echo "- Left click on tool buttons: Select drawing tools (left side)"
echo "- Left click on color buttons: Select colors (right side, 4x4 grid)"
echo "- Click and drag in drawing area: Draw shapes"
echo "- Single click: Place text, flood fill areas"
echo "- ESC key: Exit program"
echo "- Visual button feedback and mouse coordinate input"
echo ""
echo "Graphics Features:"
echo "- Line drawing with thickness control"
echo "- Rectangle and circle drawing"
echo "- Text rendering with font selection"
echo "- Fill patterns and styles (Solid, Hollow, Hatch, Pattern)"
echo "- 16-color selection (4x4 grid on right side)"
echo "- Mouse-driven interface with visual button feedback"
echo "- BGI graphics interface"
echo ""
echo "Note: Requires graphics mode support for full functionality"
