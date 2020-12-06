#!/bin/sh

tag=$(get_tag)
tag_full=$(get_tag_full)
tag_full_latest=$(get_tag_full_latest)
tag_full_stable=$(get_tag_full_stable)

_echo "Logging into GitLab Container Registry."
login

# Deploys an image for a given VM.
# Arguments:
# - The JVM to deploy, with a correlating image.
deploy() {
  vm=$1
  tag_short_vm=$tag-$vm
  tag_full_vm=$tag_full-$vm
  tag_full_latest_vm=$tag_full_latest-$vm
  tag_full_stable_vm=$tag_full_stable-$vm

  image_path=Build/$tag_short_vm.tar

  _echo "Loading image from \"$image_path\"."
  docker load --input "$image_path"

  _echo "Tagging image as \"latest\", \"$tag_full_latest_vm\"."
  docker tag "$tag_full_vm" "$tag_full_latest_vm"

  # If this is the Hotspot VM.
  if [ "$vm" = hotspot ]; then
    _echo "Tagging this Hotspot image as the default for this commit/tag, \"$tag_full\"."
    docker tag "$tag_full_vm" "$tag_full"

    _echo "Tagging this Hotspot image as the default \"latest\", \"$tag_full_latest\"."
    docker tag "$tag_full_vm" "$tag_full_latest"
  fi

  # If a Git tag is present.
  if [ -n "$CI_COMMIT_TAG" ]; then
    _echo "Tagging image as \"stable\", \"$tag_full_stable_vm\"."
    docker tag "$tag_full_vm" "$tag_full_stable_vm"

    if [ "$vm" = hotspot ]; then
      _echo "Tagging this Hotspot image as the default \"stable\", \"$tag_full_stable\"."
      docker tag "$tag_full_vm" "$tag_full_stable"
    fi
  fi

  _echo "Pushing Docker image for \"$TARGET_ARCH\" to \"$tag_full_vm\"."
  docker push "$tag_full_vm"
}

_echo "Deploying YAMDI with Hotspot VM."
deploy hotspot
_echo "Deploying YAMDI with OpenJ9 VM."
deploy openj9
