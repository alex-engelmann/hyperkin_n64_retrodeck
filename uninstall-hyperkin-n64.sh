#!/bin/bash
# =============================================================================
# Hyperkin N64 Adapter Uninstall Script for Bazzite + RetroDeck
# =============================================================================
# Removes all changes made by setup-hyperkin-n64.sh
#
# Usage:
#   chmod +x uninstall-hyperkin-n64.sh
#   ./uninstall-hyperkin-n64.sh
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

RETROARCH_CFG="$HOME/.var/app/net.retrodeck.retrodeck/config/retroarch/retroarch.cfg"

# =============================================================================
# Step 1: Remove Flatpak device override
# =============================================================================

info "Removing Flatpak device override..."

flatpak override --user --nodevice=input net.retrodeck.retrodeck

info "Done."

# =============================================================================
# Step 2: Remove SDL2 environment override
# =============================================================================

info "Removing SDL2 environment override..."

flatpak override --user \
    --unset-env=SDL_GAMECONTROLLERCONFIG_FILE \
    net.retrodeck.retrodeck

info "Done."

# =============================================================================
# Step 3: Remove SDL2 gamecontroller mapping
# =============================================================================

GAMECONTROLLERDB_FILE="$HOME/.var/app/net.retrodeck.retrodeck/config/ES-DE/gamecontrollerdb.txt"

if [ -f "$GAMECONTROLLERDB_FILE" ]; then
    info "Removing Hyperkin mapping from gamecontrollerdb.txt..."

    sed -i '/03006d4b790000004e95000010010000/d' "$GAMECONTROLLERDB_FILE"

    # Remove file if now empty
    if [ ! -s "$GAMECONTROLLERDB_FILE" ]; then
        rm -f "$GAMECONTROLLERDB_FILE"
    fi

    info "Done."
else
    warning "gamecontrollerdb.txt not found, skipping."
fi

# =============================================================================
# Step 4: Remove RetroArch autoconfig
# =============================================================================

RETROARCH_AUTOCONFIG="$HOME/.var/app/net.retrodeck.retrodeck/config/retroarch/autoconfig/sdl2/ShanWan Hyperkin Adapter.cfg"

if [ -f "$RETROARCH_AUTOCONFIG" ]; then
    info "Removing RetroArch autoconfig..."

    rm -f "$RETROARCH_AUTOCONFIG"

    info "Done."
else
    warning "RetroArch autoconfig not found, skipping."
fi

# =============================================================================
# Step 5: Reset RetroArch configuration
# =============================================================================

if [ -f "$RETROARCH_CFG" ]; then
    info "Cleaning RetroArch configuration..."

    # Restore RetroArch's default autoconfig directory
    if grep -q '^joypad_autoconfig_dir = "/var/config/retroarch/autoconfig"' "$RETROARCH_CFG"; then
        sed -i \
            's|^joypad_autoconfig_dir = "/var/config/retroarch/autoconfig"|joypad_autoconfig_dir = "/app/retrodeck/components/retroarch/autoconfig"|' \
            "$RETROARCH_CFG"
    fi

    # Remove stored player 1 bindings so RetroArch regenerates defaults
    sed -i '/^input_player1_.* = /d' "$RETROARCH_CFG"

    info "Done."
else
    warning "retroarch.cfg not found, skipping."
fi

# =============================================================================
# Done
# =============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Uninstall complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All changes from setup-hyperkin-n64.sh have been removed."
echo "RetroArch will regenerate default controller bindings on next launch."
echo ""
