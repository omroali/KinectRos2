# Dual Kinect v2 System Architecture

This document provides a visual overview of the dual Kinect v2 system architecture, data flow, and component relationships.

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                      DUAL KINECT V2 SYSTEM                          │
└─────────────────────────────────────────────────────────────────────┘

 HARDWARE LAYER
┌──────────────────────────┐              ┌──────────────────────────┐
│     Kinect v2 Camera 1   │              │     Kinect v2 Camera 2   │
│  (Xbox One Kinect)       │              │  (Xbox One Kinect)       │
│  USB ID: 045e:02d8       │              │  USB ID: 045e:02d8       │
│  ┌────────┐ ┌──────────┐ │              │  ┌────────┐ ┌──────────┐ │
│  │  RGB   │ │  Depth   │ │              │  │  RGB   │ │  Depth   │ │
│  │1920x   │ │ 512x424  │ │              │  │1920x   │ │ 512x424  │ │
│  │ 1080   │ │  ToF     │ │              │  │ 1080   │ │  ToF     │ │
│  └────────┘ └──────────┘ │              │  └────────┘ └──────────┘ │
└──────────┬───────────────┘              └──────────┬───────────────┘
           │                                         │
           │ USB 3.0 (Required)                      │ USB 3.0 (Required)
           │ + External Power                        │ + External Power
           │                                         │
┌──────────▼─────────────────────────────────────────▼───────────────┐
│                      HOST MACHINE / DOCKER                          │
│                   (USB buffer: 128MB recommended)                   │
└─────────────────────────────────────────────────────────────────────┘

 DRIVER LAYER (libfreenect2)
┌─────────────────────────────────────────────────────────────────────┐
│                         libfreenect2                                │
│  ┌─────────────────────────┐    ┌─────────────────────────┐        │
│  │  Device 1               │    │  Device 2               │        │
│  │  Serial: XXXXXXXXXX     │    │  Serial: YYYYYYYYYY     │        │
│  │  - RGB Pipeline         │    │  - RGB Pipeline         │        │
│  │  - Depth Pipeline       │    │  - Depth Pipeline       │        │
│  │  - Registration         │    │  - Registration         │        │
│  └─────────────────────────┘    └─────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────┘

 ROS 2 BRIDGE LAYER (kinect2_bridge)
┌────────────────────────────────┐  ┌────────────────────────────────┐
│  Namespace: /kinect2_1         │  │  Namespace: /kinect2_2         │
│  ┌──────────────────────────┐  │  │  ┌──────────────────────────┐  │
│  │  kinect2_bridge_node     │  │  │  │  kinect2_bridge_node     │  │
│  │  - sensor: <serial1>     │  │  │  │  - sensor: <serial2>     │  │
│  │  - publish_tf: true      │  │  │  │  - publish_tf: true      │  │
│  │  - depth_method: cpu     │  │  │  │  - depth_method: cpu     │  │
│  │  - reg_method: cpu       │  │  │  │  - reg_method: cpu       │  │
│  └──────────────────────────┘  │  │  └──────────────────────────┘  │
└────────────────────────────────┘  └────────────────────────────────┘

 ROS 2 TOPICS (per camera)
┌────────────────────────────────┐  ┌────────────────────────────────┐
│  /kinect2_1/                   │  │  /kinect2_2/                   │
│    ├─ hd/                      │  │    ├─ hd/                      │
│    │   ├─ image_color          │  │    │   ├─ image_color          │
│    │   ├─ image_color_rect     │  │    │   ├─ image_color_rect     │
│    │   └─ camera_info          │  │    │   └─ camera_info          │
│    ├─ qhd/                     │  │    ├─ qhd/                     │
│    │   ├─ image_color          │  │    │   ├─ image_color          │
│    │   ├─ image_depth_rect     │  │    │   ├─ image_depth_rect     │
│    │   ├─ points               │  │    │   ├─ points               │
│    │   └─ camera_info          │  │    │   └─ camera_info          │
│    └─ sd/                      │  │    └─ sd/                      │
│        ├─ image_color_rect     │  │        ├─ image_color_rect     │
│        ├─ image_depth          │  │        ├─ image_depth          │
│        ├─ image_depth_rect     │  │        ├─ image_depth_rect     │
│        ├─ points               │  │        ├─ points               │
│        └─ camera_info          │  │        └─ camera_info          │
└────────────────────────────────┘  └────────────────────────────────┘

 TF TRANSFORM LAYER
┌─────────────────────────────────────────────────────────────────────┐
│                            world                                    │
│                              │                                      │
│              ┌───────────────┴───────────────┐                     │
│              ▼                               ▼                      │
│      kinect2_1_link               kinect2_2_link                   │
│      (0, 0, 0)                    (x, y, z, roll, pitch, yaw)      │
│              │                               │                      │
│              ▼                               ▼                      │
│  kinect2_1_rgb_optical_frame    kinect2_2_rgb_optical_frame        │
│              │                               │                      │
│              ▼                               ▼                      │
│  kinect2_1_ir_optical_frame     kinect2_2_ir_optical_frame         │
└─────────────────────────────────────────────────────────────────────┘

 VISUALIZATION LAYER (RViz2)
┌─────────────────────────────────────────────────────────────────────┐
│                              RViz2                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐        │
│  │ TF Display     │  │ PointCloud2    │  │ PointCloud2    │        │
│  │ - world tree   │  │ /kinect2_1/    │  │ /kinect2_2/    │        │
│  │ - camera links │  │   sd/points    │  │   sd/points    │        │
│  └────────────────┘  └────────────────┘  └────────────────┘        │
│  ┌────────────────┐  ┌────────────────┐                            │
│  │ Image Display  │  │ Image Display  │                            │
│  │ /kinect2_1/hd/ │  │ /kinect2_2/hd/ │                            │
│  │  image_color   │  │  image_color   │                            │
│  └────────────────┘  └────────────────┘                            │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
                              KINECT V2 DATA FLOW

┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Kinect v2     │     │   libfreenect2  │     │  kinect2_bridge │
│   Hardware      │────▶│   Driver        │────▶│   ROS 2 Node    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                        ┌───────────────────────────────┼───────────────────────────────┐
                        │                               │                               │
                        ▼                               ▼                               ▼
               ┌─────────────────┐             ┌─────────────────┐             ┌─────────────────┐
               │   HD Stream     │             │   QHD Stream    │             │   SD Stream     │
               │   1920x1080     │             │   960x540       │             │   512x424       │
               │   RGB only      │             │   RGB + Depth   │             │   RGB + Depth   │
               └─────────────────┘             │   + Point Cloud │             │   + Point Cloud │
                                               └─────────────────┘             └─────────────────┘

Point Cloud Generation:
  RGB Image ────┐
                ├───▶ Registration ───▶ XYZRGB Point Cloud
  Depth Image ──┘     (CPU-based)
```

## Component Interaction

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LAUNCH SEQUENCE                              │
└─────────────────────────────────────────────────────────────────────┘

1. Device Setup (Host)
   └─▶ device_setup.sh
       ├─▶ Install udev rules
       ├─▶ Set USB buffer (128MB)
       └─▶ Add user to plugdev/video groups

2. Docker Container Start
   └─▶ docker-compose up
       ├─▶ Mount /dev/bus/usb
       ├─▶ Set privileged mode
       └─▶ Pass DISPLAY for GUI

3. ROS 2 Workspace Build
   └─▶ colcon build
       ├─▶ kinect2_bridge
       ├─▶ kinect2_registration
       └─▶ kinect2_calibration

4. Launch Dual Cameras
   └─▶ kinect2_dual_dynamic.launch.py
       ├─▶ Start kinect2_bridge (camera 1)
       ├─▶ Start kinect2_bridge (camera 2)
       ├─▶ Start static_transform_publisher (world→camera1)
       ├─▶ Start static_transform_publisher (world→camera2)
       └─▶ Start dynamic_camera_tf (optional)
```

## Resolution and Bandwidth

| Stream | Resolution | Frame Rate | Bandwidth | Use Case |
|--------|------------|------------|-----------|----------|
| HD     | 1920×1080  | 30 Hz      | High      | Color images only |
| QHD    | 960×540    | 30 Hz      | Medium    | Balanced RGB+Depth |
| SD     | 512×424    | 30 Hz      | Low       | Point clouds, dual camera |

**Recommendation**: Use SD streams for dual camera setups to avoid USB bandwidth saturation.

## USB Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      USB BANDWIDTH REQUIREMENTS                     │
└─────────────────────────────────────────────────────────────────────┘

Single Kinect v2:
  - USB 3.0 REQUIRED (5 Gbps)
  - ~2 Gbps actual throughput
  - External power adapter required

Dual Kinect v2:
  - Separate USB 3.0 controllers recommended
  - Total bandwidth: ~4 Gbps
  - USB buffer: 128MB minimum

Host Configuration:
  ┌────────────────────┐     ┌────────────────────┐
  │ USB 3.0 Controller │     │ USB 3.0 Controller │
  │     (Host 1)       │     │     (Host 2)       │
  └─────────┬──────────┘     └─────────┬──────────┘
            │                          │
            ▼                          ▼
      ┌───────────┐              ┌───────────┐
      │ Kinect v2 │              │ Kinect v2 │
      │ Camera 1  │              │ Camera 2  │
      └───────────┘              └───────────┘
```

## File Organization

```
KinectRos22/
├── docker/
│   ├── Dockerfile              # libfreenect2 + ROS 2 Humble
│   └── docker-compose.yml      # USB passthrough, privileged mode
│
├── kinect2_ros2/               # Main ROS 2 packages
│   ├── kinect2_bridge/         # Camera driver node
│   │   ├── launch/
│   │   │   ├── kinect2_single.launch.py
│   │   │   ├── kinect2_dual_dynamic.launch.py
│   │   │   └── kinect2_rviz.rviz
│   │   └── src/
│   ├── kinect2_registration/   # Depth-to-color registration
│   └── kinect2_calibration/    # Calibration tools
│
├── config/
│   ├── kinectrviz.rviz         # Single camera RViz config
│   ├── dual_kinect.rviz        # Dual camera RViz config
│   ├── camera
_config.yaml      # Camera positions
│   └── dual_kinect_serials.yaml
│
├── bash_scripts/container/
│   ├── launch_dual_kinect2.sh  # Launch helper
│   ├── test_kinect2.sh         # Device diagnostics
│   └── bashrc_extensions.sh    # Shell setup
│
├── device_setup.sh             # Host USB/udev setup
└── 99-kinect-devices.rules     # udev rules
```

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| `LIBUSB_ERROR_ACCESS` | Permission denied | Run `device_setup.sh` |
| `LIBUSB_ERROR_TIMEOUT` | USB buffer too small | Set buffer to 128MB |
| `Device not found` | Not connected/powered | Check USB and power |
| `Device busy` | Another process using it | Kill `Protonect` or other nodes |
| `USB 2.0 mode` | Wrong port | Use USB 3.0 port |

## Performance Tips

1. **USB Configuration**
   - Use separate USB 3.0 controllers for each Kinect
   - Verify USB 3.0 with `lsusb -t` (look for "5000M")

2. **Resolution Selection**
   - Use SD (512×424) for dual camera point clouds
   - Use QHD (960×540) for single camera with depth

3. **CPU Usage**
   - Point cloud generation is CPU-intensive
   - Consider disabling unused streams

4. **Docker**
   - Run with `--privileged` for USB access
   - Mount `/dev/bus/usb` for dynamic device detection

## Summary

The dual Kinect v2 system uses:
- **libfreenect2** for hardware communication
- **kinect2_bridge** for ROS 2 integration
- **Static transforms** to place cameras in world frame
- **USB 3.0** (mandatory) with external power adapters
- **SD resolution** recommended for dual camera bandwidth