#!/bin/zsh
set -euo pipefail

# Usage: ./generate_icons.sh <source_image> [appiconset_dir]
# Default appiconset_dir points to the TrainPlanner iOS target's AppIcon.appiconset

SRC_PATH=${1:-}
if [[ -z "$SRC_PATH" || ! -f "$SRC_PATH" ]]; then
  echo "[x] 请提供源图路径，例如: ./generate_icons.sh ~/Desktop/icon-src.png" >&2
  exit 1
fi

DEFAULT_SET_DIR="$(cd "$(dirname "$0")"/..; pwd)/TrainPlanner/Assets.xcassets/AppIcon.appiconset"
SET_DIR=${2:-$DEFAULT_SET_DIR}
mkdir -p "$SET_DIR"

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR" >/dev/null 2>&1 || true; }
trap cleanup EXIT

BASE_1024="$TMP_DIR/base-1024.png"

# 放大到 1024×1024，保持居中裁切
sips -s format png "$SRC_PATH" --resampleWidth 1024 --out "$BASE_1024" >/dev/null
sips -z 1024 1024 "$BASE_1024" --out "$BASE_1024" >/dev/null

typeset -a specs
specs=(
  # idiom size scale px filename
  "iphone 20x20 2x 40 icon-40.png"
  "iphone 20x20 3x 60 icon-60.png"
  "iphone 29x29 2x 58 icon-58.png"
  "iphone 29x29 3x 87 icon-87.png"
  "iphone 40x40 2x 80 icon-80.png"
  "iphone 40x40 3x 120 icon-120.png"
  "iphone 60x60 2x 120 icon-120_iphone.png"
  "iphone 60x60 3x 180 icon-180.png"

  "ipad 20x20 1x 20 icon-20-ipad.png"
  "ipad 20x20 2x 40 icon-40-ipad.png"
  "ipad 29x29 1x 29 icon-29-ipad.png"
  "ipad 29x29 2x 58 icon-58-ipad.png"
  "ipad 40x40 1x 40 icon-40x40-ipad.png"
  "ipad 40x40 2x 80 icon-80-ipad.png"
  "ipad 76x76 1x 76 icon-76.png"
  "ipad 76x76 2x 152 icon-152.png"
  "ipad 83.5x83.5 2x 167 icon-167.png"

  "ios-marketing 1024x1024 1x 1024 icon-1024.png"
)

json_images=()

for entry in ${(f)specs}; do
  parts=(${=entry})
  idiom=${parts[1]}
  size=${parts[2]}
  scale=${parts[3]}
  px=${parts[4]}
  filename=${parts[5]}

  out="$SET_DIR/$filename"
  sips -s format png "$BASE_1024" --resampleWidth $px --out "$out" >/dev/null
  json_images+="{\"idiom\":\"$idiom\",\"size\":\"$size\",\"scale\":\"$scale\",\"filename\":\"$filename\"}"
done

# 生成 Contents.json
json_joined=$(printf ",%s" ${json_images[@]})
json_joined=${json_joined:1}
cat > "$SET_DIR/Contents.json" <<JSON
{
  "images": [
    $json_joined
  ],
  "info": { "version": 1, "author": "xcode" }
}
JSON

echo "✅ 已生成并写入 $SET_DIR"


