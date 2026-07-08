#!/bin/bash
# Thin client for the unified recording service: starts a recording, shows a
# live dashboard, and stops the recording on Ctrl+C.
#
# Requires the recording service node to be running already:
#   ros2 launch sensor_recorder unified_recording.launch.py
# (tmux_launch.sh opens it in the "record" window; alias: launch_recording)

STOPPED=0

stop_recording() {
    [ "$STOPPED" -ne 0 ] && return
    STOPPED=1
    echo ""
    echo "Stopping recording..."
    ros2 service call /stop_recording std_srvs/srv/Trigger > /dev/null 2>&1
    echo "Recording stopped: ${SESSION_DIR:-<unknown>}"
    if [ -n "$SESSION_DIR" ] && [ -d "$SESSION_DIR" ]; then
        echo "Final contents:"
        find "$SESSION_DIR" -type f -exec du -h {} + 2>/dev/null | sort -hr | head -20
    fi
    exit 0
}

trap stop_recording SIGINT SIGTERM

# --- Check the service is up ------------------------------------------------
if ! timeout 5 ros2 service type /start_recording > /dev/null 2>&1; then
    echo "Error: /start_recording service not found."
    echo "Start the recording service first:"
    echo "  ros2 launch sensor_recorder unified_recording.launch.py   (alias: launch_recording)"
    exit 1
fi

# --- Start recording ----------------------------------------------------------
echo "Calling /start_recording..."
RESPONSE=$(ros2 service call /start_recording std_srvs/srv/Trigger 2>&1)

if ! echo "$RESPONSE" | grep -q "success=True"; then
    echo "Error: recording did not start."
    echo "$RESPONSE" | grep -o "message='[^']*'" || echo "$RESPONSE" | tail -3
    exit 1
fi

# The service response message ends with the session directory path.
SESSION_DIR=$(echo "$RESPONSE" | grep -o "message='[^']*'" | sed "s/message='Recording started in //; s/'$//")
START_TIME=$(date +%s)

# --- Dashboard ----------------------------------------------------------------
while true; do
    tput clear

    CURRENT_TIME=$(date +%s)
    DURATION=$((CURRENT_TIME - START_TIME))

    echo "╔═════════════════════════════════════════════════════════════╗"
    echo "║            🔴 REC [Live Recording Dashboard] 🔴             ║"
    echo "║           Press Ctrl+C to stop and save session             ║"
    echo "╠═════════════════════════════════════════════════════════════╣"
    printf "║ %-15s | %-40s ║\n" "Session Dir" "$(basename "$SESSION_DIR")"
    printf "║ %-15s | %-40s ║\n" "Duration"    "${DURATION} seconds"
    echo "╠═════════════════════ File Details ══════════════════════════╣"

    (
      echo "║ SIZE     | FILE"
      echo "║----------|-------------------------------------------------- "
      find "$SESSION_DIR" -type f -exec du -h {} + 2>/dev/null | sort -hr | awk '{size=$1; $1=""; file=$0; printf "║ %-8s | %s\n", size, file}'
    ) | head -n 15

    echo "╚═════════════════════════════════════════════════════════════╝"

    sleep 2
done
