#!/bin/bash

# PaintRs - Run in DOSBox Script
# This script runs the PaintRs program in DOSBox for authentic DOS experience

echo "PaintRs - Graphics Painting Program (2003)"
echo "Running in DOSBox for authentic experience..."
echo "=================================================="

# Check if DOSBox is installed
if ! command -v dosbox &> /dev/null; then
    echo "DOSBox not found. Installing..."
    sudo apt update
    sudo apt install -y dosbox
fi

# Get the full path to current directory
PAINT_RS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting DOSBox with PaintRs..."
echo "Directory: $PAINT_RS_DIR"
echo ""
echo "In DOSBox:"
echo "- Type 'dir' to see files"
echo "- Type 'PaintRs_Detailed.exe' to run the program"
echo "- Click on tool buttons (left side) to select drawing tools"
echo "- Click on color rectangles (right side) to select colors"
echo "- Click and drag in drawing area to draw"
echo "- Press ESC to exit"
echo ""

# Check if original executable exists
if [ -f "$PAINT_RS_DIR/PaintRs.exe" ]; then
    echo "Found original PaintRs.exe - using that!"
    PROGRAM="PaintRs.exe"
elif [ -f "$PAINT_RS_DIR/PaintRs_Detailed.exe" ]; then
    echo "Using compiled PaintRs_Detailed.exe"
    PROGRAM="PaintRs_Detailed.exe"
else
    echo "PaintRs executable not found!"
    echo "Please compile first: fpc -o PaintRs_Detailed PaintRs_Detailed.pas"
    exit 1
fi

# Start DOSBox with PaintRs (interactive mode)
dosbox -c "mount c $PAINT_RS_DIR" \
       -c "c:" \
       -c "echo." \
       -c "echo === PaintRs Graphics Painting Program (2003) ===" \
       -c "echo." \
       -c "echo Available files:" \
       -c "dir" \
       -c "echo." \
       -c "echo To run PaintRs, type: $PROGRAM" \
       -c "echo Then press Enter" \
       -c "echo." \
       -c "echo Program features:" \
       -c "echo - 6 tool buttons on left side (Polish labels)" \
       -c "echo - 16 color selection grid on right side" \
       -c "echo - Mouse-driven drawing in center area" \
       -c "echo - Press ESC to exit when done" \
       -c "echo." &
       # Note: Interactive mode - user can type commands manually

echo "DOSBox started in interactive mode."
echo "Close DOSBox window when finished."
