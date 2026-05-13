#!/usr/bin/env bash

set -euo pipefail

duration_seconds="${1:-60}"
timestamp="$(date +%Y%m%d_%H%M%S)"
output_root="${ROSBAG_DIR:-$HOME/rosbags}"
output_dir="${output_root}/kinect_bag_compare_${timestamp}"
uncompressed_bag="${output_dir}/uncompressed"
compressed_bag="${output_dir}/compressed"

# Common topics for fair comparison (same data, different formats)
topics_common=(
  /kinect2_1/qhd/camera_info
  /kinect2_1/qhd/points
  /kinect2_1/sd/image_ir_rect
  /kinect2_2/qhd/camera_info
  /kinect2_2/qhd/points
  /kinect2_2/sd/image_ir_rect
  /tf
  /tf_static
)

# Uncompressed: original image topics
topics_uncompressed=(
  "${topics_common[@]}"
  /kinect2_1/qhd/image_color_rect
  /kinect2_1/qhd/image_depth_rect
  /kinect2_1/sd/image_ir
  /kinect2_2/qhd/image_color_rect
  /kinect2_2/qhd/image_depth_rect
  /kinect2_2/sd/image_ir
)

# Compressed: compressed image topics (same metadata, but compressed payloads)
topics_compressed=(
  "${topics_common[@]}"
  /kinect2_1/qhd/image_color_rect/compressed
  /kinect2_1/qhd/image_depth_rect/compressed
  /kinect2_1/sd/image_ir/compressed
  /kinect2_2/qhd/image_color_rect/compressed
  /kinect2_2/qhd/image_depth_rect/compressed
  /kinect2_2/sd/image_ir/compressed
)

mkdir -p "$output_dir"

cleanup() {
  local exit_code="$?"

  if [[ -n "${uncompressed_pid:-}" ]] && kill -0 "$uncompressed_pid" 2>/dev/null; then
    kill -INT "$uncompressed_pid" 2>/dev/null || true
    wait "$uncompressed_pid" 2>/dev/null || true
  fi

  if [[ -n "${compressed_pid:-}" ]] && kill -0 "$compressed_pid" 2>/dev/null; then
    kill -INT "$compressed_pid" 2>/dev/null || true
    wait "$compressed_pid" 2>/dev/null || true
  fi

  if [[ $exit_code -ne 0 ]]; then
    echo "Recording stopped early with exit code $exit_code." >&2
  fi
}

trap cleanup EXIT INT TERM

echo "Recording for ${duration_seconds}s into:"
echo "  uncompressed: ${uncompressed_bag}"
echo "  compressed:   ${compressed_bag}"
echo ""
echo "Both bags record the same topics, but images are:"
echo "  uncompressed: /qhd/image_* and /sd/image_* (raw sensor data)"
echo "  compressed:   /qhd/image_*/compressed and /sd/image_*/compressed (H.264/JPEG encoded)"
echo ""

ros2 bag record -o "$uncompressed_bag" "${topics_uncompressed[@]}" >"${output_dir}/uncompressed.log" 2>&1 &
uncompressed_pid="$!"

ros2 bag record -o "$compressed_bag" "${topics_compressed[@]}" >"${output_dir}/compressed.log" 2>&1 &
compressed_pid="$!"

sleep "$duration_seconds"

kill -INT "$uncompressed_pid" "$compressed_pid" 2>/dev/null || true
wait "$uncompressed_pid" 2>/dev/null || true
wait "$compressed_pid" 2>/dev/null || true

trap - EXIT INT TERM

echo
echo "Bag size report"
echo "---------------"
du -sh "$uncompressed_bag" "$compressed_bag"

uncompressed_size_bytes="$(du -sb "$uncompressed_bag" | awk '{print $1}')"
compressed_size_bytes="$(du -sb "$compressed_bag" | awk '{print $1}')"

if [[ "$compressed_size_bytes" -gt 0 ]]; then
  savings_percent="$(awk -v u="$uncompressed_size_bytes" -v c="$compressed_size_bytes" 'BEGIN { printf "%.1f", (1 - (c / u)) * 100 }')"
  ratio="$(awk -v u="$uncompressed_size_bytes" -v c="$compressed_size_bytes" 'BEGIN { printf "%.2f", u / c }')"
  echo "Uncompressed bytes: ${uncompressed_size_bytes}"
  echo "Compressed bytes:   ${compressed_size_bytes}"
  echo "Size reduction:     ${savings_percent}%"
  echo "Uncompressed/compressed ratio: ${ratio}x"
fi

echo
echo "Topic summary"
echo "-------------"
printf 'Uncompressed topics (%d):\n' "${#topics_uncompressed[@]}"
printf '  %s\n' "${topics_uncompressed[@]}"
printf '\nCompressed topics (%d):\n' "${#topics_compressed[@]}"
printf '  %s\n' "${topics_compressed[@]}"

echo
echo "Next steps"
echo "----------"
echo "Analyze topic sizes with:"
echo "  python3 \$HOME/bash_scripts/report_bag_topic_size.py ${uncompressed_bag}"
echo "  python3 \$HOME/bash_scripts/report_bag_topic_size.py ${compressed_bag}"
echo ""
echo "Logs"
echo "----"
echo "  ${output_dir}/uncompressed.log"
echo "  ${output_dir}/compressed.log"
