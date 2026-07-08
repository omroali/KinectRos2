#!/bin/bash
# Wrapper script to launch ROS recording and display a live dashboard.

# --- Configuration ---
# These paths are inside the container and should match recording_config.yaml
OUTPUT_ROOT="/home/ubuntu/data"
UUID="0000"
SESSION_BASE_DIR="${OUTPUT_ROOT}/${UUID}"

ROS_PID=0

# --- Functions ---
cleanup() {
    echo ""
    echo "Stopping recording process..."
    if [ $ROS_PID -ne 0 ]; then
        # Send SIGINT (Ctrl+C) to the process group to shut down ros2 launch gracefully
        kill -SIGINT -$ROS_PID
        wait $ROS_PID 2>/dev/null
    fi
    
    echo "Final Summary:"
    # The final summary logic from the previous script is implicitly handled by the loop's last run
    # and the shell's natural exit. We can add a more explicit final print if needed.
    exit 0
}

# --- Main ---
# Trap Ctrl+C (SIGINT) and call the cleanup function
trap cleanup SIGINT

# Launch the ROS recording node in the background
echo "Starting recording in the background... Monitoring will begin shortly."
# Use setsid to create a new session, so we can kill the whole process group
setsid ros2 launch kinect2_bridge kinect2_recording.launch.py > /dev/null 2>&1 &
ROS_PID=$!

# Wait for the session directory to be created
echo "Waiting for session directory to be created..."
SESSION_DIR=""
for i in {1..15}; do
    # Find the most recently modified session directory
    LATEST_DIR=$(find "${SESSION_BASE_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    if [ -n "$LATEST_DIR" ]; then
        SESSION_DIR=$LATEST_DIR
        break
    fi
    sleep 1
done

if [ -z "$SESSION_DIR" ]; then
    echo "Error: Could not find session directory after 15 seconds. Aborting."
    cleanup
    exit 1
fi

START_TIME=$(date +%s)

# Start the monitoring loop
while true; do
    # Clear the terminal
    tput clear

    # Calculate duration
    CURRENT_TIME=$(date +%s)
    DURATION=$((CURRENT_TIME - START_TIME))
    
    # Header
    echo "╔═════════════════════════════════════════════════════════════╗"
    echo "║            🔴 REC [Live Recording Dashboard] 🔴             ║"
    echo "║           Press Ctrl+C to stop and save session             ║"
    echo "╠═════════════════════════════════════════════════════════════╣"
    printf "║ %-15s | %-40s ║\n" "Session Dir" "$(basename "$SESSION_DIR")"
    printf "║ %-15s | %-40s ║\n" "Duration"    "${DURATION} seconds"
    echo "╠═════════════════════ File Details ══════════════════════════╣"
    
    # File details
    (
      echo "║ SIZE     | FILE"
      echo "║----------|-------------------------------------------------- "
      find "$SESSION_DIR" -type f -exec du -h {} + 2>/dev/null | sort -hr | awk '{size=$1; $1=""; file=$0; printf "║ %-8s | %s\n", size, file}'
    ) | head -n 15 # Limit to 15 lines to prevent overflow

    echo "╚═════════════════════════════════════════════════════════════╝"

    sleep 2
done
