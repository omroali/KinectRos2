import os
from typing import List, Tuple

import yaml


DEFAULT_STREAMS = {
    "color":      {"enabled": True, "mode": "compressed", "fps": 30},
    "infrared_1": {"enabled": True, "mode": "raw",        "fps": 30},
    "infrared_2": {"enabled": True, "mode": "raw",        "fps": 30},
    "depth":      {"enabled": True},
}

# Per-stream topic naming. "raw" subscribes to <prefix><suffix>/image (with a
# remap to the bare <prefix><suffix> source topic). "compressed" subscribes to
# the camera's pre-encoded JPEG topic. Only color supports compressed mode;
# IR/depth don't have compressed equivalents on the D555.
_STREAM_SUFFIX = {
    "color":      {"raw": "_Color", "compressed": "_CompressedColor"},
    "infrared_1": {"raw": "_Infrared_1"},
    "infrared_2": {"raw": "_Infrared_2"},
}


def load_config(config_file: str) -> dict:
    if not config_file or not os.path.exists(config_file):
        raise FileNotFoundError(f"Config file not found: {config_file}")
    with open(config_file, "r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def selected_cameras(config_file: str) -> Tuple[str, List[dict]]:
    config = load_config(config_file)
    cameras = config.get("cameras", {}) or {}

    selected = []
    for name, camera in cameras.items():
        if not isinstance(camera, dict):
            continue
        if not camera.get("record", False):
            continue
        camera_copy = dict(camera)
        camera_copy["name"] = name
        selected.append(camera_copy)

    world_frame = config.get("world_frame", "map")
    return world_frame, selected


def resolve_streams_config(user_streams: dict | None) -> dict:
    """Merge user-provided stream config with defaults."""
    resolved = {}
    user_streams = user_streams or {}
    for name, defaults in DEFAULT_STREAMS.items():
        merged = dict(defaults)
        merged.update(user_streams.get(name, {}) or {})
        resolved[name] = merged
    return resolved


def _topic_prefix(camera: dict) -> str:
    serial = camera.get("serial")
    if not serial:
        raise ValueError(f"Camera {camera.get('name', '<unknown>')} missing serial")
    return f"/realsense/D555_{serial}"


def build_recording_setup(cameras: List[dict], user_streams: dict | None) -> dict:
    """Build the parameter shape that recording_manager expects.

    Returns a dict with five string-array fields:
      color_topics            - raw Image topics (subscribed by colour_video_recorder)
      color_remaps            - ros2-style remaps from <topic>/image to the source topic
      color_compressed_topics - CompressedImage topics
      topic_fps_overrides     - "<topic>:<fps>" entries for per-stream subsampling
      bag_topics              - everything ros2 bag record should subscribe to
    """
    streams = resolve_streams_config(user_streams)
    raw_topics: List[str] = []
    raw_remaps: List[str] = []
    compressed_topics: List[str] = []
    fps_overrides: List[str] = []
    bag_topics: List[str] = []

    for camera in cameras:
        prefix = _topic_prefix(camera)

        for stream_name in ("color", "infrared_1", "infrared_2"):
            cfg = streams[stream_name]
            if not cfg.get("enabled", True):
                continue
            mode = cfg.get("mode", "raw")
            suffix_map = _STREAM_SUFFIX[stream_name]
            if mode not in suffix_map:
                raise ValueError(
                    f"Stream '{stream_name}' does not support mode '{mode}'. "
                    f"Allowed modes for this stream: {sorted(suffix_map)}"
                )

            fps = cfg.get("fps")

            if mode == "compressed":
                topic = f"{prefix}{suffix_map['compressed']}"
                compressed_topics.append(topic)
                if fps:
                    fps_overrides.append(f"{topic}:{fps}")
                raw_suffix = suffix_map.get("raw")
                if raw_suffix:
                    bag_topics += [
                        f"{prefix}{raw_suffix}/camera_info",
                        f"{prefix}{raw_suffix}/metadata",
                    ]
            else:
                source = f"{prefix}{suffix_map['raw']}"
                sub = f"{source}/image"
                raw_topics.append(sub)
                raw_remaps.append(f"{sub}:={source}")
                if fps:
                    fps_overrides.append(f"{sub}:{fps}")
                bag_topics += [f"{source}/camera_info", f"{source}/metadata"]

        if streams["depth"].get("enabled", True):
            bag_topics += [
                f"{prefix}_Depth",
                f"{prefix}_Depth/camera_info",
                f"{prefix}_Depth/metadata",
            ]

    return {
        "color_topics": raw_topics,
        "color_remaps": raw_remaps,
        "color_compressed_topics": compressed_topics,
        "topic_fps_overrides": fps_overrides,
        "bag_topics": bag_topics,
    }
