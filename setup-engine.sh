#!/bin/bash
# setup-engine.sh — builds the latest llama-server from source into ./bin/
# Run once before ./start-engine.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
BUILD_DIR="/tmp/llama-cpp-build"
TAG="b8664"   # known Gemma 4-compatible release; update as needed
SOURCE_URL="https://github.com/ggml-org/llama.cpp/archive/refs/tags/${TAG}.tar.gz"

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│        llama.cpp Setup · Build from Source          │"
echo "└─────────────────────────────────────────────────────┘"
echo "  Tag    : $TAG"
echo "  Build  : $BUILD_DIR"
echo "  Output : $BIN_DIR/llama-server"
echo ""

# Check deps
for cmd in curl cmake make g++ tar; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[error] '$cmd' is required but not found."
        exit 1
    fi
done

mkdir -p "$BIN_DIR" "$BUILD_DIR"

# Download source
echo "  [fetch] Downloading llama.cpp $TAG source..."
curl -L --progress-bar "$SOURCE_URL" | tar -xz -C "$BUILD_DIR" --strip-components=1

# Build — only the server target, with native CPU optimisations
echo ""
echo "  [build] Configuring with cmake..."
cmake -S "$BUILD_DIR" -B "$BUILD_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_NATIVE=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    2>&1 | tail -5

echo "  [build] Compiling llama-server (this takes ~5 min)..."
cmake --build "$BUILD_DIR/build" --target llama-server -j"$(nproc)" 2>&1 | tail -10

# Install
cp "$BUILD_DIR/build/bin/llama-server" "$BIN_DIR/llama-server"
chmod +x "$BIN_DIR/llama-server"

# Cleanup
rm -rf "$BUILD_DIR"

# Verify
echo ""
VER=$("$BIN_DIR/llama-server" --version 2>&1 | head -1)
echo "  ✓ llama-server installed to ./bin/llama-server"
echo "  ✓ Version: $VER"
echo ""
echo "  Run the engine:"
echo "    ./start-engine.sh --cpu"
echo "    ./start-engine.sh --gpu   (if you have a GPU)"
echo ""
