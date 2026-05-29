#!/bin/bash
# =============================================================================
# Hyperkin N64 Adapter Setup Script for Bazzite + RetroDeck
# =============================================================================
# This script configures the ShanWan/Hyperkin N64 USB adapter to work with
# RetroDeck (ES-DE frontend and RetroArch emulator) on Bazzite Linux.
#
# What this script does:
#   1. Grants RetroDeck access to input devices via Flatpak override
#   2. Installs the SDL2 controller mapping (gamecontrollerdb.txt)
#   3. Points RetroDeck at the SDL2 mapping via Flatpak environment override
#   4. Copies the RetroArch sdl2 autoconfig for correct button mapping
#   5. Clears RetroArch's manual player 1 bindings
#   6. Fixes RetroArch's autoconfig directory path
#
# Requirements:
#   - Bazzite (or other Linux distro with Flatpak)
#   - RetroDeck installed as a Flatpak (net.retrodeck.retrodeck)
#   - Hyperkin N64 adapter plugged in and set to PC mode
#   - "ShanWan Hyperkin Adapter.cfg" in the same directory as this script
#   - "gamecontrollerdb.txt" in the same directory as this script
#
# Usage:
#   chmod +x setup-hyperkin-n64.sh
#   ./setup-hyperkin-n64.sh
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Directory where this script lives — used to find bundled repo files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Preflight checks
# =============================================================================

info "Checking prerequisites..."

# Check RetroDeck is installed
if ! flatpak info net.retrodeck.retrodeck &>/dev/null; then
    error "RetroDeck (net.retrodeck.retrodeck) is not installed. Please install it first."
fi

# Check the cfg file is present alongside this script
if [ ! -f "$SCRIPT_DIR/ShanWan Hyperkin Adapter.cfg" ]; then
    error "'ShanWan Hyperkin Adapter.cfg' not found in $SCRIPT_DIR. Please place it alongside this script."
fi

# Check the SDL2 mapping file is present alongside this script
if [ ! -f "$SCRIPT_DIR/gamecontrollerdb.txt" ]; then
    error "'gamecontrollerdb.txt' not found in $SCRIPT_DIR. Please place it alongside this script."
fi

# Check adapter is plugged in
if ! grep -q "ShanWan Hyperkin Adapter" /proc/bus/input/devices 2>/dev/null; then
    warning "Hyperkin N64 adapter not detected. Make sure it's plugged in and set to PC mode."
    warning "Continuing anyway, but test after plugging in the adapter."
fi

# =============================================================================
# Step 1: Flatpak device access override
# =============================================================================

info "Granting RetroDeck access to input devices..."

# Allow RetroDeck to access input devices inside the Flatpak sandbox.
# Without this the sandbox blocks access to /dev/input/ entirely.
flatpak override --user --device=input net.retrodeck.retrodeck

info "Flatpak device override set."

# =============================================================================
# Step 2: SDL2 gamecontroller mapping
# =============================================================================

info "Installing SDL2 gamecontroller mapping..."

# The gamecontrollerdb.txt tells SDL2 exactly how to map this adapter's inputs.
# This is the critical file — without it SDL2 does not correctly expose
# the adapter's Z trigger and C buttons through the GameController API.
# Both ES-DE and RetroArch use SDL2, so this mapping applies to both.
#
# See gamecontrollerdb.txt in this repo for the full mapping with comments.

GAMECONTROLLERDB_DIR="$HOME/.var/app/net.retrodeck.retrodeck/config/ES-DE"
GAMECONTROLLERDB_FILE="$GAMECONTROLLERDB_DIR/gamecontrollerdb.txt"

mkdir -p "$GAMECONTROLLERDB_DIR"
cp "$SCRIPT_DIR/gamecontrollerdb.txt" "$GAMECONTROLLERDB_FILE"

info "gamecontrollerdb.txt installed to $GAMECONTROLLERDB_FILE"

# =============================================================================
# Step 3: Flatpak SDL2 mapping environment override
# =============================================================================

info "Setting SDL2 mapping environment variable for RetroDeck..."

# Tell SDL2 where to find our custom mapping file.
# Without this environment variable, gamecontrollerdb.txt is never loaded.
flatpak override --user \
    --env=SDL_GAMECONTROLLERCONFIG_FILE="$GAMECONTROLLERDB_FILE" \
    net.retrodeck.retrodeck

info "Flatpak SDL2 environment override set."

# =============================================================================
# Step 4: RetroArch sdl2 autoconfig
# =============================================================================

info "Copying RetroArch autoconfig for the adapter..."

RETROARCH_AUTOCONFIG_DIR="$HOME/.var/app/net.retrodeck.retrodeck/config/retroarch/autoconfig/sdl2"

mkdir -p "$RETROARCH_AUTOCONFIG_DIR"
cp "$SCRIPT_DIR/ShanWan Hyperkin Adapter.cfg" "$RETROARCH_AUTOCONFIG_DIR/"

info "RetroArch autoconfig copied to $RETROARCH_AUTOCONFIG_DIR/ShanWan Hyperkin Adapter.cfg"

# =============================================================================
# Step 5: Clear RetroArch manual player 1 bindings
# =============================================================================

info "Clearing RetroArch manual input bindings..."

RETROARCH_CFG="$HOME/.var/app/net.retrodeck.retrodeck/config/retroarch/retroarch.cfg"

if [ -f "$RETROARCH_CFG" ]; then
    # Remove any saved player 1 bindings so RetroArch falls back
    # to the autoconfig file we installed above.
    sed -i '/^input_player1_.* = /d' "$RETROARCH_CFG"

    info "Removed stored player 1 bindings from retroarch.cfg"
else
    warning "retroarch.cfg not found — launch RetroDeck once then re-run this script."
fi

# =============================================================================
# Step 6: Fix RetroArch autoconfig directory path
# =============================================================================

info "Fixing RetroArch autoconfig directory path..."

if [ -f "$RETROARCH_CFG" ]; then
    if grep -q '^joypad_autoconfig_dir = ' "$RETROARCH_CFG"; then
        sed -i \
            's|^joypad_autoconfig_dir = ".*"|joypad_autoconfig_dir = "/var/config/retroarch/autoconfig"|' \
            "$RETROARCH_CFG"
    else
        echo 'joypad_autoconfig_dir = "/var/config/retroarch/autoconfig"' \
            >> "$RETROARCH_CFG"
    fi

    info "retroarch.cfg updated."
else
    warning "retroarch.cfg not found — launch RetroDeck once then re-run this script."
fi

# =============================================================================
# Done
# =============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "What was configured:"
echo "  1. Flatpak override: devices=input"
echo "  2. SDL2 mapping:     $GAMECONTROLLERDB_FILE"
echo "  3. Flatpak override: SDL_GAMECONTROLLERCONFIG_FILE"
echo "  4. RetroArch config: $RETROARCH_AUTOCONFIG_DIR/ShanWan Hyperkin Adapter.cfg"
echo "  5. Player 1 retroarch.cfg bindings deleted"
echo "  6. retroarch.cfg:    joypad_autoconfig_dir -> /var/config/retroarch/autoconfig"
echo ""
echo "Notes:"
echo "  - Make sure the adapter is set to PC mode (not Switch/Console mode)."
echo "  - RetroArch may display a harmless 'using fallback' message on startup."
echo "    This does not affect functionality."
echo ""
