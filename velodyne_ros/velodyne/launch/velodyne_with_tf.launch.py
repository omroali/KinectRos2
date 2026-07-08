#!/usr/bin/env python3
"""Velodyne driver + map->velodyne static TF, driven by the unified config.

Reads $SENSOR_CONFIG_DIR/velodyne.yaml (see config/README.md) for the device
IP and sensor pose, launches the standard VLP16 pipeline with the point cloud
stamped in the sensor frame, and runs static_tf_from_yaml.py to place that
frame in the world. The TF node watches the YAML, so editing the pose and
saving repositions the sensor live.
"""

import os

import yaml
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def _config_path() -> str:
    config_dir = os.environ.get("SENSOR_CONFIG_DIR", "/home/ubuntu/config")
    return os.path.join(config_dir, "velodyne.yaml")


def _load_velodyne_entry(config_path: str) -> dict:
    if not os.path.isfile(config_path):
        return {}
    with open(config_path, "r") as f:
        cfg = yaml.safe_load(f) or {}
    cameras = cfg.get("cameras", {})
    if not isinstance(cameras, dict) or not cameras:
        return {}
    # single-sensor file: take the first entry
    entry = next(iter(cameras.values()))
    return entry if isinstance(entry, dict) else {}


def generate_launch_description():
    config_path = _config_path()
    entry = _load_velodyne_entry(config_path)

    device_ip = str(entry.get("device_ip", "10.68.0.55"))
    frame = str(entry.get("frame", "velodyne"))

    velodyne_share = get_package_share_directory("velodyne")
    vlp16_launch = os.path.join(
        velodyne_share, "launch", "velodyne-all-nodes-VLP16-launch.py"
    )

    actions = [
        DeclareLaunchArgument(
            "device_ip",
            default_value=device_ip,
            description="Velodyne IP (default from velodyne.yaml).",
        ),
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource(vlp16_launch),
            launch_arguments={
                "device_ip": LaunchConfiguration("device_ip"),
                # Stamp the cloud in the sensor frame; the static TF below
                # places it in the world. (Upstream default is "map", which
                # pins the cloud to the world origin.)
                "frame_id": frame,
            }.items(),
        ),
    ]

    if os.path.isfile(config_path):
        actions.append(
            Node(
                package="kinect2_bridge",
                executable="static_tf_from_yaml.py",
                name="velodyne_static_tf",
                output="screen",
                arguments=[config_path],
            )
        )

    return LaunchDescription(actions)
