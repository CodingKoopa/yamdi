#!/bin/bash
set -e

function stop() {
  # Print a message because otherwise, it is very difficult to tell that this trap is actually
  # being triggered.
  echo "Gracefully shutting down server."
  # Send the "stop" command to the server.
  cmd stop
  # Wait for the Java process to exit.
  wait
}

# Handle the SIGINT and SIGTERM signals. SIGINT is what is normally sent to a program when Ctrl+C
# is pressed. The server handles this by quitting, without saving. SIGTERM is what is sent to a program
# when "docker stop" or "docker-compose" is used. SIGTERM is also used when an active Docker
# Compose session is quit with Ctrl+C (This does not work in regular Docker.).

# SIGINT and SIGTERM are expected to implemented similarly. The server implements them by shutting down
# the server, but without saving. The "stop" Bukkit command shuts down the server properly, and does
# save everything, so here the signals are trapped, and will intervene to run the "stop" command.
trap stop SIGINT
trap stop SIGTERM

echo "Starting up Yet Another Minecraft Docker Image."

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
  declare -r SERVER_NAME="Spigot revision $REV"

  # Only build a new spigot.jar if manually enabled, or if a jar for this REV does not already exist.
  if [ "$FORCE_SPIGOT_REBUILD" = true ] || [ ! -f "$SPIGOT_REVISION_JAR" ]; then
    echo "Building $SERVER_NAME."
    # Build in a temporary directory.
    declare -r SPIGOT_BUILD_DIRECTORY=/tmp/spigot-build
    mkdir -p "$SPIGOT_BUILD_DIRECTORY"
    pushd "$SPIGOT_BUILD_DIRECTORY"
    # Remove any preexisting JARs from failed compilations.
    rm -f BuildTools.jar
    # Download the latest BuildTools JAR.
    wget -q https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
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

  # Select the specified revision.
  ln -sf "$SPIGOT_REVISION_JAR" "$SERVER_JAR"

elif [ "$FORCE_SPIGOT_REBUILD" = true ] || [ $SERVER_TYPE = "paper" ]; then
  echo "Paper server selected."

  declare -r SERVER_JAR="$SERVER_DIRECTORY/paper.jar"
  declare -r PAPER_REVISION_JAR="$SERVER_DIRECTORY/paper-$REV.jar"
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

  if [ "$PAPER_BUILD" = "latest" ]; then
    echo "Resolving latest Paper build."
    PARCHMENT_BUILD_JSON=$(curl -s https://papermc.io/api/v1/$SERVER_TYPE/$REV/$PAPER_BUILD)
    # Handle errors returned by the API.
    BUILD_JSON_ERROR=$(echo "$PARCHMENT_BUILD_JSON" | jq .error)
    if [ ! "null" = "$BUILD_JSON_ERROR" ]; then
      echo "Error: Failed to fetch Paper build info. Curl error: \"$BUILD_JSON_ERROR\"."
      exit 2
    fi

    PAPER_BUILD=$(echo "$PARCHMENT_BUILD_JSON" | jq .build | sed s\#\"\#\#g)
  fi

  declare -r SERVER_NAME="Paper revision $REV build $PAPER_BUILD"

  if [ ! -f "$PAPER_REVISION_JAR" ]; then
    echo "Downloading $SERVER_NAME."
    curl https://papermc.io/api/v1/$SERVER_TYPE/$REV/$PAPER_BUILD/download > "$PAPER_REVISION_JAR"
  else
    echo "$SERVER_NAME already downloaded."
  fi

  # Select the specified revision.
  ln -sf "$PAPER_REVISION_JAR" "$SERVER_JAR"
fi

if [ ! -f "$SERVER_JAR" ]; then
  echo "Error: Server JAR not found. This could be due to a build error, or a misconfiguration."
  exit 1
fi

# Make a separate config directory.
mkdir -p "$SERVER_CONFIG_DIRECTORY"
# Configuration files are not put in a seperate directory, but are instead scattered around the
# working directory. So that's a bit of an issue.
declare -ar CONFIGURATION_FILES=(
  # EULA.
  "eula.txt"
  # Vanilla server settings.
  # See: https://minecraft.gamepedia.com/Server.properties
  "server.properties"
  # Spigot settings.
  # See: https://www.spigotmc.org/wiki/spigot-configuration/
  "spigot.yml"
  # Bukkit settings.
  # See: https://bukkit.gamepedia.com/Bukkit.yml
  "bukkit.yml"
  # Bukkit help page settings.
  # https://bukkit.gamepedia.com/Help.yml
  "help.yml"
  # Bukkit command permissions.
  # https://bukkit.gamepedia.com/Permissions.yml
  "permissions.yml"
  # Bukkit custom commands.
  # See: https://bukkit.gamepedia.com/Commands.yml
  "commands.yml"
)
for FILE in "${CONFIGURATION_FILES[@]}"; do
  if [ ! -f "$FILE" ]; then
    touch "$SERVER_CONFIG_DIRECTORY/$FILE" || true
    ln -sf "$SERVER_CONFIG_DIRECTORY/$FILE" "$SERVER_DIRECTORY/$FILE" || true
  fi
done

# Make sure the command input file is clear.
rm -f "$COMMAND_INPUT_FILE"
# Make a named pipe for sending commands to the server. It is important that the permissions are 700
# because, if they were world writeable, any user could run a server command with administrator
# priviledges.
mkfifo -m700 "$COMMAND_INPUT_FILE"

# Enter the server directory because the Minecraft server checks the current directory for
# configuration files.
cd "$SERVER_DIRECTORY"
echo "Launching $SERVER_NAME."
# Start the launcher with the specified memory amounts. Execute it in the background, so that this
# script can still recieve signals.
# shellcheck disable=SC2086
java $JVM_OPTS -Xmx${GAME_MEMORY_AMOUNT} -Xms${GAME_MEMORY_AMOUNT} -jar "$SERVER_JAR" \
    nogui --plugins $SERVER_PLUGIN_DIRECTORY < <(tail -f "$COMMAND_INPUT_FILE") &
# Don't exit this script before the Java process does.
wait