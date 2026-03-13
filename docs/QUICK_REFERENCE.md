# Kinect v2 Quick Reference Card

## System Info

**Hardware:** 2x Kinect v2 (Xbox One Kinect)  
**USB ID:** `045e:02d8`  
**USB Requirement:** USB 3.0 (mandatory)  
**Driver:** libfreenect2  
**ROS Package:** kinect2_bridge  

---

## Quick Commands

### Check Devices
```bash
# Check USB detection
lsusb | grep "045e:02d8"  # Should show 2 devices

# Verify USB 3.0 (not 2.0)
lsusb -t | grep -A 2 "045e:02d8"  # Look for "5000M"

# Test with libfreenect2
Protonect  # Press Ctrl+C to exit
```

### Run Tests
```bash
cd ~/bash_scripts
./test_kinect2.sh  # Full diagnostics
```

### Build Workspace
```bash
cd ~/base_ws
colcon build --symlink-install
source install/setup.bash
```

### Launch

**Single Camera:**
```bash
ros2 launch kinect2_bridge kinect2_bridge.launch.yaml
```

**Dual Cameras (default positions):**
```bash
cd ~/bash_scripts
./launch_dual_kinect2.sh
```

**Dual Cameras (custom position):**
```bash
./launch_dual_kinect2.sh --camera2-x 2.0 --camera2-y 2.0 --camera2-yaw -1.5708
```

**With specific serials:**
```bash
./launch_dual_kinect2.sh \
  --camera1-serial 123456 \
  --camera2-serial 234567 \
  --camera2-x 2.0 --camera2-y 2.0
```

---

## Key Topics

### Camera 1 Topics
```
/kinect2_1/hd/image_color          # 1920x1080 RGB
/kinect2_1/qhd/image_color         # 960x540 RGB
/kinect2_1/sd/image_color          # 512x424 RGB
/kinect2_1/sd/image_depth          # 512x424 Depth
/kinect2_1/sd/points               # Point cloud (SD)
/kinect2_1/qhd/points              # Point cloud (QHD)
```

### Camera 2 Topics
```
/kinect2_2/...  # Same structure as camera 1
```

### Check Topics
```bash
ros2 topic list | grep kinect2
ros2 topic hz /kinect2_1/qhd/image_color  # Should be ~30 Hz
ros2 topic echo /kinect2_1/sd/points --once
```

---

## RViz Setup

**Using Pre-configured Files:**
```bash
# Single camera
rviz2 -d ~/config/kinectrviz.rviz

# Dual cameras
rviz2 -d ~/config/dual_kinect.rviz
```

**Manual Setup (if needed):**
```bash
rviz2
```

1. **Fixed Frame:** Set to `kinect2_link` (single) or `world` (dual)
2. **Add PointCloud2:**
   - Topic: `/kinect2/sd/points` (single) or `/kinect2_1/sd/points` (dual)
   - Color Transformer: RGB8
   - Size (m): 0.01
   - Reliability: Best Effort
3. **Add PointCloud2:** (dual camera only)
   - Topic: `/kinect2_2/sd/points`
   - Color Transformer: RGB8
4. **Add TF** to see camera frames
5. **Add Image:**
   - Topic: `/kinect2/hd/image_color` (single) or `/kinect2_1/hd/image_color` (dual)

**Note:** Config files are in `/home/ros/config/` (mounted from `config/` directory)

---

## Recording Data

```bash
# Record point clouds and transforms
ros2 bag record \
  /kinect2_1/sd/points \
  /kinect2_2/sd/points \
  /tf /tf_static

# Record with timestamp
ros2 bag record -o kinect2_$(date +%Y%m%d_%H%M%S) \
  /kinect2_1/qhd/image_color \
  /kinect2_2/qhd/image_color \
  /kinect2_1/sd/points \
  /kinect2_2/sd/points \
  /tf /tf_static
```

---

## Troubleshooting

### No Devices Detected
```bash
# 1. Check USB
lsusb | grep "045e:02d8"

# 2. Check power (LEDs should be on)

# 3. Test libfreenect2
Protonect

# 4. Check permissions
ls -l /dev/bus/usb/*/* | grep "02d8"
```

### Device Busy
```bash
killall Protonect
killall kinect2_bridge_node
```

### USB 2.0 Warning
Kinect v2 requires USB 3.0!
```bash
lsusb -t  # Verify "5000M" not "480M"
```

### Only One Camera Works
- Use separate USB 3.0 controllers
- Check second camera power
- Try different USB ports
- Reduce bandwidth: use SD resolution

---

## Launch Script Options

```
--camera1-ns NAME          Camera 1 namespace (default: kinect2_1)
--camera2-ns NAME          Camera 2 namespace (default: kinect2_2)
--camera1-serial SERIAL    Camera 1 serial number
--camera2-serial SERIAL    Camera 2 serial number
--camera2-x VALUE          X position in meters (default: 1.0)
--camera2-y VALUE          Y position in meters (default: 0.0)
--camera2-z VALUE          Z position in meters (default: 0.0)
--camera2-roll VALUE       Roll in radians (default: 0.0)
--camera2-pitch VALUE      Pitch in radians (default: 0.0)
--camera2-yaw VALUE        Yaw in radians (default: -0.523599)
--no-rviz                  Don't launch RViz
--no-transforms            Don't publish transforms
```

---

## Resolution Guide

| Name | RGB | Depth | Bandwidth | Use Case |
|------|-----|-------|-----------|----------|
| SD   | 512x424 | 512x424 | Low | Point clouds, dual camera |
| QHD  | 960x540 | 512x424 | Medium | Balanced |
| HD   | 1920x1080 | 512x424 | High | Single camera, high quality |

**Recommendation:** Use SD for dual camera setups to avoid USB bandwidth issues.

---

## Coordinate Frames

```
world
├── kinect2_1_link (origin)
│   ├── kinect2_1_rgb_optical_frame
│   └── kinect2_1_ir_optical_frame
└── kinect2_2_link (at specified position)
    ├── kinect2_2_rgb_optical_frame
    └── kinect2_2_ir_optical_frame
```

---

## Common Positions

**Side-by-side (1 meter apart):**
```bash
--camera2-x 1.0 --camera2-y 0.0 --camera2-yaw 0.0
```

**90° apart (L-shape):**
```bash
--camera2-x 2.0 --camera2-y 2.0 --camera2-yaw -1.5708
```

**Opposite facing:**
```bash
--camera2-x 2.0 --camera2-y 0.0 --camera2-yaw 3.14159
```

---

## Documentation

- `KINECT2_SETUP.md` - Complete setup guide
- `MIGRATION_TO_KINECT2.md` - Migration info
- `README.md` - Project overview
- `./test_kinect2.sh` - Automated diagnostics

---

## Docker

**Rebuild container:**
```bash
cd docker
docker-compose down
docker-compose build
docker-compose up -d
```

**Enter container:**
```bash
docker exec -it <container_name> /bin/bash
```

---

## Performance Tips

1. **USB 3.0:** Mandatory, verify with `lsusb -t`
2. **Separate controllers:** Use different USB controllers for each camera
3. **SD resolution:** Best for dual camera bandwidth
4. **Frame rate:** 30 Hz is standard
5. **Point clouds:** CPU intensive, monitor system load

---

## Emergency Reset

```bash
# Kill all related processes
killall kinect2_bridge_node Protonect rviz2

# Rebuild workspace
cd ~/base_ws
rm -rf build/ install/ log/
colcon build --symlink-install
source install/setup.bash

# Test single camera first
ros2 launch kinect2_bridge kinect2_bridge.launch.yaml
```

---

**For help:** Run `./test_kinect2.sh` or see `KINECT2_SETUP.md`
