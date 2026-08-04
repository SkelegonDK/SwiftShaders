#!/bin/bash
# Compiles every .metal file in Sources/SwiftShaders/Metal into a single
# default.metallib placed in the target's Resources directory.
#
# SwiftPM's command-line build does not compile .metal files, so this has to
# run before `swift build` / `swift run`. `make gallery` does it for you.
set -euo pipefail

cd "$(dirname "$0")/.."

METAL_DIR="Sources/SwiftShaders/Metal"
OUT_DIR="Sources/SwiftShaders/Resources"
AIR_DIR="$(mktemp -d)"
trap 'rm -rf "$AIR_DIR"' EXIT

mkdir -p "$OUT_DIR"

count=0
for f in "$METAL_DIR"/*.metal; do
    xcrun -sdk macosx metal \
        -frecord-sources \
        -c "$f" \
        -o "$AIR_DIR/$(basename "$f" .metal).air"
    count=$((count + 1))
done

xcrun -sdk macosx metallib "$AIR_DIR"/*.air -o "$OUT_DIR/default.metallib"

echo "Compiled $count shaders -> $OUT_DIR/default.metallib"
