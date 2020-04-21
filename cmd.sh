#!/bin/bash

# shellcheck source=utils.sh
source /usr/lib/utils

echo "$@" >"$COMMAND_INPUT_FILE"
