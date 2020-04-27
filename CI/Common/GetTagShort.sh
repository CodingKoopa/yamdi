#!/bin/sh

# Tag images with the architecture they're for, to begin with.
short_tag=$TARGET_ARCH:

# If a Git tag is present.
if [ -n "$CI_COMMIT_TAG" ]; then
  # If this job is being ran for a tagged commit, tag it with the commit tag.
  short_tag=$short_tag$CI_COMMIT_TAG
else
  # If this job is being ran for a normal commit, tag it with the commit hash.
  short_tag=$short_tag$CI_COMMIT_SHA
fi

echo "$short_tag"
