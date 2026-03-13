#!/bin/bash

# test_dual_kinect.sh
# Test and verification script for dual Kinect setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Dual Kinect System Test ===${NC}"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

# Helper functions
pass_test() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

fail_test() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

warn_test() {
    echo -e "${YELLOW}⚠ WARNING:${NC} $1"
    ((TESTS_WARNING++))
}

# Test 1: Check if ROS 2 is sourced
echo -e "${BLUE}[Test 1]${NC} Checking ROS 2 environment..."
if [ -z "$ROS_DISTRO" ]; then
    fail_test "ROS 2 environment not sourced"
    echo "  → Please run: source /opt/ros/humble/setup.bash"
else
    pass_test "ROS 2 $ROS_DISTRO environment detected"
fi
echo ""

# Test 2: Check for USB devices
echo -e "${BLUE}[Test 2]${NC} Checking for Kinect devices..."
if command -v lsusb &> /dev/null; then
    KINECT_COUNT=$(lsusb | grep -i "kinect\|primesense\|asus.*xtion" | wc -l)
    echo "  Found devices:"
    lsusb | grep -i "kinect\|primesense\|asus.*xtion" || echo "  (none)"

    if [ "$KINECT_COUNT" -ge 2 ]; then
        pass_test "Found $KINECT_COUNT Kinect-compatible device(s)"
    elif [ "$KINECT_COUNT" -eq 1 ]; then
        warn_test "Only 1 Kinect device found (need 2 for dual setup)"
    else
        fail_test "No Kinect devices detected"
        echo "  → Check USB connections and device power"
    fi
else
    warn_test "lsusb command not available, cannot check devices"
fi
echo ""

# Test 3: Check if required packages exist
echo -e "${BLUE}[Test 3]${NC} Checking for required ROS 2 packages..."

check_package() {
    if ros2 pkg prefix $1 &> /dev/null; then
        pass_test "Package '$1' found"
        return 0
    else
        fail_test "Package '$1' not found"
        return 1
    fi
}

check_package "openni2_camera"
check_package "depth_image_proc"
check_package "tf2_ros"
echo ""

# Test 4: Check if launch files exist
echo -e "${BLUE}[Test 4]${NC} Checking for dual Kinect launch files..."

check_launch_file() {
    local pkg_name="$1"
    local launch_file="$2"

    PKG_PATH=$(ros2 pkg prefix $pkg_name 2>/dev/null)
    if [ -n "$PKG_PATH" ]; then
        LAUNCH_PATH="$PKG_PATH/share/$pkg_name/launch/$launch_file"
        if [ -f "$LAUNCH_PATH" ]; then
            pass_test "Launch file '$launch_file' exists"
            return 0
        fi
    fi

    # Also check in source directory
    if [ -f "openni2_camera/openni2_camera/launch/$launch_file" ]; then
        pass_test "Launch file '$launch_file' exists (in source)"
        return 0
    fi

    fail_test "Launch file '$launch_file' not found"
    return 1
}

check_launch_file "openni2_camera" "dual_camera_with_cloud.launch.py"
check_launch_file "openni2_camera" "dual_camera_with_transforms.launch.py"
echo ""

# Test 5: Check if RViz config exists
echo -e "${BLUE}[Test 5]${NC} Checking for RViz configuration..."

RVIZ_CONFIG_FOUND=0
if [ -f "src/ros2_ws/ros2_ws/dual_kinect.rviz" ]; then
    pass_test "RViz config found: src/ros2_ws/ros2_ws/dual_kinect.rviz"
    RVIZ_CONFIG_FOUND=1
elif [ -f "ros2_ws/ros2_ws/dual_kinect.rviz" ]; then
    pass_test "RViz config found: ros2_ws/ros2_ws/dual_kinect.rviz"
    RVIZ_CONFIG_FOUND=1
else
    PKG_PATH=$(ros2 pkg prefix ros2_ws 2>/dev/null)
    if [ -n "$PKG_PATH" ] && [ -f "$PKG_PATH/share/ros2_ws/ros2_ws/dual_kinect.rviz" ]; then
        pass_test "RViz config found in install directory"
        RVIZ_CONFIG_FOUND=1
    else
        warn_test "RViz config not found (will use default config)"
    fi
fi
echo ""

# Test 6: Check if helper script exists
echo -e "${BLUE}[Test 6]${NC} Checking for helper scripts..."
if [ -f "bash_scripts/launch_dual_kinect.sh" ]; then
    pass_test "Launch helper script exists"
    if [ -x "bash_scripts/launch_dual_kinect.sh" ]; then
        pass_test "Launch helper script is executable"
    else
        warn_test "Launch helper script is not executable"
        echo "  → Run: chmod +x bash_scripts/launch_dual_kinect.sh"
    fi
else
    warn_test "Launch helper script not found"
fi
echo ""

# Test 7: Test ROS 2 daemon
echo -e "${BLUE}[Test 7]${NC} Checking ROS 2 daemon..."
if ros2 daemon status &> /dev/null; then
    pass_test "ROS 2 daemon is running"
else
    warn_test "ROS 2 daemon not running, starting it..."
    ros2 daemon start
    if ros2 daemon status &> /dev/null; then
        pass_test "ROS 2 daemon started successfully"
    else
        fail_test "Could not start ROS 2 daemon"
    fi
fi
echo ""

# Test 8: Check available topics (if system is running)
echo -e "${BLUE}[Test 8]${NC} Checking for active dual Kinect topics..."
TOPICS=$(ros2 topic list 2>/dev/null)

if echo "$TOPICS" | grep -q "/camera1/"; then
    pass_test "Camera1 topics detected (system appears to be running)"

    # Check specific topics
    if echo "$TOPICS" | grep -q "/camera1/depth_registered/points"; then
        pass_test "Camera1 point cloud topic active"
    fi

    if echo "$TOPICS" | grep -q "/camera1/rgb/image_raw"; then
        pass_test "Camera1 RGB image topic active"
    fi
else
    warn_test "Camera1 topics not found (system not running)"
fi

if echo "$TOPICS" | grep -q "/camera2/"; then
    pass_test "Camera2 topics detected"

    if echo "$TOPICS" | grep -q "/camera2/depth_registered/points"; then
        pass_test "Camera2 point cloud topic active"
    fi

    if echo "$TOPICS" | grep -q "/camera2/rgb/image_raw"; then
        pass_test "Camera2 RGB image topic active"
    fi
else
    warn_test "Camera2 topics not found (system not running)"
fi
echo ""

# Test 9: Check TF frames (if system is running)
echo -e "${BLUE}[Test 9]${NC} Checking TF frames..."
if command -v ros2 &> /dev/null; then
    FRAMES=$(ros2 run tf2_ros tf2_echo world camera1_link 2>&1 | head -n 1)
    if echo "$FRAMES" | grep -q "At time"; then
        pass_test "TF transform world → camera1_link available"
    else
        warn_test "TF transform world → camera1_link not available (system not running)"
    fi

    FRAMES2=$(ros2 run tf2_ros tf2_echo world camera2_link 2>&1 | head -n 1)
    if echo "$FRAMES2" | grep -q "At time"; then
        pass_test "TF transform world → camera2_link available"
    else
        warn_test "TF transform world → camera2_link not available (system not running)"
    fi
fi
echo ""

# Test 10: Check USB bandwidth availability
echo -e "${BLUE}[Test 10]${NC} Checking USB configuration..."
if command -v lsusb &> /dev/null; then
    USB3_COUNT=$(lsusb -t 2>/dev/null | grep -c "5000M" || true)
    if [ "$USB3_COUNT" -gt 0 ]; then
        pass_test "USB 3.0 controllers detected ($USB3_COUNT)"
    else
        warn_test "No USB 3.0 controllers detected"
        echo "  → USB 2.0 may have bandwidth limitations for dual cameras"
    fi
else
    warn_test "Cannot check USB configuration (lsusb not available)"
fi
echo ""

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}          TEST SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Passed:${NC}   $TESTS_PASSED"
echo -e "${YELLOW}Warnings:${NC} $TESTS_WARNING"
echo -e "${RED}Failed:${NC}   $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    if [ $TESTS_WARNING -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed! System ready for dual Kinect operation.${NC}"
        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo "  1. Launch the system:"
        echo "     ./bash_scripts/launch_dual_kinect.sh"
        echo ""
        echo "  2. Or manually:"
        echo "     ros2 launch openni2_camera dual_camera_with_transforms.launch.py"
        exit 0
    else
        echo -e "${YELLOW}⚠ Tests passed with warnings. System should work but review warnings above.${NC}"
        echo ""
        echo -e "${BLUE}To launch anyway:${NC}"
        echo "  ./bash_scripts/launch_dual_kinect.sh"
        exit 0
    fi
else
    echo -e "${RED}✗ Some tests failed. Please resolve issues before running dual Kinect system.${NC}"
    echo ""
    echo -e "${BLUE}Common fixes:${NC}"
    echo "  • Source ROS 2: source /opt/ros/humble/setup.bash"
    echo "  • Build workspace: cd /path/to/workspace && colcon build"
    echo "  • Check USB connections: lsusb | grep -i kinect"
    echo "  • Install packages: sudo apt install ros-humble-openni2-camera"
    exit 1
fi
