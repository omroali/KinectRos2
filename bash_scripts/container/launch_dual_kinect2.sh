#!/bin/bash

# launch_dual_kinect2.sh
# Launch script for dual Kinect v2 setup with ROS2

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Dual Kinect v2 Launch Script ===${NC}"

# Check if ROS 2 is sourced
if [ -z "$ROS_DISTRO" ]; then
    echo -e "${RED}Error: ROS 2 environment not sourced!${NC}"
    echo "Please source your ROS 2 installation:"
    echo "  source /opt/ros/jazzy/setup.bash"
    echo "  source ~/base_ws/install/setup.bash"
    exit 1
fi

# Default parameters
CAMERA1_NS="kinect2_1"
CAMERA2_NS="kinect2_2"
CAMERA1_SERIAL=""
CAMERA2_SERIAL=""
CAMERA2_X="1.0"
CAMERA2_Y="0.0"
CAMERA2_Z="0.0"
CAMERA2_ROLL="0.0"
CAMERA2_PITCH="0.0"
CAMERA2_YAW="-0.523599"  # -30 degrees
LAUNCH_RVIZ="true"
USE_TRANSFORMS="true"

# Parse command line arguments
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --camera1-ns NAME          Namespace for camera 1 (default: kinect2_1)"
    echo "  --camera2-ns NAME          Namespace for camera 2 (default: kinect2_2)"
    echo "  --camera1-serial SERIAL    Serial number for camera 1 (auto-detect if empty)"
    echo "  --camera2-serial SERIAL    Serial number for camera 2 (auto-detect if empty)"
    echo "  --camera2-x VALUE          Camera 2 X position in meters (default: 1.0)"
    echo "  --camera2-y VALUE          Camera 2 Y position in meters (default: 0.0)"
    echo "  --camera2-z VALUE          Camera 2 Z position in meters (default: 0.0)"
    echo "  --camera2-roll VALUE       Camera 2 roll in radians (default: 0.0)"
    echo "  --camera2-pitch VALUE      Camera 2 pitch in radians (default: 0.0)"
    echo "  --camera2-yaw VALUE        Camera 2 yaw in radians (default: -0.523599)"
    echo "  --no-rviz                  Don't launch RViz"
    echo "  --no-transforms            Don't publish static transforms"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --camera2-x 2.0 --camera2-y 1.5 --camera2-yaw -1.5708"
    echo "  $0 --camera1-serial 123456 --camera2-serial 234567"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --camera1-ns)
            CAMERA1_NS="$2"
            shift 2
            ;;
        --camera2-ns)
            CAMERA2_NS="$2"
            shift 2
            ;;
        --camera1-serial)
            CAMERA1_SERIAL="$2"
            shift 2
            ;;
        --camera2-serial)
            CAMERA2_SERIAL="$2"
            shift 2
            ;;
        --camera2-x)
            CAMERA2_X="$2"
            shift 2
            ;;
        --camera2-y)
            CAMERA2_Y="$2"
            shift 2
            ;;
        --camera2-z)
            CAMERA2_Z="$2"
            shift 2
            ;;
        --camera2-roll)
            CAMERA2_ROLL="$2"
            shift 2
            ;;
        --camera2-pitch)
            CAMERA2_PITCH="$2"
            shift 2
            ;;
        --camera2-yaw)
            CAMERA2_YAW="$2"
            shift 2
            ;;
        --no-rviz)
            LAUNCH_RVIZ="false"
            shift
            ;;
        --no-transforms)
            USE_TRANSFORMS="false"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Check for Kinect v2 devices
echo "Checking for Kinect v2 devices..."
KINECT_COUNT=$(lsusb | grep -c "045e:02d8" || true)
echo -e "${BLUE}Found $KINECT_COUNT Kinect v2 device(s).${NC}"
if [ "$KINECT_COUNT" -lt 2 ]; then
    echo -e "${YELLOW}Warning: Found less than 2 Kinect v2 devices.${NC}"
    echo "You may need 2 devices for dual camera setup."
fi
echo ""

# Display configuration
echo -e "${BLUE}Configuration:${NC}"
echo "  Camera 1 Namespace: $CAMERA1_NS"
echo "  Camera 1 Serial: ${CAMERA1_SERIAL:-auto-detect}"
echo "  Camera 2 Namespace: $CAMERA2_NS"
echo "  Camera 2 Serial: ${CAMERA2_SERIAL:-auto-detect}"
echo "  Camera 2 Position: ($CAMERA2_X, $CAMERA2_Y, $CAMERA2_Z)"
echo "  Camera 2 Orientation: (roll=$CAMERA2_ROLL, pitch=$CAMERA2_PITCH, yaw=$CAMERA2_YAW)"
echo "  Launch RViz: $LAUNCH_RVIZ"
echo "  Use Transforms: $USE_TRANSFORMS"
echo ""

# Build launch command
LAUNCH_CMD="ros2 launch kinect2_bridge dual_kinect2.launch.py"
LAUNCH_CMD="$LAUNCH_CMD camera1_namespace:=$CAMERA1_NS"
LAUNCH_CMD="$LAUNCH_CMD camera2_namespace:=$CAMERA2_NS"

if [ -n "$CAMERA1_SERIAL" ]; then
    LAUNCH_CMD="$LAUNCH_CMD camera1_serial:=$CAMERA1_SERIAL"
fi

if [ -n "$CAMERA2_SERIAL" ]; then
    LAUNCH_CMD="$LAUNCH_CMD camera2_serial:=$CAMERA2_SERIAL"
fi

if [ "$USE_TRANSFORMS" == "true" ]; then
    LAUNCH_CMD="$LAUNCH_CMD camera2_x:=$CAMERA2_X"
    LAUNCH_CMD="$LAUNCH_CMD camera2_y:=$CAMERA2_Y"
    LAUNCH_CMD="$LAUNCH_CMD camera2_z:=$CAMERA2_Z"
    LAUNCH_CMD="$LAUNCH_CMD camera2_roll:=$CAMERA2_ROLL"
    LAUNCH_CMD="$LAUNCH_CMD camera2_pitch:=$CAMERA2_PITCH"
    LAUNCH_CMD="$LAUNCH_CMD camera2_yaw:=$CAMERA2_YAW"
fi

# Launch cameras
echo -e "${GREEN}Launching dual Kinect v2 cameras...${NC}"
echo "Command: $LAUNCH_CMD"
echo ""

# Execute launch command in background
$LAUNCH_CMD &
LAUNCH_PID=$!

# Wait for cameras to initialize
echo "Waiting for cameras to initialize (5 seconds)..."
sleep 5

# Launch RViz if requested
if [ "$LAUNCH_RVIZ" == "true" ]; then
    echo "Launching RViz..."

    # Check if RViz config exists
    RVIZ_CONFIG="$HOME/base_ws/src/kinect2_ros2/kinect2_bridge/launch/dual_kinect2.rviz"
    if [ -f "$RVIZ_CONFIG" ]; then
        rviz2 -d "$RVIZ_CONFIG" &
    else
        echo "RViz config not found, launching with default config"
        rviz2 &
    fi
    RVIZ_PID=$!
fi

echo ""
echo -e "${GREEN}Dual Kinect v2 system is running!${NC}"
echo "Press Ctrl+C to stop."
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Shutting down..."

    if [ -n "$RVIZ_PID" ]; then
        kill $RVIZ_PID 2>/dev/null || true
    fi

    if [ -n "$LAUNCH_PID" ]; then
        kill $LAUNCH_PID 2>/dev/null || true
    fi

    # Give processes time to clean up
    sleep 2

    echo "Done."
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Wait for background processes
wait
