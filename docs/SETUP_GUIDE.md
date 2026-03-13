# Kinect v2 ROS 2 Setup Guide

## 1. Device Setup

Run the device setup script on the **host machine** (not in Docker):

```bash
cd /path/to/KinectRos22
sudo ./device_setup.sh
```

This script:
- Installs udev rules for Kinect USB permissions
- Adds user to required groups (plugdev, video)
- Increases USB buffer to 128MB
- Fixes permissions on connected devices

After running, log out and log back in for group changes to take effect.

If devices are replugged later, re-run:
```bash
sudo ./device_setup.sh
```

## 2. Docker Setup

Start the container with USB access:

```bash
cd /path/to/KinectRos22/docker
docker compose up -d
docker compose exec ros2_humble bash
```

Inside the container, build the workspace:

```bash
cd ~/base_ws
source /opt/ros/humble/setup.bash
colcon build --symlink-install
source install/setup.bash
```

## 3. Running a Single Camera

```bash
ros2 launch kinect2_bridge kinect2_single.launch.py \
    serial:=<SERIAL_NUMBER> \
    namespace:=kinect2_1
```

Example:
```bash
ros2 launch kinect2_bridge kinect2_single.launch.py \
    serial:=007425354147 \
    namespace:=kinect2_1
```

With initial position:
```bash
ros2 launch kinect2_bridge kinect2_single.launch.py \
    serial:=007425354147 \
    namespace:=kinect2_1 \
    x:=0.0 y:=0.0 z:=1.0 \
    roll:=0.0 pitch:=0.0 yaw:=0.0
```

With dynamic TF (runtime adjustable):
```bash
ros2 launch kinect2_bridge kinect2_single.launch.py \
    serial:=007425354147 \
    namespace:=kinect2_1 \
    use_dynamic_tf:=true
```

## 4. Running Dual Cameras

```bash
ros2 launch kinect2_bridge kinect2_dual_dynamic.launch.py \
    serial1:=007425354147 \
    serial2:=001934470647
```

With initial positions:
```bash
ros2 launch kinect2_bridge kinect2_dual_dynamic.launch.py \
    serial1:=007425354147 \
    serial2:=001934470647 \
    camera1_x:=0.0 camera1_y:=0.0 camera1_z:=0.0 \
    camera2_x:=1.0 camera2_y:=0.0 camera2_z:=0.0 \
    camera2_yaw:=-0.5236
```

## 5. Changing Camera Position at Runtime

Requires `use_dynamic_tf:=true` (single camera) or the dual dynamic launch.

Command line:
```bash
ros2 param set /dynamic_camera_tf camera1_x 0.5
ros2 param set /dynamic_camera_tf camera1_y 0.3
ros2 param set /dynamic_camera_tf camera1_z 1.0
ros2 param set /dynamic_camera_tf camera1_roll 0.0
ros2 param set /dynamic_camera_tf camera1_pitch 0.0
ros2 param set /dynamic_camera_tf camera1_yaw 0.785

ros2 param set /dynamic_camera_tf camera2_x 1.5
ros2 param set /dynamic_camera_tf camera2_y -0.5
ros2 param set /dynamic_camera_tf camera2_yaw -0.5
```

GUI method:
```bash
ros2 run rqt_reconfigure rqt_reconfigure
```

## 6. RViz Visualization

Launch RViz with the provided config:
```bash
rviz2 -d ~/base_ws/install/kinect2_bridge/share/kinect2_bridge/launch/kinect2_rviz.rviz
```

Set Fixed Frame to `world`.

## 7. Topics

Each camera publishes under its namespace:

| Topic | Description |
|-------|-------------|
| `/<ns>/hd/image_color` | 1920x1080 color image |
| `/<ns>/qhd/image_color` | 960x540 color image |
| `/<ns>/sd/image_color_rect` | 512x424 color image |
| `/<ns>/sd/image_depth_rect` | 512x424 depth image |
| `/<ns>/sd/points` | SD point cloud |
| `/<ns>/qhd/points` | QHD point cloud |

## 8. TF Frames

```
world
└── kinect2_1_link
    └── kinect2_1_rgb_optical_frame
        └── kinect2_1_ir_optical_frame
└── kinect2_2_link
    └── kinect2_2_rgb_optical_frame
        └── kinect2_2_ir_optical_frame
```

## 9. Troubleshooting

**LIBUSB_ERROR_ACCESS**: Run `sudo ./device_setup.sh` on host.

**LIBUSB_ERROR_TIMEOUT**: Check USB buffer size:
```bash
cat /sys/module/usbcore/parameters/usbfs_memory_mb
```
Should be 128. If not, re-run device_setup.sh.

**Device not found**: Verify Kinect is connected:
```bash
lsusb | grep -i microsoft
```

**Point cloud not visible in RViz**: Set QoS Reliability to "Best Effort" in RViz display settings.

## 10. Serial Numbers

Find connected Kinect serial numbers:
```bash
ros2 launch kinect2_bridge kinect2_single.launch.py
```
Check output for "Kinect2 devices found" listing serials.