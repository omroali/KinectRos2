# Copyright 2019 Open Source Robotics Foundation, Inc.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials provided
#    with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

"""Launch the velodyne driver, pointcloud, and laserscan nodes with default configuration."""

import os

import ament_index_python.packages
import yaml
from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument,
    EmitEvent,
    RegisterEventHandler,
)
from launch.event_handlers import OnProcessExit
from launch.events import Shutdown
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    # --- Launch arguments (override YAML defaults) ---
    device_ip_arg = DeclareLaunchArgument(
        "device_ip",
        default_value="192.168.1.201",
        description="IP address of the Velodyne LiDAR",
    )
    port_arg = DeclareLaunchArgument(
        "port", default_value="2368", description="UDP port of the Velodyne LiDAR"
    )
    frame_id_arg = DeclareLaunchArgument(
        "frame_id", default_value="map", description="TF frame ID for the point cloud"
    )
    rpm_arg = DeclareLaunchArgument(
        "rpm", default_value="600.0", description="Velodyne rotation speed (RPM)"
    )

    # --- Driver node ---
    driver_share_dir = ament_index_python.packages.get_package_share_directory(
        "velodyne_driver"
    )
    driver_params_file = os.path.join(
        driver_share_dir, "config", "VLP16-velodyne_driver_node-params.yaml"
    )

    velodyne_driver_node = Node(
        package="velodyne_driver",
        executable="velodyne_driver_node",
        output="both",
        parameters=[
            driver_params_file,
            {
                "device_ip": LaunchConfiguration("device_ip"),
                "port": LaunchConfiguration("port"),
                "frame_id": LaunchConfiguration("frame_id"),
                "rpm": LaunchConfiguration("rpm"),
            },
        ],
    )

    # --- Transform / pointcloud node ---
    convert_share_dir = ament_index_python.packages.get_package_share_directory(
        "velodyne_pointcloud"
    )
    convert_params_file = os.path.join(
        convert_share_dir, "config", "VLP16-velodyne_transform_node-params.yaml"
    )

    with open(convert_params_file, "r") as f:
        convert_params = yaml.safe_load(f)["velodyne_transform_node"]["ros__parameters"]

    convert_params["calibration"] = os.path.join(
        convert_share_dir, "params", "VLP16db.yaml"
    )
    velodyne_transform_node = Node(
        package="velodyne_pointcloud",
        executable="velodyne_transform_node",
        output="both",
        parameters=[convert_params],
    )

    # --- Laserscan node ---
    laserscan_share_dir = ament_index_python.packages.get_package_share_directory(
        "velodyne_laserscan"
    )
    laserscan_params_file = os.path.join(
        laserscan_share_dir, "config", "default-velodyne_laserscan_node-params.yaml"
    )
    velodyne_laserscan_node = Node(
        package="velodyne_laserscan",
        executable="velodyne_laserscan_node",
        output="both",
        parameters=[laserscan_params_file],
    )

    return LaunchDescription(
        [
            device_ip_arg,
            port_arg,
            frame_id_arg,
            rpm_arg,
            velodyne_driver_node,
            velodyne_transform_node,
            velodyne_laserscan_node,
            RegisterEventHandler(
                event_handler=OnProcessExit(
                    target_action=velodyne_driver_node,
                    on_exit=[EmitEvent(event=Shutdown())],
                )
            ),
        ]
    )
