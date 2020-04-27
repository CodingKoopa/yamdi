#!/bin/sh

# Get a tag for the current "latest" image.
tag_long_latest="$(CI/Common/GetTagLongLatest.sh)"
# Get a full tag including the GitLab Registry URL. This will either end in a commit hash, or tag.
tag_long=$(CI/Common/GetTagLong.sh)
# Get a short tag without the registry URL, for saving the image to a local archive.
tag_short=$(CI/Common/GetTagShort.sh)

echo "Logging into GitLab Container Registry."
# Log into the GitLab Container Registry.
CI/Common/Login.sh

# Deploys an image for a given VM.
# Arguments:
# - The JVM to deploy, with a correlating image.
deploy() {
  vm=$1
  vm_tag_long_latest="$tag_long_latest"-"$vm"
  vm_tag_long="$tag_long"-"$vm"
  vm_tag_short="$tag_short"-"$vm"

  image_path=Build/"$vm_tag_short".tar
  echo "Loading image from \"$image_path\"."
  # Load the built Docker image from the build directory.
  docker load --input "$image_path"

  echo "Pushing Docker image for \"$TARGET_ARCH\" to \"$vm_tag_long\"."
  # Push the Docker image to the registry.
  docker push "$vm_tag_long"

  echo "Tagging image as \"latest\", \"$vm_tag_long_latest\"."
  # Tag the Docker image as the latest image.
  docker tag "$vm_tag_long" "$vm_tag_long_latest"

  echo "Pushing \"latest\" tag."
  # Push the latest tag to the registry.
  docker push "$vm_tag_long_latest"

  # If a Git tag is present.
  if [ -n "$CI_COMMIT_TAG" ]; then
    vm_tag_long_stable=$CI_REGISTRY_IMAGE/$TARGET_ARCH:stable-"$vm"

    cho "Tagging image as \"stable\", \"$vm_tag_long_stable\"."
    # Tag the Docker image as the latest image.
    docker tag "$vm_tag_long" "$vm_tag_long_stable"

    echo "Pushing \"stable\" tag."
    # Push the latest tag to the registry.
    docker push "$vm_tag_long_stable"
  fi
}

echo "Deploying YAMDI with Hotspot VM."
deploy hotspot
echo "Deploying YAMDI with OpenJ9 VM."
deploy openj9
