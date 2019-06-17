#!/bin/bash
set -e

# Declares constant paths that are needed for operation.
# Arguments:
#   None.
# Returns:
#   None.
function export-paths() {
  # Set the directory for the server installation to be kept.
  export SERVER_DIRECTORY="/opt/server"
  # Set the directory for the server host configuration to be kept.
  export SERVER_CONFIG_HOST_DIRECTORY="/opt/server-config-host"
  # Set the directory for the server host plugins to be kept.
  export SERVER_PLUGINS_HOST_DIRECTORY="/opt/server-plugins-host"
  # Set the directory for the command named pipe to be.
  export COMMAND_INPUT_FILE="/tmp/server-commmand-input"
}

# Initializes a new temporary Git directory, makes a commit for it, and merges its contents with a
# given directory, using Git. For more details on the checkout method used here, see:
# https://gitolite.com/deploy.html
# Arguments:
#   Path to the source directory.
#   Path to the target directory.
# Returns:
#   None.
function import-directory() {
  SOURCE_DIRECTORY=$1
  TARGET_DIRECTORY=$2

  # If the directory is empty or doesn't exist. An unmounted Docker volume should be an empty directory.
  if [ -z "$(ls -A "$SOURCE_DIRECTORY")" ] || [ ! -d "$SOURCE_DIRECTORY" ]; then
    echo "No files to import."
    return 0
  fi

  echo "Making copy of host files."
  declare -r SOURCE_DIRECTORY_VCS="$SOURCE_DIRECTORY-copy"
  cp -R "$SOURCE_DIRECTORY" "$SOURCE_DIRECTORY_VCS"

  echo "Initializing Git repo."
  # Use a temporary Git directory. This reduces the need for maintining a repo externally, and
  # reduces any conflict with a preexisting repo.
  export GIT_DIR="$SOURCE_DIRECTORY_VCS/.git-yamdi"
  # For now, use the source directory as Git's working directory, to copy the initial changes.
  export GIT_WORK_TREE="$SOURCE_DIRECTORY_VCS"
  # Initialize the temporary directory, if it hasn't already been initialized.
  git init -q

  echo "Configuring Git repo."
  # git commit --author doesn't seem to work correctly here, so set the author info in its own
  # set of commands.
  git config user.name "YAMDI, with love ♥"
  git config user.email "codingkoopa@gmail.com"

  echo "Making Git commit."
  # Add all files from the directory from the stage. This also stages deletions.
  git add -A
  # Remove our temporary Git directory from the stage.
  git reset -- "$GIT_DIR"
  # Make a commit. This is necessary because otherwise, we can't really use this repo for anything.
  # Procede even if failed because that probably just means there haven't been any configuration
  # changes.
  git commit -m "Automatically generated commit." || true

  echo "Switching Git working directory to target."
  # Pull the rug out from under Git - make it use the target directory.
  export GIT_WORK_TREE="$TARGET_DIRECTORY"

  # If the directory doesn't already exist, create it, and don't show the diff.
  if [ ! -d "$TARGET_DIRECTORY" ]; then
    echo "Making new directory."
    mkdir -p "$TARGET_DIRECTORY"
  else
    echo "Changes that will be overwritten:"
    # Right now, reverse the input so it makes more sense. Condense the summary because otherwise
    # the full contents of new additions will be displayed.
    git diff --color -R --compact-summary
  fi

  echo "Updating server directory."
  # Update the directory with new changes. Procede if failed, because if no commit was made, then
  # there won't be a valid master branch to use.
  git checkout -q -f master || true
}

# Given two directories setup by import-directory(), compare them for changes.
# Arguments:
#   Path to the source directory.
#   Path to the target directory.
# Returns:
#   None.
function get-directory-changes() {
  SOURCE_DIRECTORY=$1
  TARGET_DIRECTORY=$2

  export GIT_DIR="$SOURCE_DIRECTORY-copy/.git-yamdi"
  export GIT_WORK_TREE="$TARGET_DIRECTORY"
  if [ -d "$GIT_DIR" ]; then
    git diff --color
  else
    echo "No Git repo found."
  fi
}

# Exits YAMDI, waiting for Java to save and removing the Git repository. "wait" must be ran
# separately, because this function will be ran in its own sub process.
# Arguments:
#   None.
# Returns:
#   None.
function exit-script() {
  echo "Exiting script."

  echo "Getting changes made by server to configuration files."
  get-directory-changes "$SERVER_CONFIG_VCS_DIRECTORY" "$SERVER_DIRECTORY"
  echo "Getting changes made by server to plugin files."
  get-directory-changes "$SERVER_PLUGINS_VCS_DIRECTORY" "$SERVER_DIRECTORY/plugins"

  exit 0
}

# Stops the server, and exits the script. This function can handle SIGINT and SIGTERM signals.
# Arguments:
#   None.
# Returns:
#   None.
function stop() {
  # Print a message because otherwise, it is very difficult to tell that this trap is actually
  # being triggered.
  echo "SIGINT or SIGTERM recieved. Sending stop command to server."
  # Send the "stop" command to the server.
  cmd stop
  echo "Waiting for Java process to exit."
  wait
  exit-script
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

echo "Starting up Yet Another Minecraft Docker Image."

export-paths

# Enter the server directory because we will use Git to update files here, and the Minecraft server
# will check the current directory for configuration files.
cd "$SERVER_DIRECTORY"

echo "Importing server configuration files."
import-directory "$SERVER_CONFIG_HOST_DIRECTORY" "$SERVER_DIRECTORY"
echo "Importing server plugin files."
import-directory "$SERVER_PLUGINS_HOST_DIRECTORY" "$SERVER_DIRECTORY/plugins"

if [ -z "$SERVER_TYPE" ]; then
  SERVER_TYPE="spigot"
fi
if [ -z "$REV" ]; then
  REV="latest"
fi
if [ -z "$BUILDTOOLS_MEMORY_AMOUNT" ]; then
  BUILDTOOLS_MEMORY_AMOUNT="1024M"
fi
if [ -z "$GAME_MEMORY_AMOUNT" ]; then
  GAME_MEMORY_AMOUNT="1024M"
fi

if [ "$SERVER_TYPE" = "spigot" ]; then
  echo "Spigot server selected."

  declare -r SERVER_JAR="$SERVER_DIRECTORY/spigot.jar"
  declare -r SPIGOT_REVISION_JAR="$SERVER_DIRECTORY/spigot-$REV.jar"
  declare -r SERVER_NAME="Spigot-$REV"

  # Only build a new spigot.jar if manually enabled, or if a jar for this REV does not already
  # exist.
  if [ "$FORCE_SPIGOT_REBUILD" = true ] || [ ! -f "$SPIGOT_REVISION_JAR" ]; then
    echo "Building $SERVER_NAME."
    # Build in a temporary directory.
    declare -r SPIGOT_BUILD_DIRECTORY=/tmp/spigot-build
    mkdir -p "$SPIGOT_BUILD_DIRECTORY"
    pushd "$SPIGOT_BUILD_DIRECTORY"
    # Remove any preexisting JARs from failed compilations.
    rm -f BuildTools.jar
    # Download the latest BuildTools JAR.
    wget -q https://hub.spigotmc.org/jenkins/job/\
BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
    # Run BuildTools with the specified RAM, for the specified revision.
    # shellcheck disable=SC2086
    java $JVM_OPTS -Xmx${BUILDTOOLS_MEMORY_AMOUNT} -Xms${BUILDTOOLS_MEMORY_AMOUNT} \
        -jar BuildTools.jar --rev $REV
    # Copy the Spigot build to the Spigot directory.
    cp spigot-*.jar "$SPIGOT_REVISION_JAR"
    popd
    # Remove the build files to preserve space.
    rm -rf "$SPIGOT_BUILD_DIRECTORY"
  else
    echo "$SERVER_NAME already built."
  fi

  # Select the specified revision. In some cases, ln's -f option doesn't work.
  rm -rf "$SERVER_JAR"
  ln -s "$SPIGOT_REVISION_JAR" "$SERVER_JAR"

elif [ $SERVER_TYPE = "paper" ]; then
  echo "Paper server selected."

  declare -r SERVER_JAR="$SERVER_DIRECTORY/paper.jar"
  if [ -z "$PAPER_BUILD" ]; then
    PAPER_BUILD="latest"
  fi

  # Unlike Spigot, the Paper launcher doesn't know what to do with a "latest" version, so here we
  # manually find out the latest version using the API. When we do have the latest version, if a
  # "latest" build was specified (or omitted altogether) then we have to find out that too.
  if [ "$REV" = "latest" ]; then
    echo "Resolving latest Paper revision."

    PARCHMENT_VERSIONS_JSON=$(curl -s https://papermc.io/api/v1/$SERVER_TYPE)
    # Handle errors returned by the API.
    VERSION_JSON_ERROR=$(echo "$PARCHMENT_VERSIONS_JSON" | jq .error)
    if [ ! "null" = "$VERSION_JSON_ERROR" ]; then
      echo "Error: Failed to fetch Paper versions. Curl error: \"$VERSION_JSON_ERROR\"."
      exit 2
    fi

    REV=$(echo "$PARCHMENT_VERSIONS_JSON" | jq .versions[0] | sed s\#\"\#\#g)
  fi
  echo "Paper revision: \"$REV\"."

  if [ "$PAPER_BUILD" = "latest" ]; then
    echo "Resolving latest Paper build."
    PARCHMENT_BUILD_JSON=$(curl -s "https://papermc.io/api/v1/$SERVER_TYPE/$REV/$PAPER_BUILD")
    # Handle errors returned by the API.
    BUILD_JSON_ERROR=$(echo "$PARCHMENT_BUILD_JSON" | jq .error)
    if [ ! "null" = "$BUILD_JSON_ERROR" ]; then
      echo "Error: Failed to fetch Paper build info. Curl error: \"$BUILD_JSON_ERROR\"."
      exit 2
    fi

    PAPER_BUILD=$(echo "$PARCHMENT_BUILD_JSON" | jq .build | sed s\#\"\#\#g)
  fi
  echo "Paper build: \"$PAPER_BUILD\"."

  declare -r PAPER_REVISION_JAR="$SERVER_DIRECTORY/paper-$REV-$PAPER_BUILD.jar"
  declare -r SERVER_NAME="Paper-$REV-$PAPER_BUILD"
  if [ ! -f "$PAPER_REVISION_JAR" ]; then
    echo "Downloading $SERVER_NAME."
    curl "https://papermc.io/api/v1/$SERVER_TYPE/$REV/$PAPER_BUILD/download" > "$PAPER_REVISION_JAR"
  else
    echo "$SERVER_NAME already downloaded."
  fi

  # Select the specified revision. In some cases, ln's -f option doesn't work.
  rm -rf "$SERVER_JAR"
  ln -sf "$PAPER_REVISION_JAR" "$SERVER_JAR"
fi

if [ ! -f "$SERVER_JAR" ]; then
  echo "Error: Server JAR not found. This could be due to a build error, or a misconfiguration."
  exit 1
fi

# Make sure the command input file is clear.
rm -f "$COMMAND_INPUT_FILE"
# Make a named pipe for sending commands to the server. It is important that the permissions are
# 700 because, if they were world writeable, any user could run a server command with administrator
# priviledges.
mkfifo -m700 "$COMMAND_INPUT_FILE"

# Append suggested JVM options unless required not to.
if [ ! "$USE_SUGGESTED_JVM_OPTS" = false ]; then
  # Set the error file path to include the server info.
  SUGGESTED_JVM_OPTS+=" -XX:ErrorFile=./$SERVER_NAME-error-pid%p.log"

  # Enable experimental VM features, for the options we'll be setting. Although this is not listed
  # in the documentation for "java", when I tested an experimental feature in a YAMDI container,
  # this was necessary. These options are largely taken from here: https://mcflags.emc.gs/.
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
fi

TOTAL_JVM_OPTS="-Xmx${GAME_MEMORY_AMOUNT} -Xms${GAME_MEMORY_AMOUNT} $SUGGESTED_JVM_OPTS $JVM_OPTS"
echo "Launching $SERVER_NAME with JVM options $TOTAL_JVM_OPTS."
# Start the launcher with the specified memory amounts. Execute it in the background, so that this
# script can still recieve signals.
# shellcheck disable=SC2086
java $TOTAL_JVM_OPTS -jar "$SERVER_JAR" nogui < <(tail -f "$COMMAND_INPUT_FILE") &
echo "Waiting for Java process to exit."
wait
exit-script