from setuptools import find_packages, setup

package_name = "session_recorder"

setup(
    name=package_name,
    version="0.1.0",
    packages=find_packages(exclude=("test",)),
    data_files=[
        ("share/ament_index/resource_index/packages", [f"resource/{package_name}"]),
        (f"share/{package_name}", ["package.xml"]),
        (f"share/{package_name}/launch", ["launch/unified_recording.launch.py"]),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="oali",
    maintainer_email="oali@example.com",
    description="Unified service-driven recording manager for all sensors.",
    license="Apache-2.0",
    entry_points={
        "console_scripts": [
            "colour_video_recorder = session_recorder.colour_video_recorder:main",
            "recording_manager = session_recorder.recording_manager:main",
            "video_to_image_publisher = session_recorder.video_to_image_publisher:main",
        ],
    },
)
