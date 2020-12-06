#!/bin/sh

# shellcheck source=CI/common.sh
. CI/common.sh

tag=$(get_tag)
tag_full=$(get_tag_full)
tag_full_latest=$(get_tag_full_latest)

_echo "Making artifact directory."
mkdir Build

_echo "Logging into GitLab Container Registry."
login

# Builds and saves an image with a given VM.
# Arguments:
#   - The JVM to build with, with a correlating Dockerfile.
# Variables Read:
#   - TARGET_ARCH: See get_tag().
build() {
  vm=$1
  tag_short_vm=$tag-$vm
  tag_full_vm=$tag_full-$vm
  tag_full_latest_vm=$tag_full_latest-$vm

  image_path=Build/$tag_short_vm.tar

  _echo "Pulling latest image \"$tag_full_latest_vm\" to use as cache."
  docker pull "$tag_full_latest_vm" || true

  _echo "Building image for $TARGET_ARCH as \"$tag_full_vm\"."
  docker build --cache-from "$tag_full_latest_vm" -t "$tag_full_vm" -f Dockerfile.openjdk."$vm" .

  _echo "Saving image to \"$image_path\"."
  docker save --output "$image_path" "$tag_full_vm"
}

_echo "Building with Hotspot VM."
build hotspot
_echo "Building with OpenJ9 VM."
build openj9
