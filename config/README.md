# RViz Configuration Files

This directory contains RViz configuration files for visualizing Kinect camera data.

## Available Configurations

### `kinectrviz.rviz`
Single Kinect v2 camera visualization with:
- **Fixed Frame:** `kinect2_link`
- **PointCloud2 displays:**
  - SD resolution (512x424) - enabled by default
  - QHD resolution (960x540) - disabled by default, can be enabled in RViz
- **Image display:** HD color image (1920x1080)
- **Grid reference:** XZ plane
- **Queue size:** 10 (increased from default 5)
- **Reliability:** Best Effort

### `dual_kinect.rviz`
Dual Kinect v2 camera visualization with:
- **Fixed Frame:** `world`
- **TF display:** Shows coordinate frame transforms
- **PointCloud2 displays:** One for each camera
- **Grid reference:** XY plane

## Usage

### From Docker Container

The config directory is mounted as a volume at `/home/ros/config` in the container.

**Launch RViz with single camera config:**
```bash
rviz2 -d ~/config/kinectrviz.rviz
```

**Launch RViz with dual camera config:**
```bash
rviz2 -d ~/config/dual_kinect.rviz
```

### From Host Machine

**When using docker-compose:**
```bash
docker exec -it <container_name> bash -c "source /opt/ros/humble/setup.bash && source ~/base_ws/install/setup.bash && rviz2 -d ~/config/kinectrviz.rviz"
```

### Loading Config in Running RViz

If RViz is already running:
1. Click **File** → **Open Config**
2. Navigate to `/home/ros/config/`
3. Select the desired `.rviz` file
4. Click **Open**

## Customization

You can modify these files directly on your host machine. Changes will be immediately available in the Docker container since this directory is mounted as a volume.

### Key Settings to Adjust

**Point Cloud Size:**
- Increase `Size (m)` value (default: 0.01) to make points larger
- Try values like 0.02 or 0.03 for denser appearance

**Point Cloud Style:**
- `Points` - faster rendering, simple dots
- `Flat Squares` - better visibility (default)
- `Spheres` - highest quality, slower rendering

**Color Transformer:**
- `RGB8` - use actual camera colors (default)
- `Intensity` - grayscale based on depth
- `AxisColor` - color by X/Y/Z axis

**Queue Size:**
- Increase if you see message filter warnings
- Default: 10
- Recommended range: 10-50

**Reliability Policy:**
- `Best Effort` - lower latency, may drop messages (default for point clouds)
- `Reliable` - ensures delivery, higher latency (good for images)

## Troubleshooting

### No Point Clouds Visible

1. **Check if point clouds are publishing:**
   ```bash
   ros2 topic hz /kinect2/sd/points
   ```

2. **Verify Fixed Frame matches your TF tree:**
   ```bash
   ros2 run tf2_ros tf2_echo kinect2_link kinect2_rgb_optical_frame
   ```

3. **Enable the display in RViz:**
   - Expand the display in the left panel
   - Check the checkbox next to the display name

4. **Increase point size:**
   - Set `Size (m)` to 0.02 or higher

### Message Filter Warnings

If you see "discarding message because the queue is full":
1. Increase `Queue Size` in the display settings
2. Change `Reliability Policy` to `Best Effort`
3. Set Fixed Frame to `kinect2_link` instead of `world`

### Slow Performance

1. **Reduce point cloud resolution:**
   - Use SD instead of QHD
   - Disable unused displays

2. **Change rendering style:**
   - Use `Points` instead of `Spheres`

3. **Reduce queue size:**
   - Lower values use less memory

## Creating New Configs

To save your custom RViz configuration:
1. Make your changes in RViz
2. Click **File** → **Save Config As**
3. Save to `/home/ros/config/your_config_name.rviz`
4. The file will appear on your host machine in this directory

## Docker Volume Mount

This directory is mounted in `docker-compose.yml` as:
```yaml
- ../config:/home/ros/config:rw
```

Any changes made on the host are immediately visible in the container and vice versa.