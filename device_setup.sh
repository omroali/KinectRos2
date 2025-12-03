#!/bin/bash

# ============================================================
# Kinect Device Setup Script
# ============================================================
# This script sets up USB permissions for Kinect devices
# (Xbox 360 Kinect, Kinect v2, ASUS Xtion) on Linux systems
#
# Usage: sudo ./setup_kinect_permissions.sh [username]
#
# If no username is provided, it will use the user who invoked sudo
# ============================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Kinect Device Permission Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Determine target user
if [ -n "$1" ]; then
    TARGET_USER="$1"
elif [ -n "$SUDO_USER" ]; then
    TARGET_USER="$SUDO_USER"
else
    echo -e "${RED}ERROR: Cannot determine target user${NC}"
    echo "Please run as: sudo $0 <username>"
    exit 1
fi

echo -e "${GREEN}Target user: ${TARGET_USER}${NC}"
echo ""

# Verify user exists
if ! id "$TARGET_USER" &>/dev/null; then
    echo -e "${RED}ERROR: User '${TARGET_USER}' does not exist${NC}"
    exit 1
fi

# Step 1: Add user to necessary groups
echo -e "${YELLOW}[1/5]${NC} Adding user '${TARGET_USER}' to necessary groups..."

for group in plugdev video dialout; do
    if getent group "$group" > /dev/null 2>&1; then
        usermod -aG "$group" "$TARGET_USER"
        echo -e "  ${GREEN}✓${NC} Added to group: $group"
    else
        echo -e "  ${YELLOW}⚠${NC} Group '$group' does not exist, creating it..."
        groupadd "$group"
        usermod -aG "$group" "$TARGET_USER"
        echo -e "  ${GREEN}✓${NC} Created and added to group: $group"
    fi
done

echo ""

# Step 2: Install udev rules
echo -e "${YELLOW}[2/5]${NC} Installing udev rules..."

RULES_FILE="/etc/udev/rules.d/99-kinect-devices.rules"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_RULES="${SCRIPT_DIR}/99-kinect-devices.rules"

if [ -f "$SOURCE_RULES" ]; then
    cp "$SOURCE_RULES" "$RULES_FILE"
    chmod 644 "$RULES_FILE"
    echo -e "  ${GREEN}✓${NC} Installed udev rules to: $RULES_FILE"
else
    echo -e "  ${RED}✗${NC} Source rules file not found: $SOURCE_RULES"
    exit 1
fi

echo ""

# Step 3: Reload udev rules
echo -e "${YELLOW}[3/5]${NC} Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger
echo -e "  ${GREEN}✓${NC} udev rules reloaded"
echo ""

# Step 4: Check for connected Kinect devices
echo -e "${YELLOW}[4/5]${NC} Scanning for connected Kinect devices..."
echo ""

FOUND_DEVICES=0

# Check for Kinect 360
if lsusb | grep -q "045e:02ae\|045e:02b0\|045e:02ad"; then
    echo -e "  ${GREEN}✓${NC} Found: Microsoft Kinect for Xbox 360 (Kinect v1)"
    FOUND_DEVICES=1
fi

# Check for Kinect v2
if lsusb | grep -q "045e:02c4\|045e:02d8\|045e:02d9"; then
    echo -e "  ${GREEN}✓${NC} Found: Microsoft Kinect for Xbox One (Kinect v2)"
    FOUND_DEVICES=1
fi

# Check for ASUS Xtion
if lsusb | grep -q "1d27:0600\|1d27:0601\|1d27:0609"; then
    echo -e "  ${GREEN}✓${NC} Found: ASUS Xtion / PrimeSense device"
    FOUND_DEVICES=1
fi

if [ $FOUND_DEVICES -eq 0 ]; then
    echo -e "  ${YELLOW}⚠${NC} No Kinect devices detected"
    echo -e "  ${YELLOW}⚠${NC} Please connect your device and run: sudo udevadm trigger"
fi

echo ""

# Step 5: Summary
echo -e "${YELLOW}[5/5]${NC} Setup complete!"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Setup completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} Please log out and log back in for group changes to take effect."
echo -e "Or run: ${BLUE}newgrp plugdev${NC} in your current terminal"
echo ""
echo -e "After re-login, you can verify your groups with: ${BLUE}groups${NC}"
echo ""
echo -e "To test device detection, run: ${BLUE}lsusb | grep -E '045e|1d27'${NC}"
echo ""
