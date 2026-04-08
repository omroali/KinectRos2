#!/usr/bin/env python3

# Copyright (c) 2024
# Dual Kinect v2 Launch File for ROS 2
#
# Loads configuration from:
#   - config/dual_kinect_serials.yaml  (serial numbers per camera namespace)
#   - config/camera_config.yaml        (camera positions and orientations)
#
# Usage:
#   ros2 launch kinect2_bridge dual_kinect2_simple.launch.py
#
# To override transforms at launch time:
#   ros2 launch kinect2_bridge dual_kinect2_simple.launch.py \
#       publish_transforms:=false

import os
import yaml

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, GroupAction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node, PushRosNamespace


def _load_camera_config(config_path: str) -> dict:
    """Parse camera_config.yaml and return a flat dict of string values ready for
    use as static_transform_publisher arguments."""
    with open(config_path, "r") as f:
        cfg = yaml.safe_load(f)

    def _s(val):
        """Convert a numeric value to a plain string (no scientific notation)."""
        return str(float(val))

    result = {
        "world_frame":      cfg.get("world_frame", "map"),
        "publish_rate":     float(cfg.get("publish_rate", 50.0)),
        # Camera 1
        "cam1_frame":       cfg["camera1"]["frame"],
        "cam1_x":           _s(cfg["camera1"]["position"]["x"]),
        "cam1_y":           _s(cfg["camera1"]["position"]["y"]),
        "cam1_z":           _s(cfg["camera1"]["position"]["z"]),
        "cam1_roll":        _s(cfg["camera1"]["orientation"]["roll"]),
        "cam1_pitch":       _s(cfg["camera1"]["orientation"]["pitch"]),
        "cam1_yaw":         _s(cfg["camera1"]["orientation"]["yaw"]),
        # Camera 2
        "cam2_frame":       cfg["camera2"]["frame"],
        "cam2_x":           _s(cfg["camera2"]["position"]["x"]),
        "cam2_y":           _s(cfg["camera2"]["position"]["y"]),
        "cam2_z":           _s(cfg["camera2"]["position"]["z"]),
        "cam2_roll":        _s(cfg["camera2"]["orientation"]["roll"]),
        "cam2_pitch":       _s(cfg["camera2"]["orientation"]["pitch"]),
        "cam2_yaw":         _s(cfg["camera2"]["orientation"]["yaw"]),
    }
    return result


def generate_launch_description():
    # ------------------------------------------------------------------ #
    #  Locate installed config files                                       #
    # ------------------------------------------------------------------ #
    pkg_share = get_package_share_directory("kinect2_bridge")
    config_dir = os.path.join(pkg_share, "config")

    serials_yaml    = os.path.join(config_dir, "dual_kinect_serials.yaml")
    camera_cfg_path = os.path.join(config_dir, "camera_config.yaml")

    if not os.path.isfile(serials_yaml):
        raise FileNotFoundError(
            f"Serial config not found: {serials_yaml}\n"
            "Did you rebuild with 'colcon build'?"
        )
    if not os.path.isfile(camera_cfg_path):
        raise FileNotFoundError(
            f"Camera config not found: {camera_cfg_path}\n"
            "Did you rebuild with 'colcon build'?"
        )

    # Parse camera positions at launch time
    cam = _load_camera_config(camera_cfg_path)

    # ------------------------------------------------------------------ #
    #  Launch arguments                                                    #
    # ------------------------------------------------------------------ #
    camera1_namespace_arg = DeclareLaunchArgument(
        "camera1_namespace",
        default_value="kinect2_1",
        description="ROS namespace for the first Kinect v2",
    )

    camera2_namespace_arg = DeclareLaunchArgument(
        "camera2_namespace",
        default_value="kinect2_2",
        description="ROS namespace for the second Kinect v2",
    )

    publish_transforms_arg = DeclareLaunchArgument(
        "publish_transforms",
        default_value="true",
        description="Publish static TF transforms between camera frames and world",
    )

    camera1_namespace  = LaunchConfiguration("camera1_namespace")
    camera2_namespace  = LaunchConfiguration("camera2_namespace")
    publish_transforms = LaunchConfiguration("publish_transforms")

    # ------------------------------------------------------------------ #
    #  Camera 1 — Kinect v2 Bridge                                        #
    #                                                                      #
    #  Serial is loaded from dual_kinect_serials.yaml.                    #
    #  The YAML uses the ROS 2 parameter-file format:                     #
    #    /kinect2_1/kinect2_bridge:                                        #
    #      ros__parameters:                                                #
    #        sensor: "001934470647"                                        #
    #  ROS 2 matches the key against the node's fully-qualified name, so   #
    #  passing the file to both nodes is safe — each picks only its entry. #
    # ------------------------------------------------------------------ #
    camera1_group = GroupAction([
        PushRosNamespace(camera1_namespace),
        Node(
            package="kinect2_bridge",
            executable="kinect2_bridge_node",
            name="kinect2_bridge",
            output="screen",
            parameters=[
                # Serial number resolved from YAML (kinect2_1 → 001934470647)
                serials_yaml,
                # Runtime parameters
                {
                    "base_name":           camera1_namespace,
                    "publish_tf":          True,
                    "base_name_tf":        camera1_namespace,
                    "fps_limit":           30.0,
                    "use_png":             False,
                    "depth_method":        "default",
                    "reg_method":          "default",
                    "max_depth":           12.0,
                    "min_depth":           0.1,
                    "queue_size":          5,
                    "bilateral_filter":    True,
                    "edge_aware_filter":   True,
                    "worker_threads":      4,
                },
            ],
        ),
        # Point cloud — SD resolution (512×424)
        Node(
            package="depth_image_proc",
            executable="point_cloud_xyzrgb_node",
            name="points_xyzrgb_sd",
            remappings=[
                ("rgb/camera_info",            "sd/camera_info"),
                ("rgb/image_rect_color",        "sd/image_color_rect"),
                ("depth_registered/image_rect", "sd/image_depth_rect"),
                ("points",                      "sd/points"),
            ],
        ),
        # Point cloud — QHD resolution (960×540)
        Node(
            package="depth_image_proc",
            executable="point_cloud_xyzrgb_node",
            name="points_xyzrgb_qhd",
            remappings=[
                ("rgb/camera_info",            "qhd/camera_info"),
                ("rgb/image_rect_color",        "qhd/image_color_rect"),
                ("depth_registered/image_rect", "qhd/image_depth_rect"),
                ("points",                      "qhd/points"),
            ],
        ),
    ])

    # ------------------------------------------------------------------ #
    #  Camera 2 — Kinect v2 Bridge                                        #
    #  Serial resolved from YAML (kinect2_2 → 007425354147)              #
    # ------------------------------------------------------------------ #
    camera2_group = GroupAction([
        PushRosNamespace(camera2_namespace),
        Node(
            package="kinect2_bridge",
            executable="kinect2_bridge_node",
            name="kinect2_bridge",
            output="screen",
            parameters=[
                # Serial number resolved from YAML
                serials_yaml,
                {
                    "base_name":           camera2_namespace,
                    "publish_tf":          True,
                    "base_name_tf":        camera2_namespace,
                    "fps_limit":           30.0,
                    "use_png":             False,
                    "depth_method":        "default",
                    "reg_method":          "default",
                    "max_depth":           12.0,
                    "min_depth":           0.1,
                    "queue_size":          5,
                    "bilateral_filter":    True,
                    "edge_aware_filter":   True,
                    "worker_threads":      4,
                },
            ],
        ),
        Node(
            package="depth_image_proc",
            executable="point_cloud_xyzrgb_node",
            name="points_xyzrgb_sd",
            remappings=[
                ("rgb/camera_info",            "sd/camera_info"),
                ("rgb/image_rect_color",        "sd/image_color_rect"),
                ("depth_registered/image_rect", "sd/image_depth_rect"),
                ("points",                      "sd/points"),
            ],
        ),
        Node(
            package="depth_image_proc",
            executable="point_cloud_xyzrgb_node",
            name="points_xyzrgb_qhd",
            remappings=[
                ("rgb/camera_info",            "qhd/camera_info"),
                ("rgb/image_rect_color",        "qhd/image_color_rect"),
                ("depth_registered/image_rect", "qhd/image_depth_rect"),
                ("points",                      "qhd/points"),
            ],
        ),
    ])

    # ------------------------------------------------------------------ #
    #  Static TF publishers — positions from camera_config.yaml           #
    #                                                                      #
    #  camera1: x=3.72 y=1.18 z=0.706 roll=0 pitch=0 yaw=0              #
    #  camera2: x=3.72 y=1.18 z=0.706 roll=0 pitch=0 yaw=-0.5236        #
    #                                                                      #
    #  Both cameras publish transforms relative to the world_frame         #
    #  defined in camera_config.yaml (default: "map").                    #
    # ------------------------------------------------------------------ #
    camera1_tf = Node(
        package="tf2_ros",
        executable="static_transform_publisher",
        name="camera1_tf_publisher",
        arguments=[
            "--frame-id",    cam["world_frame"],
            "--child-frame-id", cam["cam1_frame"],
            "--x",     cam["cam1_x"],
            "--y",     cam["cam1_y"],
            "--z",     cam["cam1_z"],
            "--roll",  cam["cam1_roll"],
            "--pitch", cam["cam1_pitch"],
            "--yaw",   cam["cam1_yaw"],
        ],
        condition=IfCondition(publish_transforms),
    )

    camera2_tf = Node(
        package="tf2_ros",
        executable="static_transform_publisher",
        name="camera2_tf_publisher",
        arguments=[
            "--frame-id",    cam["world_frame"],
            "--child-frame-id", cam["cam2_frame"],
            "--x",     cam["cam2_x"],
            "--y",     cam["cam2_y"],
            "--z",     cam["cam2_z"],
            "--roll",  cam["cam2_roll"],
            "--pitch", cam["cam2_pitch"],
            "--yaw",   cam["cam2_yaw"],
        ],
        condition=IfCondition(publish_transforms),
    )

    # ------------------------------------------------------------------ #
    #  Assemble launch description                                         #
    # ------------------------------------------------------------------ #
    return LaunchDescription([
        camera1_namespace_arg,
        camera2_namespace_arg,
        publish_transforms_arg,
        camera1_group,
        camera2_group,
        camera1_tf,
        camera2_tf,
    ])
