#!/bin/sh

# Get a tag for the current "latest" image.
tag_long_latest="$(CI/Common/GetTagLongLatest.sh)"
# Get a full tag including the GitLab Registry URL. This will either end in a commit hash, or tag.
tag_long=$(CI/Common/GetTagLong.sh)
# Get a short tag without the registry URL, for saving the image to a local archive.
tag_short=$(CI/Common/GetTagShort.sh)

echo "Making artifact directory."
# Make a directory to save the built image to, as an artifact.
mkdir Build

echo "Logging into GitLab Container Registry."
# Log into the GitLab Container Registry.
CI/Common/Login.sh

# Builds and saves an image for a given VM.
# Arguments:
# - The JVM to build, with a correlating Dockerfile.
build() {
  vm=$1
  vm_tag_long_latest="$tag_long_latest"-"$vm"
  vm_tag_long="$tag_long"-"$vm"
  vm_tag_short="$tag_short"-"$vm"

  echo "Pulling latest image \"$vm_tag_long_latest\" to use as cache."
  # Pull the last built Docker image to use as a cache. This may fail.
  docker pull "$vm_tag_long_latest" || true

  echo "Building image for $TARGET_ARCH as \"$vm_tag_long\"."
  # Build Docker images for the target architecture.
  docker build --build-arg --cache-from "$vm_tag_long_latest" \
    -t "$vm_tag_long" -f Dockerfile.openjdk."$vm" .

  image_path=Build/"$vm_tag_short".tar
  echo "Saving image to \"$image_path\"."
  # Save the built Docker image to the build directory.
  docker save --output "$image_path" "$vm_tag_long"
}

echo "Building YAMDI with Hotspot VM."
build hotspot
echo "Building YAMDI with OpenJ9 VM."
build openj9
