#!/bin/sh

# Get a tag, based off of the current Git commit hash.
TAG_LONG=$(CI/Common/GetTagLong.sh)
# Get a tag, for the current "latest" image.
TAG_LONG_LATEST="$(CI/Common/GetTagLongLatest.sh)"

# Log debug info.
echo "Deploying Docker image  and $TAG_LONG_LATEST."

CI/Common/Login.sh

echo "Loading Docker image artifact."
# Load the built Docker image from the build directory.
docker load --input Build/"$(CI/Common/GetTagShort.sh)".tar
echo "Pushing Docker image for architecture \"$TARGET_ARCH\" to \"$TAG_LONG\"."
# Push the Docker image to the registry.
docker push "$TAG_LONG"
echo "Tagging Docker image \"$TAG_LONG\" as \"$TAG_LONG_LATEST\"."
# Tag the Docker image as the latest image.
docker tag "$TAG_LONG" "$TAG_LONG_LATEST"
echo "Pushing Docker image for architecture \"$TARGET_ARCH\" to \"$TAG_LONG_LATEST\" (Latest)."
# Push the latest tag to the registry.
docker push "$TAG_LONG_LATEST"
# If a Git tag is present.
if [ -n "$CI_COMMIT_TAG" ]; then
  TAG_LONG_STABLE=$CI_REGISTRY_IMAGE/$TARGET_ARCH:stable
  echo "Tagging Docker image \"$TAG_LONG\" as \"$TAG_LONG_STABLE\"."
  # Tag the Docker image as the latest stable image.
  docker tag "$TAG_LONG" "$TAG_LONG_STABLE"
  echo "Pushing Docker image for architecture \"$TARGET_ARCH\" to \"$TAG_LONG_LATEST\" (Stable)."
  # Push the stable tag to the registry.
  docker push "$TAG_LONG_STABLE"
fi
