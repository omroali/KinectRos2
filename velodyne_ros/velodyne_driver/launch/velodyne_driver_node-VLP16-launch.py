# Copyright 2019 Open Source Robotics Foundation, Inc.
# All rights reserved.
#
# Software License Agreement (BSD License 2.0)
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above
#   copyright notice, this list of conditions and the following
#   disclaimer in the documentation and/or other materials provided
#   with the distribution.
# * Neither the name of {copyright_holder} nor the names of its
#   contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
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

"""Launch the velodyne driver node with default configuration."""

import os

import ament_index_python.packages
import launch
import launch_ros.actions


def generate_launch_description():
    config_directory = os.path.join(
        ament_index_python.packages.get_package_share_directory('velodyne_driver'),
        'config')
    params = os.path.join(config_directory, 'VLP16-velodyne_driver_node-params.yaml')
    tf_config_path = os.path.join(config_directory, 'velodyne_tf.yaml')

    with open(tf_config_path, 'r') as f:
        tf_config = yaml.safe_load(f)
        tf_params = tf_config['/**']['ros_parameters']

    velodyne_driver_node = launch_ros.actions.Node(package='velodyne_driver',
                                                   executable='velodyne_driver_node',
                                                   output='both',
                                                   parameters=[params])

    map_to_base_link = launch_ros.actions.Node(
        package='tf_ros',
        executable='static_transformer_publisher',
        name='map_to_base_link',
        arguments=['0.0', '0.0', '0.0', '0.0', '0.0', '0.0', 'map', 'base_link']
    )

    base_link_to_velodyne = launch_ros.actions.Node(
        package='tf_ros',
        executable='static_transformer_publisher',
        name='base_link_to_velodyne',
        arguments=[
            str(tf_params['x']),
            str(tf_params['y']),
            str(tf_params['z']),
            str(tf_params['roll']),
            str(tf_params['pitch']),
            str(tf_params['yaw']),
            tf_params['parent_frame'],
            tf_params['child_frame'],

        ]
    )
    return launch.LaunchDescription([
        velodyne_driver_node,
        map_to_base_link,
        base_link_to_velodyne,
         launch.actions.RegisterEventHandler(
             event_handler=launch.event_handlers.OnProcessExit(
                 target_action=velodyne_driver_node,
                 on_exit=[launch.actions.EmitEvent(
                     event=launch.events.Shutdown())],
             )),
         ])
