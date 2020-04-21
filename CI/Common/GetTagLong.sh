#!/bin/sh

# Generate the full tag of the image, including the registry URL.
echo "$CI_REGISTRY_IMAGE"/"$(CI/Common/GetTagShort.sh)"
