# Unified sensor configuration

Single source of truth for every sensor in the rig. This directory is
mounted into the container at `/home/ubuntu/config` and exported as
`$SENSOR_CONFIG_DIR`; all launch files look here first and fall back to
their installed package copies if a file is missing.

| File | Consumed by |
|------|-------------|
| `kinect_cameras.yaml` | `multi_kinect.launch.py`, Kinect recording launches, `vicon_marker_calibration_tf.py` |
| `realsense_cameras.yaml` | `realsense_multi_camera.launch.py`, RealSense recording service |
| `velodyne.yaml` | `velodyne_with_tf.launch.py` (driver IP + map→velodyne pose) |
| `recording.yaml` | Both recording managers (encoder, CRF, bag storage/compression, per-stream toggles) |

Edits take effect on the next node (re)launch — no rebuild required.
Exception: the velodyne pose is live — `static_tf_from_yaml.py` watches
`velodyne.yaml` and re-publishes the transform when the file changes.
