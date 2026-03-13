from setuptools import setup
from glob import glob
import os

package_name = "ros2_ws"
pkg = package_name

setup(
    name=package_name,
    version="0.0.1",
    packages=[package_name],
    data_files=[
        ("share/ament_index/resource_index/packages", [f"resource/{pkg}"]),
        (f"share/{pkg}", ["package.xml"]),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="omar",
    maintainer_email="oali@students.lincoln.ac.uk",
    description="Cookie Cutter Ros2 ws",
    license="",
    entry_points={
        "console_scripts": [
            # f"data_loader_node.py = {pkg}.data_loader_node:main",
            # f"detect_sheep.py = {pkg}.detect_sheep:main",
        ],
    },
)
