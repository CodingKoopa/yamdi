#!/bin/sh

# Get a tag, based off of the current Git commit hash.
TAG_LONG=$(CI/Common/GetTagLong.sh)
# Get a tag, for the current "latest" image.
TAG_LONG_LATEST="$(CI/Common/GetTagLongLatest.sh)"

CI/Common/Login.sh

echo "Pulling latest image \"$TAG_LONG_LATEST\" to use as cache."
# Pull the last built Docker image to use as a cache. This may fail.
docker pull "$TAG_LONG_LATEST" || true
echo "Building Docker image for architecture \"$TARGET_ARCH\", as \"$TAG_LONG\"."
# Build a Docker image for the target architecture.
docker build --build-arg TARGET_ARCH="$TARGET_ARCH" --cache-from "$TAG_LONG_LATEST" -t "$TAG_LONG" .
echo "Making artifact directory."
# Make a directory to save the built image to, as an artifact.
mkdir Build
echo "Saving Docker image as artifact."
# Save the built Docker image to the build directory.
docker save --output "Build/$(CI/Common/GetTagShort.sh).tar" "$TAG_LONG"
