#!/bin/bash

# Apply camera configuration from YAML file to dynamic_camera_tf node
# Usage: ./apply_camera_config.sh <config_file.yaml>

set -e

CONFIG_FILE="${1:-config/camera_config.yaml}"
NODE_NAME="/dynamic_camera_tf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Check if node is running
if ! ros2 node list 2>/dev/null | grep -q "$NODE_NAME"; then
    echo "Error: Node $NODE_NAME is not running"
    echo "Launch with: ros2 launch kinect2_bridge kinect2_dual_dynamic.launch.py"
    exit 1
fi

echo "Applying config from: $CONFIG_FILE"

# Parse YAML and extract values
parse_yaml() {
    local prefix=$1
    local file=$2
    local s='[[:space:]]*'
    local w='[a-zA-Z0-9_]*'
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1\2=\3|p" \
         -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1\2=\3|p" "$file" | \
    sed -e 's/[[:space:]]*$//' \
        -e "s/^/${prefix}/" \
        -e 's/[[:space:]]*=[[:space:]]*/=/'
}

# Extract value from config
get_value() {
    local key=$1
    grep -E "^${key}=" /tmp/camera_config_parsed 2>/dev/null | cut -d= -f2 | tr -d ' '
}

# Parse config to temp file
parse_yaml "" "$CONFIG_FILE" > /tmp/camera_config_parsed

# Read camera1 config
cam1_enabled=$(get_value "camera1enabled")
cam1_x=$(get_value "camera1positionx")
cam1_y=$(get_value "camera1positiony")
cam1_z=$(get_value "camera1positionz")
cam1_roll=$(get_value "camera1orientationroll")
cam1_pitch=$(get_value "camera1orientationpitch")
cam1_yaw=$(get_value "camera1orientationyaw")
cam1_frame=$(get_value "camera1frame")

# Read camera2 config
cam2_enabled=$(get_value "camera2enabled")
cam2_x=$(get_value "camera2positionx")
cam2_y=$(get_value "camera2positiony")
cam2_z=$(get_value "camera2positionz")
cam2_roll=$(get_value "camera2orientationroll")
cam2_pitch=$(get_value "camera2orientationpitch")
cam2_yaw=$(get_value "camera2orientationyaw")
cam2_frame=$(get_value "camera2frame")

# Apply camera1 settings
echo "Applying Camera 1 settings..."
[ -n "$cam1_enabled" ] && ros2 param set $NODE_NAME camera1_enabled $cam1_enabled
[ -n "$cam1_x" ] && ros2 param set $NODE_NAME camera1_x $cam1_x
[ -n "$cam1_y" ] && ros2 param set $NODE_NAME camera1_y $cam1_y
[ -n "$cam1_z" ] && ros2 param set $NODE_NAME camera1_z $cam1_z
[ -n "$cam1_roll" ] && ros2 param set $NODE_NAME camera1_roll $cam1_roll
[ -n "$cam1_pitch" ] && ros2 param set $NODE_NAME camera1_pitch $cam1_pitch
[ -n "$cam1_yaw" ] && ros2 param set $NODE_NAME camera1_yaw $cam1_yaw
[ -n "$cam1_frame" ] && ros2 param set $NODE_NAME camera1_frame $cam1_frame

# Apply camera2 settings
echo "Applying Camera 2 settings..."
[ -n "$cam2_enabled" ] && ros2 param set $NODE_NAME camera2_enabled $cam2_enabled
[ -n "$cam2_x" ] && ros2 param set $NODE_NAME camera2_x $cam2_x
[ -n "$cam2_y" ] && ros2 param set $NODE_NAME camera2_y $cam2_y
[ -n "$cam2_z" ] && ros2 param set $NODE_NAME camera2_z $cam2_z
[ -n "$cam2_roll" ] && ros2 param set $NODE_NAME camera2_roll $cam2_roll
[ -n "$cam2_pitch" ] && ros2 param set $NODE_NAME camera2_pitch $cam2_pitch
[ -n "$cam2_yaw" ] && ros2 param set $NODE_NAME camera2_yaw $cam2_yaw
[ -n "$cam2_frame" ] && ros2 param set $NODE_NAME camera2_frame $cam2_frame

# Cleanup
rm -f /tmp/camera_config_parsed

echo "Done."
