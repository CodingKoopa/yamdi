#!/bin/bash
set -e

# Exits YAMDI, saving the patch for any changes that have been made to the configuration files by
# the server. If the Java process seems to have crashed, the patch will not be created.
# Arguments:
#   The Java return code.
# Globals Read:
#   - SERVER_CONFIG_HOST_DIRECTORY: Location of the mountpoint of the host's configuration directory.
#   - SERVER_DIRECTORY: Location of the containerized server directory.
# Arguments:
#   - The Java return code.
# Outputs:
#   - Status messages.
# Returns:
#   - The Java return code.
function exit_script() {
  JAVA_RET=$1

  info "Stopping Yet Another Minecraft Docker Image."

  if [ "$JAVA_RET" -ne 0 ]; then
    warning "Java process return code is $JAVA_RET, likely crashed. Not checking files for changes."
  else
    info "Checking server configuration files."
    get_directory_changes "$SERVER_CONFIG_HOST_DIRECTORY" "$SERVER_DIRECTORY" \
        "$SERVER_DIRECTORY/config.patch"
    info "Checking server plugin files."
    get_directory_changes "$SERVER_PLUGINS_HOST_DIRECTORY" "$SERVER_DIRECTORY/plugins" \
        "$SERVER_DIRECTORY/plugins.patch"
  fi

  exit "$JAVA_RET"
}

# Stops the server, and exits the script. This function can handle SIGINT and SIGTERM signals. This
# function needs "utils.sh" to be sourced.
# Globals Read:
#   - JAVA_PID: The PID of the Java process.
# Outputs:
#   - Status messages.
# Returns:
#   - The Java return code.
function stop() {
  # Print a message because otherwise, it is very difficult to tell that this trap is actually
  # being triggered.
  info "SIGINT or SIGTERM recieved. Sending stop command to server."
  # Send the "stop" command to the server.
  cmd stop
  debug "Waiting for Java process to exit."
  # JAVA_PID is exported after the Java process is started. If this function is called before then,
  # it should just be empty, which is fine for wait, as without arguments it will wait for all
  # background processes. This is still necessary though, because, through testing, it seems that
  # when the PID is specified in the other wait command, this one hangs.
  set +e
  wait "$JAVA_PID"
  JAVA_RET=$?
  set -e
  exit_script $JAVA_RET
}

# Handle the SIGINT and SIGTERM signals. SIGINT is what is normally sent to a program when Ctrl+C
# is pressed. The server handles this by quitting, without saving. SIGTERM is what is sent to a
# program when "docker stop" or "docker-compose" is used. SIGTERM is also used when an active
# Docker Compose session is quit with Ctrl+C (This does not work in regular Docker.).

# SIGINT and SIGTERM are expected to implemented similarly. The server implements them by shutting
# down the server, but without saving. The "stop" Bukkit command shuts down the server properly, 
# and does save everything, so here the signals are trapped, and will intervene to run the "stop" 
# command.
trap stop SIGINT
trap stop SIGTERM

# shellcheck source=utils.sh
source /usr/lib/utils

info "Starting Yet Another Minecraft Docker Image."

# Enter the server directory because we will use Git to update files here, and the Minecraft server
# will check the current directory for configuration files.
cd "$SERVER_DIRECTORY"

# Remove files that aren't depended upon by any stage of this script.
if [ "$CLEAN_FILES" = true ]; then
  debug "Cleaning crash dumps and reports."
  # Purge crash dumps. TODO: There are almost certainly more forms that could be included here.
  rm -rf {heapdump,javacore,Snap}.*
  # Purge crash reports and logs. With Docker, we have our own logging system.
  rm -rf crash-reports logs ./*.log
fi

info "Importing server configuration files."
import_directory "$SERVER_CONFIG_HOST_DIRECTORY" "$SERVER_DIRECTORY"
# Ignore server properties unless explicitly told not to.
if [ ! "$IGNORE_SERVER_PROPERTY_CHANGES" = false ]; then
  git update-index --assume-unchanged "$SERVER_DIRECTORY/server.properties"
fi

if [ -d "$SERVER_DIRECTORY/plugins" ]; then
  # If we aren't doing a clean, don't go any further than the root JARs.
  if [ ! "$CLEAN_FILES" = true ]; then
    MAXDEPTH=(-maxdepth 1)
  fi
  # If this isn't done, then when the source directory has new JARs, the target will still have the
  # old ones.
  find "$SERVER_DIRECTORY/plugins" "${MAXDEPTH[@]}" -name "*.jar" -type f -delete
fi
info "Importing server plugin files."
import_directory "$SERVER_PLUGINS_HOST_DIRECTORY" "$SERVER_DIRECTORY/plugins"

# This is necessary because of Spigot BuildTools needing to use Git.
debug "Unsetting Git variables."
unset GIT_DIR GIT_WORK_TREE

if [ -z "$SERVER_TYPE" ]; then
  SERVER_TYPE="spigot"
fi
if [ -z "$REV" ]; then
  REV="latest"
fi

if [ "$SERVER_TYPE" = "spigot" ]; then
  info "Spigot server selected."

  declare -r SERVER_JAR="$SERVER_DIRECTORY/spigot.jar"
  declare -r SPIGOT_REVISION_JAR="$SERVER_DIRECTORY/spigot-$REV.jar"
  declare -r SERVER_NAME="Spigot-$REV"

  # Only build a new spigot.jar if manually enabled, or if a jar for this REV does not already
  # exist.
  if [ "$FORCE_SPIGOT_REBUILD" = true ] || [ ! -f "$SPIGOT_REVISION_JAR" ]; then
    debug "Building $SERVER_NAME."
    # Build in a temporary directory.
    declare -r SPIGOT_BUILD_DIRECTORY=/tmp/spigot-build
    mkdir -p "$SPIGOT_BUILD_DIRECTORY"
    pushd "$SPIGOT_BUILD_DIRECTORY"
    # Remove any preexisting JARs from failed compilations.
    rm -f BuildTools.jar
    # Download the latest BuildTools JAR.
    wget -q https://hub.spigotmc.org/jenkins/job/\
BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar

    BUILDTOOLS_MEMORY_OPTS=$(generate_memory_opts "$BUILDTOOLS_MEMORY_AMOUNT_MIN" \
        "$BUILDTOOLS_MEMORY_AMOUNT_MAX" "$BUILDTOOLS_MEMORY_AMOUNT")
    TOTAL_BUILDTOOLS_MEMORY_OPTS="$BUILDTOOLS_MEMORY_OPTS $JVM_OPTS"

    # Run BuildTools with the specified RAM, for the specified revision.
    # shellcheck disable=SC2086
    java $TOTAL_BUILDTOOLS_MEMORY_OPTS -jar BuildTools.jar --rev $REV
    # Copy the Spigot build to the Spigot directory.
    cp spigot-*.jar "$SPIGOT_REVISION_JAR"
    popd
    # Remove the build files to preserve space.
    rm -rf "$SPIGOT_BUILD_DIRECTORY"
  else
    debug "$SERVER_NAME already built."
  fi

  # Select the specified revision. In some cases, ln's -f option doesn't work.
  rm -rf "$SERVER_JAR"
  ln -s "$SPIGOT_REVISION_JAR" "$SERVER_JAR"

elif [ $SERVER_TYPE = "paper" ]; then
  info "Paper server selected."

  declare -r SERVER_JAR="$SERVER_DIRECTORY/paper.jar"
  if [ -z "$PAPER_BUILD" ]; then
    PAPER_BUILD="latest"
  fi

  # Disable exit on error so that we can handle curl errors.
  set +e
  handle_curl_errors() {
    CURL_RET=$?
    if [ "$CURL_RET" -ne 0 ]; then
      error "Failed to connect to Paper servers. Curl error code: \"$CURL_RET\""
      exit 2
    fi
  }

  # Unlike Spigot, the Paper launcher doesn't know what to do with a "latest" version, so here we
  # manually find out the latest version using the API. When we do have the latest version, if a
  # "latest" build was specified (or omitted altogether) then we have to find out that too.
  if [ "$REV" = "latest" ]; then
    debug "Resolving latest Paper revision."

    PARCHMENT_VERSIONS_JSON=$(curl -s https://papermc.io/api/v1/$SERVER_TYPE)
    handle_curl_errors
    # Handle errors returned by the API.
    VERSION_JSON_ERROR=$(echo "$PARCHMENT_VERSIONS_JSON" | jq .error)
    if [ ! "null" = "$VERSION_JSON_ERROR" ]; then
      error "Failed to fetch Paper versions. Curl error: \"$VERSION_JSON_ERROR\"."
      exit 2
    fi

    REV=$(echo "$PARCHMENT_VERSIONS_JSON" | jq .versions[0] | sed s\#\"\#\#g)
  fi
  debug "Paper revision: \"$REV\"."

  if [ "$PAPER_BUILD" = "latest" ]; then
    debug "Resolving latest Paper build."
    PARCHMENT_BUILD_JSON=$(curl -s "https://papermc.io/api/v1/$SERVER_TYPE/$REV/$PAPER_BUILD")
    handle_curl_errors
    # Handle errors returned by the API.
    BUILD_JSON_ERROR=$(echo "$PARCHMENT_BUILD_JSON" | jq .error)
    if [ ! "null" = "$BUILD_JSON_ERROR" ]; then
      error "Failed to fetch Paper build info. Curl error: \"$BUILD_JSON_ERROR\"."
      exit 2
    fi

    PAPER_BUILD=$(echo "$PARCHMENT_BUILD_JSON" | jq .build | sed s\#\"\#\#g)
  fi
  debug "Paper build: \"$PAPER_BUILD\"."

  set -e

  declare -r PAPER_REVISION_JAR="$SERVER_DIRECTORY/paper-$REV-$PAPER_BUILD.jar"
  declare -r SERVER_NAME="Paper-$REV-$PAPER_BUILD"
  if [ ! -f "$PAPER_REVISION_JAR" ]; then
    debug "Downloading $SERVER_NAME."
    curl "https://papermc.io/api/v1/$SERVER_TYPE/$REV/$PAPER_BUILD/download" > "$PAPER_REVISION_JAR"
  else
    debug "$SERVER_NAME already downloaded."
  fi

  # Select the specified revision. In some cases, ln's -f option doesn't work.
  rm -rf "$SERVER_JAR"
  ln -sf "$PAPER_REVISION_JAR" "$SERVER_JAR"
fi

if [ ! -f "$SERVER_JAR" ]; then
  error "Error: Server JAR not found. This could be due to a build error, or a misconfiguration."
  exit 1
fi

# Perform server JAR cleanup.
if [ "$CLEAN_FILES" = true ]; then
  find "$SERVER_DIRECTORY" -maxdepth 1 \( -name "*.jar" ! -name "$(basename "$(readlink "$SERVER_JAR")")" \) -type f -delete
fi

# Make sure the command input file is clear.
rm -f "$COMMAND_INPUT_FILE"
# Make a named pipe for sending commands to the server. It is important that the permissions are
# 700 because, if they were world writeable, any user could run a server command with administrator
# priviledges.
mkfifo -m700 "$COMMAND_INPUT_FILE"

GAME_MEMORY_OPTS=$(generate_memory_opts "$GAME_MEMORY_AMOUNT_MIN" "$GAME_MEMORY_AMOUNT_MAX" \
    "$GAME_MEMORY_AMOUNT")

# Append suggested JVM options unless required not to.
if [ ! "$USE_SUGGESTED_JVM_OPTS" = false ]; then
  if [ "$JVM" = "hotspot" ]; then
    # Set the error file path to include the server info.
    SUGGESTED_JVM_OPTS+=" -XX:ErrorFile=./$SERVER_NAME-error-pid%p.log"

    # Enable experimental VM features, for the options we'll be setting. Although this is not
    # listed in the documentation for "java", when I tested an experimental feature in a YAMDI
    # container, this was necessary. These options are largely taken from here:
    # https://mcflags.emc.gs/.
    SUGGESTED_JVM_OPTS+=" -XX:+UnlockExperimentalVMOptions"

    # Ensure that the G1 garbage collector is enabled, because in some cases it isn't the default.
    SUGGESTED_JVM_OPTS+=" -XX:+UseG1GC"
    # Don't reserve memory, because this option seems to break and cause OOM errors when running in
    # Docker.
    # SUGGESTED_JVM_OPTS+=" -XX:+AlwaysPreTouch"
    # Disable explicit garbage collection, because some plugins try to manage their own memory and
    # suck at it.
    SUGGESTED_JVM_OPTS+=" -XX:+DisableExplicitGC"
    # Adjust the max size of the new generation that will be set later.
    SUGGESTED_JVM_OPTS+=" -XX:G1MaxNewSizePercent=80"
    # Lower the garbage collection threshold, to make cleanups not as demanding.
    SUGGESTED_JVM_OPTS+=" -XX:G1MixedGCLiveThresholdPercent=35"
    # Raise the New Generation size to keep up with MC's allocations, because MC has many.
    SUGGESTED_JVM_OPTS+=" -XX:G1NewSizePercent=50"
    # Take 100ms at the most to collect garbage.
    SUGGESTED_JVM_OPTS+=" -XX:MaxGCPauseMillis=100"
    # Allow garbage collection to use multiple threads, for performance.
    SUGGESTED_JVM_OPTS+=" -XX:+ParallelRefProcEnabled"
    # Set the garbage collection target survivor ratio higher to use more of the survivor space
    # before promoting it, because MC has steady allocations.
    SUGGESTED_JVM_OPTS+=" -XX:TargetSurvivorRatio=90"
  elif [ "$JVM" = "openj9" ]; then
    # These options are largely taken from here:
    # https://steinborn.me/posts/tuning-minecraft-openj9/.
    # See the utility script for the generation of the nursery limits.

    # Enable pausless garbage collection, for smaller pause times.
    SUGGESTED_JVM_OPTS+=" -Xgc:concurrentScavenge"
    # Reduce the amount of time spent collecting the nursery.
    SUGGESTED_JVM_OPTS+=" -Xgc:dnssExpectedTimeRatioMaximum=3"
    # Ensure that nursery objects aren't promoted to the nursery too quickly, since the server will
    # be making many of them.
    SUGGESTED_JVM_OPTS+=" -Xgc:scvNoAdaptiveTenure"
    # Disable explicit garbage collection, for the same reason as in hotspot.
    SUGGESTED_JVM_OPTS+=" -Xdisableexplicitgc"
  fi
fi

TOTAL_GAME_JVM_OPTS="$GAME_MEMORY_OPTS $SUGGESTED_JVM_OPTS $JVM_OPTS"
info "Launching Java process for $SERVER_NAME with JVM options \"$TOTAL_GAME_JVM_OPTS\"."
# Start the launcher with the specified memory amounts. Execute it in the background, so that this
# script can still recieve signals.
# shellcheck disable=SC2086
java $TOTAL_GAME_JVM_OPTS -jar "$SERVER_JAR" nogui < <(tail -f "$COMMAND_INPUT_FILE") &
export JAVA_PID=$!
debug "Waiting for Java process (PID $JAVA_PID) to exit."
# Allow wait to return an error without making the whole script exit.
set +e
wait "$JAVA_PID"
JAVA_RET=$?
set -e
debug "Java process exited (return $JAVA_RET)."
exit_script $JAVA_RET