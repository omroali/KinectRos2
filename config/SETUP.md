# Config Volume Setup

This guide explains how to set up and use the RViz configuration files with your Docker container.

## Quick Start

### 1. Recreate Docker Container with Config Volume

The `config/` directory is now mounted as a volume in the Docker container. To apply this change:

```bash
cd docker
docker-compose down
docker-compose up -d
```

### 2. Verify Config Volume is Mounted

```bash
docker exec -it <container_id> ls -la /home/ros/config/
```

You should see:
- `kinectrviz.rviz` - Single camera config
- `dual_kinect.rviz` - Dual camera config
- `README.md` - Documentation

### 3. Launch RViz with Config

**Inside the container:**
```bash
source /opt/ros/humble/setup.bash
source ~/base_ws/install/setup.bash
rviz2 -d ~/config/kinectrviz.rviz
```

**From host machine:**
```bash
docker exec -it <container_id> bash -c "source /opt/ros/humble/setup.bash && source /home/ros/base_ws/install/setup.bash && rviz2 -d /home/ros/config/kinectrviz.rviz"
```

## What's Included

### Configuration Files

1. **`kinectrviz.rviz`** - Single Kinect v2 Camera
   - Fixed Frame: `kinect2_link`
   - SD Point Cloud (512x424) - Enabled
   - QHD Point Cloud (960x540) - Available but disabled
   - HD Color Image (1920x1080)
   - Optimized queue sizes and QoS settings

2. **`dual_kinect.rviz`** - Dual Kinect v2 Cameras
   - Fixed Frame: `world`
   - TF display for coordinate frames
   - Two point cloud displays (one per camera)
   - Synchronized visualization

### Key Improvements

✅ **Increased Queue Size:** Changed from 5 to 10 to prevent message drops
✅ **Best Effort QoS:** Lower latency for point cloud visualization
✅ **PointCloud2 Display:** Better performance than DepthCloud
✅ **RGB8 Color:** Shows true camera colors on point clouds
✅ **Optimized Settings:** Pre-configured for best visualization

## Docker Volume Configuration

In `docker/docker-compose.yml`:

```yaml
volumes:
  - ../config:/home/ros/config:rw
```

This mounts the `config/` directory from your host machine to `/home/ros/config/` in the container with read-write access.

### Benefits

- ✅ Edit configs on host, instantly available in container
- ✅ Save new configs from RViz, automatically on host
- ✅ No need to rebuild container for config changes
- ✅ Version control friendly (configs in git)

## Troubleshooting

### Container Not Starting

If the container fails to start after updating docker-compose:

```bash
cd docker
docker-compose down
docker-compose up -d
docker logs <container_id>
```

### Config Directory Not Found

Make sure you're running from the correct directory:

```bash
cd /data/Academic/PhD_Code/KinectRos22
ls config/  # Should show .rviz files
cd docker
docker-compose up -d
```

### RViz Can't Find Config

Check the path inside container:

```bash
docker exec -it <container_id> bash
ls -la ~/config/
pwd  # Should be /home/ros
```

### Display Not Working

Make sure X11 forwarding is set up:

```bash
xhost +local:docker
echo $DISPLAY  # Should show :0 or similar
```

Inside container:
```bash
echo $DISPLAY  # Should match host
```

## Customizing Configs

### Option 1: Edit on Host

```bash
cd config/
# Edit .rviz files with any text editor
nano kinectrviz.rviz
```

Changes are immediately available in the container.

### Option 2: Edit in RViz

1. Launch RViz in container
2. Make your changes
3. File → Save Config As
4. Save to `/home/ros/config/my_custom.rviz`
5. File appears in `config/` on your host machine

## Next Steps

1. **Rebuild kinect2_bridge** with updated launch file:
   ```bash
   cd ~/base_ws
   colcon build --packages-select kinect2_bridge --symlink-install
   source install/setup.bash
   ```

2. **Launch kinect2_bridge:**
   ```bash
   ros2 launch kinect2_bridge kinect2_bridge_launch.yaml
   ```

3. **Launch RViz with config:**
   ```bash
   rviz2 -d ~/config/kinectrviz.rviz
   ```

4. **Verify point clouds are visible:**
   - You should see colored 3D point cloud
   - HD color image at the bottom
   - No message filter warnings

## Directory Structure

```
KinectRos22/
├── config/                          # New config directory
│   ├── README.md                    # Usage documentation
│   ├── SETUP.md                     # This file
│   ├── kinectrviz.rviz             # Single camera config
│   └── dual_kinect.rviz            # Dual camera config
├── docker/
│   ├── docker-compose.yml          # Updated with config volume
│   └── Dockerfile
├── kinect2_ros2/
│   └── kinect2_bridge/
│       └── launch/
│           └── kinect2_bridge_launch.yaml  # Updated with world frame
└── ...
```

## Integration with Existing Scripts

Update your bash scripts to use the configs:

```bash
# In launch scripts
rviz2 -d ~/config/kinectrviz.rviz &

# Or for dual camera
rviz2 -d ~/config/dual_kinect.rviz &
```

## Summary

The config volume setup provides:
- 🎯 Easy access to RViz configs
- 🔄 Bidirectional sync between host and container
- 📝 Version control for visualization settings
- 🚀 No container rebuilds needed for config changes
- 🛠️ Pre-configured optimized settings

For more details, see `config/README.md`.