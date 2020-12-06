#!/bin/sh

# Prints a message, prepended with "[CI]" to indicate that it's coming from these scripts.
# Arguments:
#   - The message to print.
# Outputs:
#   - The full message with the prefix.
_echo() {
  echo "[CI] $*"
}

# Logs into the GitLab container registry.
# Variables Read:
#   - CI_JOB_TOKEN: GitLab CI job token used to authenticate with the API.
#   - CI_REGISTRY: Address of the GitLab Container Registry.
login() {
  echo "$CI_JOB_TOKEN" | docker login "$CI_REGISTRY" -u gitlab-ci-token --password-stdin
}

# Gets the tag of the image currently being built.
# Outputs:
#   - The tag.
# Variables Read:
#   - TARGET_ARCH: The architecture to build for, such as "amd64".
#   - CI_COMMIT_TAG: The tag of this commit (optional if hash is specified).
#   - CI_COMMIT_SHA: The hash of this commit (optional if tag is specified).
get_tag() {
  # Tag images with the architecture they're for, to begin with.
  short_tag=$TARGET_ARCH

  # If a Git tag is present.
  if [ -n "$CI_COMMIT_TAG" ]; then
    # Add the Git tag.
    short_tag=$short_tag:$CI_COMMIT_TAG
  else
    # Add the Git commit hash.
    short_tag=$short_tag:$CI_COMMIT_SHA
  fi

  # Print the tag.
  echo "$short_tag"
}

# Gets the full tag of the image currently being built, including the registry URL.
# Outputs:
#   - The full tag.
# Variables Read:
#   - CI_REGISTRY_IMAGE: Address of registry for this project.
#   - TARGET_ARCH: See get_tag().
#   - CI_COMMIT_TAG: See get_tag().
#   - CI_COMMIT_SHA: See get_tag().
get_tag_full() {
  # Print the full tag.
  echo "$CI_REGISTRY_IMAGE"/"$(get_tag)"
}

# Gets the full tag for the latest image for this project.
# Outputs:
#   - The full "latest" tag.
# Variables Read:
#   - CI_REGISTRY_IMAGE: See get_full_tag().
#   - TARGET_ARCH: See get_tag().
get_tag_full_latest() {
  # Generate the long "latest" tag of the image.
  echo "$CI_REGISTRY_IMAGE"/"$TARGET_ARCH":latest
}

# Gets the full tag for the latest stable image for this project.
# Outputs:
#   - The full "stable" tag.
# Variables Read:
#   - CI_REGISTRY_IMAGE: See get_full_tag().
#   - TARGET_ARCH: See get_tag().
get_tag_full_stable() {
  # Generate the long "latest" tag of the image.
  echo "$CI_REGISTRY_IMAGE"/"$TARGET_ARCH":stable
}
