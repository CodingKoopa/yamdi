#!/bin/bash

# Get a tag, based off of the current Git commit hash.
TAG_LONG=$(CI/Common/GetTagLong.sh)
# Get a tag, for the current "latest" image.
TAG_LONG_LATEST="$(CI/Common/GetTagLongLatest.sh)"

CI/Common/Login.sh

echo "Pulling latest image \"$TAG_LONG_LATEST\" to use as cache."
# Pull the last built Docker image to use as a cache. This may fail.
docker pull "$TAG_LONG_LATEST" || true
echo "Building Docker image for architecture \"$TARGET_ARCH\", as \"$TAG_LONG\"."
# Build Docker images for the target architecture.
docker build --build-arg TARGET_ARCH="$TARGET_ARCH" --cache-from "$TAG_LONG_LATEST" \
  -t "$TAG_LONG-hotspot" -f Dockerfile.openjdk.hotspot .
docker build --build-arg TARGET_ARCH="$TARGET_ARCH" --cache-from "$TAG_LONG_LATEST" \
  -t "$TAG_LONG-openj9" -f Dockerfile.openjdk.openj9 .
echo "Making artifact directory."
# Make a directory to save the built image to, as an artifact.
mkdir Build
echo "Saving Docker images as artifact."
# Save the built Docker image to the build directory.
docker save --output Build/"$(CI/Common/GetTagShort.sh)"-hotspot.tar "$TAG_LONG"
docker save --output Build/"$(CI/Common/GetTagShort.sh)"-openj9.tar "$TAG_LONG"
