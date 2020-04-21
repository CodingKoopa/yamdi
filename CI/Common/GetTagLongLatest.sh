#!/bin/sh

# Generate the long "latest" tag of the image.
echo "$CI_REGISTRY_IMAGE"/"$TARGET_ARCH":latest
