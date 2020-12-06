#!/bin/bash
set -e

# Exits YAMDI, saving the patch for any changes that have been made to the configuration files by
# the server. If the Java process seems to have crashed, the patch will not be created.
# Arguments:
#   - The Java return code.
# Outputs:
#   - Status messages.
# Returns:
#   - The same Java return code.
# Variables Read:
#   - SERVER_CONFIG_HOST_DIRECTORY: Location of the mountpoint of the host's configuration
# directory.
#   - SERVER_DIRECTORY: Location of the containerized server directory.
function exit_script() {
  local -r java_ret=$1

  info "Stopping Yet Another Minecraft Docker Image."

  if [ "$java_ret" -ne 0 ]; then
    warning "Java process return code is $java_ret, likely crashed. Not checking files for changes."
  else
    info "Checking server configuration files."
    get_directory_changes "$SERVER_CONFIG_HOST_DIRECTORY" "$SERVER_DIRECTORY" \
      "$SERVER_DIRECTORY/config.patch"
    info "Checking server plugin files."
    get_directory_changes "$SERVER_PLUGINS_HOST_DIRECTORY" "$SERVER_DIRECTORY/plugins" \
      "$SERVER_DIRECTORY/plugins.patch"
  fi

  exit "$java_ret"
}

# Stops the server, and exits the script. This function can handle SIGINT and SIGTERM signals. This
# function needs "utils.sh" to be sourced.
# Outputs:
#   - Status messages.
# Variables Read:
#   - JAVA_PID: The PID of the Java process.
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
  local -r java_ret=$?
  set -e
  exit_script $java_ret
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

info "Starting Yet Another Minecraft Docker Image v1.0.2."

# Enter the server directory because we will use Git to update files here, and the Minecraft server
# will check the current directory for configuration files.
cd "$SERVER_DIRECTORY"

# Remove files that aren't depended upon by any stage of this script.
if [ "$YAMDI_CLEAN_FILES" = true ]; then
  debug "Cleaning crash dumps and reports."
  # Purge crash dumps.
  rm -rf {heapdump,javacore,Snap}.*
  # Purge crash reports and logs. With Docker, we have our own logging system.
  rm -rf crash-reports logs ./*.log
fi

info "Importing server configuration files."
import_directory "$SERVER_CONFIG_HOST_DIRECTORY" "$SERVER_DIRECTORY"
# Ignore server properties unless explicitly told not to.
if [ ! "$YAMDI_IGNORE_SERVER_PROPERTY_CHANGES" = false ]; then
  git update-index --assume-unchanged "$SERVER_DIRECTORY/server.properties"
fi

if [ -d "$SERVER_DIRECTORY/plugins" ]; then
  # If we aren't doing a clean, don't go any further than the root JARs.
  if [ ! "$YAMDI_CLEAN_FILES" = true ]; then
    maxdepth=(-maxdepth 1)
    declare -r maxdepth
  fi
  # If this isn't done, then when the source directory has new JARs, the target will still have the
  # old ones.
  find "$SERVER_DIRECTORY/plugins" "${maxdepth[@]}" -name "*.jar" -type f -delete
fi
info "Importing server plugin files."
import_directory "$SERVER_PLUGINS_HOST_DIRECTORY" "$SERVER_DIRECTORY/plugins"

# This is necessary because of Spigot BuildTools needing to use Git.
debug "Unsetting Git variables."
unset GIT_DIR GIT_WORK_TREE

if [ -z "$YAMDI_SERVER_TYPE" ]; then
  YAMDI_SERVER_TYPE="spigot"
fi
if [ -z "$YAMDI_REV" ]; then
  YAMDI_REV="latest"
fi

if [ "$YAMDI_SERVER_TYPE" = "spigot" ]; then
  info "Spigot server selected."

  declare -r server_jar="$SERVER_DIRECTORY/spigot.jar"
  declare -r spigot_revision_jar="$SERVER_DIRECTORY/spigot-$YAMDI_REV.jar"
  declare -r server_name="Spigot-$YAMDI_REV"

  # Only build a new spigot.jar if manually enabled, or if a jar for this REV does not already
  # exist.
  if [ "$FORCE_SPIGOT_REBUILD" = true ] || [ ! -f "$spigot_revision_jar" ]; then
    debug "Building $server_name."
    # Build in a temporary directory.
    declare -r spigot_build_directory=/tmp/spigot-build
    mkdir -p "$spigot_build_directory"
    pushd "$spigot_build_directory"
    # Remove any preexisting JARs from failed compilations.
    rm -f BuildTools.jar
    # Download the latest BuildTools JAR.
    wget -q "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/\
artifact/target/BuildTools.jar"

    buildtools_memory_opts=$(generate_memory_opts "$YAMDI_BUILDTOOLS_MEMORY_AMOUNT_MIN" \
      "$YAMDI_BUILDTOOLS_MEMORY_AMOUNT_MAX" "$YAMDI_BUILDTOOLS_MEMORY_AMOUNT")
    declare -r buildtools_memory_opts
    declare -r total_buildtools_memory_opts="$buildtools_memory_opts $JVM_OPTS"

    # Run BuildTools with the specified RAM, for the specified revision.
    # shellcheck disable=SC2086
    java $total_buildtools_memory_opts -jar BuildTools.jar --rev $YAMDI_REV
    # Copy the Spigot build to the Spigot directory.
    cp spigot-*.jar "$spigot_revision_jar"
    popd
    # Remove the build files to preserve space.
    rm -rf "$spigot_build_directory"
  else
    debug "$server_name already built."
  fi

  # Select the specified revision. In some cases, ln's -f option doesn't work.
  rm -rf "$server_jar"
  ln -s "$spigot_revision_jar" "$server_jar"

elif [ $YAMDI_SERVER_TYPE = "paper" ]; then
  info "Paper server selected."

  declare -r server_jar="$SERVER_DIRECTORY/paper.jar"
  if [ -z "$YAMDI_PAPER_BUILD" ]; then
    YAMDI_PAPER_BUILD="latest"
  fi

  # Disable exit on error so that we can handle curl errors.
  set +e
  handle_curl_errors() {
    curl_ret=$?
    if [ "$curl_ret" -ne 0 ]; then
      error "Failed to connect to Paper servers. Curl error code: \"$curl_ret\""
      exit 2
    fi
  }

  # Unlike Spigot, the Paper launcher doesn't know what to do with a "latest" version, so here we
  # manually find out the latest version using the API. When we do have the latest version, if a
  # "latest" build was specified (or omitted altogether) then we have to find out that too.
  if [ "$YAMDI_REV" = "latest" ]; then
    debug "Resolving latest Paper revision."

    versions_json=$(curl -s https://papermc.io/api/v2/projects/$YAMDI_SERVER_TYPE)
    declare -r versions_json

    handle_curl_errors
    version_json_error=$(echo "$versions_json" | jq .error)
    declare -r version_json_error
    if [ ! "null" = "$version_json_error" ]; then
      error "Failed to fetch Paper versions. Curl error: \"$version_json_error\"."
      exit 2
    fi

    YAMDI_REV=$(echo "$versions_json" | jq .versions[-1] | sed s/\"//g)
  fi
  debug "Paper revision: \"$YAMDI_REV\"."

  if [ "$YAMDI_PAPER_BUILD" = "latest" ]; then
    debug "Resolving latest Paper build."
    builds_json=$(curl -s \
      "https://papermc.io/api/v2/projects/$YAMDI_SERVER_TYPE/versions/$YAMDI_REV")
    declare -r builds_json

    handle_curl_errors
    builds_json_error=$(echo "$builds_json" | jq .error)
    declare -r builds_json_error
    if [ ! "null" = "$builds_json_error" ]; then
      error "Failed to fetch Paper build info. Curl error: \"$builds_json_error\"."
      exit 2
    fi

    YAMDI_PAPER_BUILD=$(echo "$builds_json" | jq .builds[-1] | sed s/\"//g)
  fi
  debug "Paper build: \"$YAMDI_PAPER_BUILD\"."

  debug "Resolving Paper build name."
  build_json=$(curl -s "https://papermc.io/api/v2/projects/$YAMDI_SERVER_TYPE/\
versions/$YAMDI_REV/builds/$YAMDI_PAPER_BUILD")
  declare -r build_json

  handle_curl_errors
  build_json_error=$(echo "$build_json" | jq .error)
  declare -r builds_json_error
  if [ ! "null" = "$build_json_error" ]; then
    error "Failed to fetch Paper build info. Curl error: \"$build_json_error\"."
    exit 2
  fi

  paper_build_jar_name=$(echo "$build_json" | jq .downloads.application.name | sed s/\"//g)
  declare -r paper_build_jar_name

  declare -r paper_revision_jar="$SERVER_DIRECTORY/\
$YAMDI_SERVER_TYPE-$YAMDI_REV-$YAMDI_PAPER_BUILD.jar"
  declare -r server_name="Paper-$YAMDI_REV-$YAMDI_PAPER_BUILD"
  if [ ! -f "$paper_revision_jar" ]; then
    debug "Downloading $server_name."
    curl "https://papermc.io/api/v2/projects/$YAMDI_SERVER_TYPE/versions/$YAMDI_REV/builds/\
$YAMDI_PAPER_BUILD/downloads/$paper_build_jar_name" >"$paper_revision_jar"
    handle_curl_errors
  else
    debug "$server_name already downloaded."
  fi

  # Select the specified revision. In some cases, ln's -f option doesn't work.
  rm -rf "$server_jar"
  ln -sf "$paper_revision_jar" "$server_jar"
fi

if [ ! -f "$server_jar" ]; then
  error "Error: Server JAR not found. This could be due to a build error, or a misconfiguration."
  exit 1
fi

# Perform server JAR cleanup.
if [ "$YAMDI_CLEAN_FILES" = true ]; then
  find "$SERVER_DIRECTORY" -maxdepth 1 \
    \( -name "*.jar" ! -name "$(basename "$(readlink "$server_jar")")" \) -type f -delete
fi

# Make sure the command input file is clear.
rm -f "$COMMAND_INPUT_FILE"
# Make a named pipe for sending commands to the server. It is important that the permissions are
# 700 because, if they were world writeable, any user could run a server command with administrator
# priviledges.
mkfifo -m700 "$COMMAND_INPUT_FILE"

game_memory_opts=$(generate_memory_opts "$YAMDI_GAME_MEMORY_AMOUNT_MIN" \
  "$YAMDI_GAME_MEMORY_AMOUNT_MAX" "$YAMDI_GAME_MEMORY_AMOUNT")
declare -r game_memory_opts

# Append suggested JVM options unless required not to.
if [ ! "$YAMDI_USE_SUGGESTED_JVM_OPTS" = false ]; then
  if [ "$JVM" = "hotspot" ]; then
    # Set the error file path to include the server info.
    suggested_jvm_opts+=" -XX:ErrorFile=./$server_name-error-pid%p.log"

    # Enable experimental VM features, for the options we'll be setting. Although this is not
    # listed in the documentation for "java", when I tested an experimental feature in a YAMDI
    # container, this was necessary. These options are largely taken from here:
    # https://mcflags.emc.gs/.
    suggested_jvm_opts+=" -XX:+UnlockExperimentalVMOptions"

    # Ensure that the G1 garbage collector is enabled, because in some cases it isn't the default.
    suggested_jvm_opts+=" -XX:+UseG1GC"
    # Don't reserve memory, because this option seems to break and cause OOM errors when running in
    # Docker.
    # suggested_jvm_opts+=" -XX:+AlwaysPreTouch"
    # Disable explicit garbage collection, because some plugins try to manage their own memory and
    # suck at it.
    suggested_jvm_opts+=" -XX:+DisableExplicitGC"
    # Adjust the max size of the new generation that will be set later.
    suggested_jvm_opts+=" -XX:G1MaxNewSizePercent=80"
    # Lower the garbage collection threshold, to make cleanups not as demanding.
    suggested_jvm_opts+=" -XX:G1MixedGCLiveThresholdPercent=35"
    # Raise the New Generation size to keep up with MC's allocations, because MC has many.
    suggested_jvm_opts+=" -XX:G1NewSizePercent=50"
    # Take 100ms at the most to collect garbage.
    suggested_jvm_opts+=" -XX:MaxGCPauseMillis=100"
    # Allow garbage collection to use multiple threads, for performance.
    suggested_jvm_opts+=" -XX:+ParallelRefProcEnabled"
    # Set the garbage collection target survivor ratio higher to use more of the survivor space
    # before promoting it, because MC has steady allocations.
    suggested_jvm_opts+=" -XX:TargetSurvivorRatio=90"
  elif [ "$JVM" = "openj9" ]; then
    # These options are largely taken from here:
    # https://steinborn.me/posts/tuning-minecraft-openj9/.
    # See the utility script for the generation of the nursery limits.

    # Enable pausless garbage collection, for smaller pause times.
    suggested_jvm_opts+=" -Xgc:concurrentScavenge"
    # Reduce the amount of time spent collecting the nursery.
    suggested_jvm_opts+=" -Xgc:dnssExpectedTimeRatioMaximum=3"
    # Ensure that nursery objects aren't promoted to the nursery too quickly, since the server will
    # be making many of them.
    suggested_jvm_opts+=" -Xgc:scvNoAdaptiveTenure"
    # Disable explicit garbage collection, for the same reason as in hotspot.
    suggested_jvm_opts+=" -Xdisableexplicitgc"
  fi
fi

total_game_jvm_opts="$game_memory_opts $suggested_jvm_opts $JVM_OPTS"
declare -r total_game_jvm_opts
info "Launching Java process for $server_name with JVM options \"$total_game_jvm_opts\"."
# Start the launcher with the specified memory amounts. Execute it in the background, so that this
# script can still recieve signals.
# shellcheck disable=SC2086
java $total_game_jvm_opts -jar "$server_jar" nogui < <(tail -f "$COMMAND_INPUT_FILE") &
export JAVA_PID=$!
debug "Waiting for Java process (PID $JAVA_PID) to exit."
# Allow wait to return an error without making the whole script exit.
set +e
wait "$JAVA_PID"
java_ret=$?
set -e
debug "Java process exited (return $java_ret)."
exit_script $java_ret
