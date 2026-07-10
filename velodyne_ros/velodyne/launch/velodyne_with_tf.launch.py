#!/usr/bin/env python3
"""Velodyne driver + map->velodyne static TF, driven by the unified config.

Reads $SENSOR_CONFIG_DIR/velodyne.yaml (see config/README.md) for per-unit
device IP, port, frame_id, and sensor pose; launches a namespaced VLP16
pipeline per entry with enabled: true, and runs a single static_tf_from_yaml.py
node to place every unit's frame in the world. The TF node watches the YAML,
so editing a pose and saving repositions the sensor live.
"""

import os

import yaml
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import GroupAction, IncludeLaunchDescription, LogInfo
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.actions import Node, PushRosNamespace


def _config_path() -> str:
    config_dir = os.environ.get("SENSOR_CONFIG_DIR", "/home/ubuntu/config")
    return os.path.join(config_dir, "velodyne.yaml")


def _load_velodyne_entries(config_path: str) -> list[tuple[str, dict]]:
    if not os.path.isfile(config_path):
        return []
    with open(config_path, "r") as f:
        cfg = yaml.safe_load(f) or {}
    cameras = cfg.get("cameras", {})
    if not isinstance(cameras, dict):
        return []
    entries: list[tuple[str, dict]] = []
    for name, entry in cameras.items():
        if not isinstance(entry, dict) or not entry.get("enabled", False):
            continue
        entries.append((str(name), entry))
    return entries


def generate_launch_description():
    config_path = _config_path()
    entries = _load_velodyne_entries(config_path)

    velodyne_share = get_package_share_directory("velodyne")
    vlp16_launch = os.path.join(
        velodyne_share, "launch", "velodyne-all-nodes-VLP16-launch.py"
    )

    actions = []

    for entry_name, entry in entries:
        model = str(entry.get("model", "")).upper()
        if model != "VLP16":
            actions.append(
                LogInfo(
                    msg=f"Unknown model '{model}' for {entry_name}; only VLP16 supported. Skipping."
                )
            )
            continue

        actions.append(
            GroupAction(
                [
                    PushRosNamespace(entry_name),
                    IncludeLaunchDescription(
                        PythonLaunchDescriptionSource(vlp16_launch),
                        launch_arguments={
                            "device_ip": str(entry.get("device_ip", "")),
                            "port": str(entry.get("port", 2368)),
                            "frame_id": str(entry.get("frame", entry_name)),
                        }.items(),
                    ),
                ]
            )
        )

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
