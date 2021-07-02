#!/bin/sh

# This shell script is intended to be copied and used to run YAMDI. It sets up sane defaults, and
# exposes everything that is likely to be of interest. It's not commented because there's no way
# to do so on a line by line basis; for more information on what each part of this command does,
# please refer to the YAMDI documentation.

set -x
docker run \
  --env YAMDI_SERVER_TYPE=paper \
  --env YAMDI_MINECRAFT_VERSION="latest" \
  --env YAMDI_CLEAN_FILES="true" \
  --mount type=volume,source=mc_server_data,target=/opt/yamdi/user/server,volume-nocopy=true \
  --mount type=bind,source="$(pwd)/mc-config",target=/opt/server-config-host \
  --mount type=bind,source="$(pwd)/mc-plugins",target=/opt/server-plugins-host \
  --expose 25565 \
  yamdi/yamdi:latest
