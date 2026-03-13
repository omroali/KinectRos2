# RViz Configuration Files

This directory contains RViz configuration files and camera settings for Kinect v2.

## RViz Configurations

### `kinectrviz.rviz`
Single Kinect v2 camera visualization:
- **Fixed Frame:** `kinect2_link`
- **PointCloud2:** SD resolution (512×424)
- **Image:** HD color (1920×1080)
- **QoS:** Best Effort (optimized for point clouds)

### `dual_kinect.rviz`
Dual Kinect v2 camera visualization:
- **Fixed Frame:** `world`
- **TF Display:** Shows all camera frames
- **PointCloud2:** One display per camera
- **Depth images:** Both cameras

## Camera Configuration Files

### `camera_config.yaml`
Defines camera positions for dual setup:
- Camera frame names
- Position (x, y, z)
- Orientation (roll, pitch, yaw)
- World frame reference

### `dual_kinect_serials.yaml`
Stores serial numbers for your Kinect v2 devices.

## Usage

### Launch RViz with Config

Inside the Docker container:
```bash
# Single camera
rviz2 -d ~/config/kinectrviz.rviz

# Dual cameras
rviz2 -d ~/config/dual_kinect.rviz
```

### Docker Volume Mount

This directory is mounted at `/home/ros/config/` in the container:
```yaml
volumes:
  - ../config:/home/ros/config:rw
```

Changes made on the host are immediately available in the container.

## Customizing Configs

### Edit on Host
Edit `.rviz` files directly - changes sync to the container immediately.

### Save from RViz
1. Make changes in RViz
2. File → Save Config As
3. Save to `/home/ros/config/your_config.rviz`

## Key RViz Settings for Kinect v2

### Point Cloud Display
- **Topic:** `/kinect2_1/sd/points` or `/kinect2_1/qhd/points`
- **Style:** Flat Squares or Points
- **Size:** 0.01m
- **Color Transformer:** RGB8
- **Reliability:** Best Effort

### Image Display
- **Topic:** `/kinect2_1/hd/image_color`
- **Reliability:** Reliable

### Common Issues

**No point clouds visible:**
1. Check topic is publishing: `ros2 topic hz /kinect2_1/sd/points`
2. Set Reliability to "Best Effort"
3. Set Fixed Frame to match your TF tree

**Message filter warnings:**
- Increase Queue Size to 10-20
- Use Best Effort reliability