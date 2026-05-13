#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import re
from collections import defaultdict
from pathlib import Path
from typing import Dict

try:
    from rosbag2_py import ConverterOptions, SequentialReader, StorageOptions
except ImportError as exc:  # pragma: no cover - handled at runtime
    raise SystemExit(
        "rosbag2_py is not available in this Python environment. "
        "Run this inside a ROS 2 shell/container where rosbag2 is installed."
    ) from exc


CAMERA_RE = re.compile(r"^/kinect2_(\d+)/")


def human_bytes(value: int) -> str:
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    size = float(value)
    for unit in units:
        if size < 1024.0 or unit == units[-1]:
            return f"{size:.2f} {unit}"
        size /= 1024.0
    return f"{size:.2f} TiB"


def detect_bag_uri(path_text: str) -> str:
    path = Path(path_text).expanduser().resolve()
    if path.is_dir():
        return str(path)
    return str(path.parent)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Report per-topic and per-camera serialized message sizes from a ROS 2 bag"
    )
    parser.add_argument("bag_path", help="Path to the bag directory (or any file inside the bag directory)")
    parser.add_argument(
        "--storage-id",
        default="mcap",
        help="rosbag2 storage id to use when opening the bag (default: mcap)",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=0,
        help="Show only the top N topics by bytes, sorted descending (0 shows all)",
    )
    args = parser.parse_args()

    bag_uri = detect_bag_uri(args.bag_path)
    reader = SequentialReader()
    reader.open(
        StorageOptions(uri=bag_uri, storage_id=args.storage_id),
        ConverterOptions(input_serialization_format="", output_serialization_format=""),
    )

    per_topic_bytes: Dict[str, int] = defaultdict(int)
    per_topic_messages: Dict[str, int] = defaultdict(int)
    per_camera_bytes: Dict[str, int] = defaultdict(int)
    total_bytes = 0
    total_messages = 0

    while reader.has_next():
        topic, data, _timestamp = reader.read_next()
        message_size = len(data)
        per_topic_bytes[topic] += message_size
        per_topic_messages[topic] += 1
        total_bytes += message_size
        total_messages += 1

        match = CAMERA_RE.match(topic)
        if match:
            per_camera_bytes[f"kinect2_{match.group(1)}"] += message_size
        elif topic in {"/tf", "/tf_static"}:
            per_camera_bytes["transforms"] += message_size

    topics = sorted(per_topic_bytes.items(), key=lambda item: item[1], reverse=True)
    if args.top and args.top > 0:
        topics = topics[: args.top]

    print(f"Bag: {bag_uri}")
    print(f"Storage: {args.storage_id}")
    print(f"Total serialized message bytes: {total_bytes} ({human_bytes(total_bytes)})")
    print(f"Total messages: {total_messages}")
    print()
    print("Per-topic size")
    print("--------------")
    for topic, size_bytes in topics:
        message_count = per_topic_messages[topic]
        print(f"{human_bytes(size_bytes):>12}  {size_bytes:>12} B  {message_count:>8} msgs  {topic}")

    print()
    print("Per-camera summary")
    print("------------------")
    for camera, size_bytes in sorted(per_camera_bytes.items(), key=lambda item: item[0]):
        print(f"{camera:>12}  {human_bytes(size_bytes):>12}  {size_bytes:>12} B")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
