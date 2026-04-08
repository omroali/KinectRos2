#!/bin/bash

# test_kinect2.sh
# Quick test script to verify Kinect v2 detection and setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  Kinect v2 Detection Test${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

pass_test() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail_test() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

warn_test() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((TESTS_WARNING++))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ========================================
# 1. USB Device Detection
# ========================================
echo -e "${BLUE}[1] USB Device Detection${NC}"
echo "----------------------------------------"

KINECT2_DEVICES=$(lsusb | grep "045e:02d8")
if [ -n "$KINECT2_DEVICES" ]; then
    KINECT2_COUNT=$(echo "$KINECT2_DEVICES" | wc -l)
    pass_test "Found $KINECT2_COUNT Kinect v2 camera(s)"
    echo "$KINECT2_DEVICES" | while read -r line; do
        echo "    $line"
    done
    echo ""

    if [ "$KINECT2_COUNT" -ge 2 ]; then
        pass_test "Sufficient cameras for dual setup"
    elif [ "$KINECT2_COUNT" -eq 1 ]; then
        warn_test "Only 1 camera found (need 2 for dual setup)"
    fi
else
    fail_test "No Kinect v2 cameras detected"
    echo "  → Check if Kinects are plugged in and powered"
    echo "  → Kinect v2 USB ID: 045e:02d8"
fi

# Check for audio devices
KINECT2_AUDIO=$(lsusb | grep "045e:02d9" | wc -l)
if [ "$KINECT2_AUDIO" -gt 0 ]; then
    info "Found $KINECT2_AUDIO Kinect v2 audio device(s)"
fi

# ========================================
# 2. USB 3.0 Check
# ========================================
echo ""
echo -e "${BLUE}[2] USB 3.0 Verification${NC}"
echo "----------------------------------------"

if [ -n "$KINECT2_DEVICES" ]; then
    # Extract bus and device numbers
    while read -r line; do
        BUS=$(echo "$line" | awk '{print $2}')
        DEV=$(echo "$line" | awk '{print $4}' | sed 's/://')

        # Check USB speed (5000M = USB 3.0)
        SPEED=$(cat /sys/bus/usb/devices/$BUS-*/speed 2>/dev/null | head -1)
        if [ "$SPEED" = "5000" ]; then
            pass_test "Kinect on Bus $BUS is connected to USB 3.0"
        elif [ "$SPEED" = "480" ]; then
            fail_test "Kinect on Bus $BUS is on USB 2.0 (needs USB 3.0!)"
        else
            warn_test "Could not determine USB speed for Bus $BUS"
        fi
    done <<< "$KINECT2_DEVICES"
else
    warn_test "No devices to check USB speed"
fi

# ========================================
# 3. libfreenect2 Installation
# ========================================
echo ""
echo -e "${BLUE}[3] libfreenect2 Installation${NC}"
echo "----------------------------------------"

if ldconfig -p | grep -q libfreenect2; then
    pass_test "libfreenect2 library found"
    ldconfig -p | grep libfreenect2
else
    fail_test "libfreenect2 not found"
    echo "  → Rebuild Docker container with updated Dockerfile"
fi

# Check for Protonect test tool
if command -v Protonect >/dev/null 2>&1; then
    pass_test "Protonect test tool available"
else
    warn_test "Protonect not found (optional test tool)"
fi

# ========================================
# 4. ROS 2 Environment
# ========================================
echo ""
echo -e "${BLUE}[4] ROS 2 Environment${NC}"
echo "----------------------------------------"

if [ -n "$ROS_DISTRO" ]; then
    pass_test "ROS 2 environment sourced: $ROS_DISTRO"
else
    fail_test "ROS 2 environment not sourced"
    echo "  → Run: source /opt/ros/jazzy/setup.bash"
    echo "         source ~/base_ws/install/setup.bash"
fi

# ========================================
# 5. kinect2 ROS 2 Package
# ========================================
echo ""
echo -e "${BLUE}[5] kinect2_ros2 Package${NC}"
echo "----------------------------------------"

if [ -n "$ROS_DISTRO" ]; then
    if ros2 pkg list 2>/dev/null | grep -q kinect2_bridge; then
        pass_test "kinect2_bridge package found"
    else
        fail_test "kinect2_bridge package not found"
        echo "  → Build workspace: cd ~/base_ws && colcon build --symlink-install"
    fi

    if ros2 pkg list 2>/dev/null | grep -q kinect2_registration; then
        pass_test "kinect2_registration package found"
    else
        warn_test "kinect2_registration package not found"
    fi
fi

# ========================================
# 6. USB Permissions
# ========================================
echo ""
echo -e "${BLUE}[6] USB Device Permissions${NC}"
echo "----------------------------------------"

if [ -n "$KINECT2_DEVICES" ]; then
    HAS_PERMISSION_ISSUE=false
    while read -r line; do
        BUS=$(echo "$line" | awk '{print $2}')
        DEV=$(echo "$line" | awk '{print $4}' | sed 's/://')
        DEV_PATH="/dev/bus/usb/$BUS/$DEV"

        if [ -e "$DEV_PATH" ]; then
            if [ -r "$DEV_PATH" ] && [ -w "$DEV_PATH" ]; then
                pass_test "Can access $DEV_PATH"
            else
                fail_test "Cannot access $DEV_PATH"
                ls -l "$DEV_PATH"
                HAS_PERMISSION_ISSUE=true
            fi
        fi
    done <<< "$KINECT2_DEVICES"

    if [ "$HAS_PERMISSION_ISSUE" = true ]; then
        echo ""
        echo -e "${YELLOW}Fix permissions:${NC}"
        echo "  sudo usermod -aG video \$USER"
        echo "  Create udev rules (see KINECT2_SETUP.md)"
    fi
fi

# ========================================
# 7. Test libfreenect2 Device Detection
# ========================================
echo ""
echo -e "${BLUE}[7] libfreenect2 Device Detection${NC}"
echo "----------------------------------------"

if command -v Protonect >/dev/null 2>&1; then
    info "Testing device detection with Protonect..."
    echo ""

    # Run Protonect for 2 seconds and capture output
    timeout 2 Protonect 2>&1 | head -20 || true

    echo ""
    info "Protonect test complete (Ctrl+C if it was running)"
else
    warn_test "Protonect not available, skipping device detection test"
fi

# ========================================
# Summary
# ========================================
echo ""
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "${GREEN}Passed:   $TESTS_PASSED${NC}"
echo -e "${YELLOW}Warnings: $TESTS_WARNING${NC}"
echo -e "${RED}Failed:   $TESTS_FAILED${NC}"
echo ""

# ========================================
# Recommendations
# ========================================
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${YELLOW}=== RECOMMENDATIONS ===${NC}"
    echo ""

    if [ -z "$KINECT2_DEVICES" ]; then
        echo "1. Check Kinect v2 connections:"
        echo "   • Verify both Kinects are plugged into USB 3.0 ports"
        echo "   • Ensure power adapters are connected and LEDs are on"
        echo "   • Try different USB 3.0 ports"
        echo ""
    fi

    if ! ldconfig -p | grep -q libfreenect2; then
        echo "2. Install libfreenect2:"
        echo "   cd ~/KinectRos22/docker"
        echo "   docker compose down"
        echo "   docker compose build"
        echo "   docker compose up -d"
        echo ""
    fi

    if ! ros2 pkg list 2>/dev/null | grep -q kinect2_bridge; then
        echo "3. Build ROS 2 workspace:"
        echo "   cd ~/base_ws"
        echo "   colcon build --symlink-install"
        echo "   source install/setup.bash"
        echo ""
    fi
fi

# ========================================
# Next Steps
# ========================================
echo -e "${BLUE}=== NEXT STEPS ===${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ] && [ "$KINECT2_COUNT" -ge 1 ]; then
    echo "✓ System ready for Kinect v2 operation!"
    echo ""
    echo "Test single camera:"
    echo "  ros2 launch kinect2_bridge kinect2_single.launch.py"
    echo ""

    if [ "$KINECT2_COUNT" -ge 2 ]; then
        echo "Launch dual camera system:"
        echo "  cd ~/bash_scripts"
        echo "  ./launch_dual_kinect2.sh"
        echo ""
        echo "Or with custom positions:"
        echo "  ./launch_dual_kinect2.sh --camera2-x 2.0 --camera2-y 2.0 --camera2-yaw -1.5708"
        echo ""
    fi

    echo "View topics:"
    echo "  ros2 topic list"
    echo ""
    echo "Visualize:"
    echo "  rviz2"
else
    echo "Fix the issues above, then run this test again."
    echo ""
    echo "For detailed setup instructions:"
    echo "  See docs/SETUP_GUIDE.md"
fi

echo ""
