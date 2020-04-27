#!/bin/sh

# Log into the GitLab repository.
docker login -u gitlab-ci-token -p "$CI_JOB_TOKEN" "$CI_REGISTRY"
