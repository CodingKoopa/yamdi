#!/bin/sh

# Tag images with the architecture they're for, to begin with.
SHORT_TAG=$TARGET_ARCH:

# If a Git tag is present.
if [ -n "$CI_COMMIT_TAG" ]; then
  # If this job is being ran for a tagged commit, tag it with the commit tag.
  SHORT_TAG=$SHORT_TAG$CI_COMMIT_TAG
else
  # If this job is being ran for a normal commit, tag it with the commit hash.
  SHORT_TAG=$SHORT_TAG$CI_COMMIT_SHA
fi

echo "$SHORT_TAG"
