#!/bin/bash

# Set the directory for the command named pipe to be.
declare -r COMMAND_INPUT_FILE="/tmp/server-commmand-input"

echo "$@" > "$COMMAND_INPUT_FILE"