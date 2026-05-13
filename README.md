# KinectRos22

A ROS 2 Jazzy workspace for Kinect v2 (Xbox One Kinect) sensors with Docker support.

## Features

- **Single & Dual Camera Support** - Run one or two Kinect v2 sensors simultaneously
- **Point Cloud Visualization** - XYZRGB point clouds at multiple resolutions
- **Dynamic TF** - Runtime-adjustable camera positions via ROS parameters
- **Docker Integration** - Pre-configured container with libfreenect2
- **Multiple Resolutions** - HD (1920×1080), QHD (960×540), SD (512×424)

## Requirements

### Hardware
- Kinect v2 (Xbox One Kinect) sensor
- Kinect v2 USB 3.0 adapter with power supply
- **USB 3.0 port** (mandatory)
- For dual cameras: separate USB controllers recommended

### Software
- Docker & Docker Compose
- Ubuntu 24.04 (host recommended) or 22.04

## Quick Start

### 1. Host Setup

```bash
sudo ./device_setup.sh
# Log out and back in for group changes
```

### 2. Start Docker

```bash
cd docker
docker compose up -d
docker compose exec ros2_jazzy bash
```

### 3. Build Workspace

```bash
cd ~/base_ws
source /opt/ros/jazzy/setup.bash
colcon build --symlink-install
source install/setup.bash
```

### 4. Launch

**Single camera:**
```bash
ros2 launch kinect2_single.launch.py serial:=<YOUR_SERIAL>
```

**Dual cameras:**
```bash
ros2 launch kinect2_bridge kinect2_dual_dynamic.launch.py \
    serial1:=<SERIAL_1> serial2:=<SERIAL_2>
```

### 5. Visualize

```bash
rviz2 -d ~/config/kinectrviz.rviz
```

## Vicon Auto-Alignment (On Demand)

This workflow is intentionally separate from the main launch flow.

1. Run normal Kinect launch as usual.
2. Start Vicon calibration node only when needed.
3. Save calibrated poses to config.
4. Stop calibration node and keep running with static TF.

### Start calibration node

Use an absolute config path so saved values are written to your source file.

```bash
ros2 run kinect2_bridge vicon_marker_calibration_tf.py --ros-args \
    -p config_path:=/home/ros/base_ws/src/kinect2_ros2/kinect2_bridge/config/multi_camera_config.yaml
```

or for adjustable params
```bash
ros2 run kinect2_bridge vicon_marker_calibration_tf.py --ros-args \
  -p config_path:=/home/ros/base_ws/src/kinect2_ros2/kinect2_bridge/config/multi_camera_config.yaml \
  -p translation_alpha:=0.1 \
  -p rotation_alpha:=0.05 \
  -p translation_deadband_m:=0.004 \
  -p rotation_deadband_deg:=1.2
```

### Save calibrated camera poses

```bash
ros2 service call /save_calibration std_srvs/srv/Trigger "{}"
```

The save operation is global and fresh-only.
If markers for a camera are stale, that camera is skipped.

### Why jitter happens when cameras are stationary

Small jitter is expected due to Vicon measurement noise and tiny marker centroid variation.
To reduce this, the calibration node applies deadbands before updating TF:

- translation_deadband_m (default 0.002 m = 2 mm)
- rotation_deadband_deg (default 0.2 deg)

### Tune deadbands (optional)

```bash
ros2 run kinect2_bridge vicon_marker_calibration_tf.py --ros-args \
    -p config_path:=/home/ros/base_ws/src/kinect2_ros2/kinect2_bridge/config/multi_camera_config.yaml \
    -p translation_deadband_m:=0.002 \
    -p rotation_deadband_deg:=0.2
```

If you still see jitter, increase deadbands slightly.
If updates feel too sticky, reduce deadbands.

## Project Structure

```
KinectRos22/
├── docker/                 # Docker configuration
│   ├── Dockerfile          # ROS 2 Humble + libfreenect2
│   └── docker-compose.yml
├── kinect2_ros2/           # ROS 2 packages
│   ├── kinect2_bridge/     # Main camera driver
│   ├── kinect2_registration/
│   └── kinect2_calibration/
├── config/                 # RViz configs & camera settings
├── bash_scripts/           # Helper scripts
├── docs/                   # Documentation
├── device_setup.sh         # Host USB/udev setup
└── 99-kinect-devices.rules # udev rules
```

## Topics

Each camera publishes under its namespace (`/kinect2_1/`, `/kinect2_2/`):

| Stream | Topics | Resolution |
|--------|--------|------------|
| HD | `hd/image_color` | 1920×1080 |
| QHD | `qhd/image_color`, `qhd/points` | 960×540 |
| SD | `sd/image_color_rect`, `sd/image_depth_rect`, `sd/points` | 512×424 |

## Documentation

- **[Setup Guide](docs/SETUP_GUIDE.md)** - Detailed setup instructions
- **[Quick Reference](docs/QUICK_REFERENCE.md)** - Command cheat sheet
- **[Architecture](docs/ARCHITECTURE_DUAL_KINECT.md)** - System design

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `LIBUSB_ERROR_ACCESS` | Run `sudo ./device_setup.sh` |
| `LIBUSB_ERROR_TIMEOUT` | Re-run device_setup.sh (USB buffer issue) |
| Device not found | Check USB 3.0 connection and power |
| No point cloud in RViz | Set QoS Reliability to "Best Effort" |

## Find Serial Numbers

```bash
# Launch without serial to see available devices
ros2 launch kinect2_bridge kinect2_single.launch.py

# Or use libfreenect2 directly
Protonect
```

## Acknowledgments

- [libfreenect2](https://github.com/OpenKinect/libfreenect2) - Kinect v2 driver
- [kinect2_ros2](https://github.com/krepa098/kinect2_ros2) - ROS 2 wrapper

## License

See individual package licenses in their respective directories.
