#!/bin/sh
# build-hidp.sh — Cross-compile hidp.ko for reMarkable Paper Pro
#
# Runs on Mac (or any Docker host). Builds inside an x86_64 container
# using the official reMarkable SDK + kernel source.
#
# Prerequisites in this directory:
#   toolchain.sh          — reMarkable SDK installer (~464MB)
#   Module.symvers        — Device-extracted symbol CRCs
#   linux-imx-rm/         — Kernel source repo (with extracted tarball)
#   Dockerfile.hidp       — Docker build file
#
# Output: output/hidp.ko
#
# Usage: ./build-hidp.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Verify prerequisites
missing=""
[ ! -f toolchain.sh ]    && missing="$missing toolchain.sh"
[ ! -f Module.symvers ]  && missing="$missing Module.symvers"
[ ! -f Dockerfile.hidp ] && missing="$missing Dockerfile.hidp"
[ ! -d linux-imx-rm/linux-imx-rel-5.5-uscg-3.25.1.1-95c3acd37afa ] && missing="$missing linux-imx-rm/kernel-source"
if [ -n "$missing" ]; then
    echo "ERROR: Missing prerequisites:$missing" >&2
    echo "See cross-compilation.md in project memory for setup instructions." >&2
    exit 1
fi

echo "Building hidp.ko (this takes a while under x86_64 emulation)..."

# Build the Docker image
docker build \
    --platform linux/amd64 \
    -f Dockerfile.hidp \
    -t remarkable-hidp \
    .

# Extract hidp.ko from the image
mkdir -p output
docker run --rm \
    --platform linux/amd64 \
    -v "$SCRIPT_DIR/output:/output" \
    remarkable-hidp

# Verify output
if [ ! -f output/hidp.ko ]; then
    echo "ERROR: Build succeeded but hidp.ko not found in output/" >&2
    exit 1
fi

echo ""
echo "Build complete: output/hidp.ko"
file output/hidp.ko
echo ""
echo "Next step: ./install-hidp.sh [device-ip]"
