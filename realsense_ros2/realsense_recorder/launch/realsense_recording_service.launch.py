#!/usr/bin/env python3
"""Launch the recording manager without starting capture."""

import os
import yaml

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

from realsense_recorder.recording_config import (
    build_recording_setup,
    selected_cameras,
)


def _from_config_dir(filename: str, fallback: str) -> str:
    config_dir = os.environ.get("SENSOR_CONFIG_DIR", "")
    if config_dir:
        candidate = os.path.join(config_dir, filename)
        if os.path.isfile(candidate):
            return candidate
    return fallback


def _default_realsense_config():
    base_ws = os.environ.get("BASE_WS", "/home/ubuntu/base_ws")
    return _from_config_dir(
        "realsense_cameras.yaml",
        os.path.join(base_ws, "src", "realsense_ros2", "realsense_config.yaml"),
    )


def launch_setup(context, *args, **kwargs):
    del args, kwargs

    config_file = LaunchConfiguration("config_file").perform(context)
    recording_config = LaunchConfiguration("recording_config").perform(context)

    _, cameras = selected_cameras(config_file)
    if not cameras:
        raise RuntimeError(f"No cameras are marked record: true in {config_file}.")

    with open(recording_config, "r", encoding="utf-8") as handle:
        recording_cfg = yaml.safe_load(handle)["recording_settings"]

    setup = build_recording_setup(cameras, recording_cfg.get("streams"))

    # launch_ros's parameter conversion can't infer the element type of an
    # empty STRING_ARRAY (it ends up as () and fails validation). Pad empty
    # arrays with a single empty string; the recorder/manager both filter
    # falsy entries out on read.
    def non_empty(values):
        return values if values else [""]

    return [
        Node(
            package="realsense_recorder",
            executable="recording_manager",
            name="recording_manager",
            output="screen",
            parameters=[{
                "output_root": recording_cfg["output_root"],
                "participant_id": recording_cfg["uuid"],
                "color_topics": non_empty(setup["color_topics"]),
                "color_remaps": non_empty(setup["color_remaps"]),
                "color_compressed_topics": non_empty(setup["color_compressed_topics"]),
                "topic_fps_overrides": non_empty(setup["topic_fps_overrides"]),
                "bag_topics": non_empty(setup["bag_topics"]),
                "video_encoder": recording_cfg["video_encoder"],
                "video_crf": recording_cfg["video_crf"],
                "bag_storage": recording_cfg["bag_storage"],
                "bag_compression": recording_cfg.get("bag_compression", "none"),
            }],
        )
    ]


def generate_launch_description():
    pkg_share = get_package_share_directory("realsense_recorder")
    default_recording_config = _from_config_dir(
        "recording.yaml",
        os.path.join(pkg_share, "config", "recording_config.yaml"),
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            "config_file",
            default_value=_default_realsense_config(),
            description="Path to realsense_config.yaml",
        ),
        DeclareLaunchArgument(
            "recording_config",
            default_value=default_recording_config,
            description="Path to recording settings YAML.",
        ),
        OpaqueFunction(function=launch_setup),
    ])
