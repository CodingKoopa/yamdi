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
# is pressed. Spigot handles this by quitting, without saving. SIGTERM is what is sent to a program
# when "docker stop" or "docker-compose" is used. SIGTERM is also used when an active Docker
# Compose session is quit with Ctrl+C (This does not work in regular Docker.).

# SIGINT and SIGTERM are expected to implemented similarly. Spigot implements them by shutting down
# the server, but without saving. The "stop" Bukkit command shuts down the server properly, and does
# save everything, so here the signals are trapped, and will intervene to run the "stop" command.
trap stop SIGINT
trap stop SIGTERM

declare -r SPIGOT_REVISION_JAR="$SPIGOT_DIRECTORY/spigot-$REV.jar"
declare -r SPIGOT_RUN_JAR="$SPIGOT_DIRECTORY/spigot.jar"

if [ -z "$REV" ]; then
  REV="latest"
fi
if [ -z "$BUILDTOOLS_MEMORY_AMOUNT" ]; then
  BUILDTOOLS_MEMORY_AMOUNT="1024M"
fi
if [ -z "$SPIGOT_MEMORY_AMOUNT" ]; then
  SPIGOT_MEMORY_AMOUNT="1024M"
fi

# Only build a new spigot.jar if manually enabled, or if a jar for this REV does not already exist.
if [ "$FORCE_SPIGOT_REBUILD" = true ] || [ ! -f "$SPIGOT_REVISION_JAR" ]; then
  echo "Building Spigot."
  # Build in a temporary directory.
  declare -r SPIGOT_BUILD_DIRECTORY=/tmp/spigot-build
  mkdir -p "$SPIGOT_BUILD_DIRECTORY"
  pushd "$SPIGOT_BUILD_DIRECTORY"
  # Download the latest BuildTools JAR.
  wget https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
  # Run BuildTools with the specified RAM, for the specified revision.
  # shellcheck disable=SC2086
  java $JVM_OPTS -Xmx${BUILDTOOLS_MEMORY_AMOUNT} -Xms${BUILDTOOLS_MEMORY_AMOUNT} \
      -jar BuildTools.jar --rev $REV
  # Copy the Spigot build to the Spigot directory.
  cp spigot-*.jar "$SPIGOT_REVISION_JAR"
  popd
  # Remove the build files to preserve space.
  rm -rf "$SPIGOT_BUILD_DIRECTORY"
fi

# Make a separate config directory.
mkdir -p "$SPIGOT_CONFIG_DIRECTORY"
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
  if [ ! -f $FILE ]; then
    touch "$SPIGOT_CONFIG_DIRECTORY/$FILE" || true
    ln -sf "$SPIGOT_CONFIG_DIRECTORY/$FILE" "$SPIGOT_DIRECTORY/$FILE" || true
  fi
done

# Select the specified revision.
ln -sf "$SPIGOT_REVISION_JAR" "$SPIGOT_RUN_JAR"

# Make sure the command input file is clear.
rm -f "$COMMAND_INPUT_FILE"
# Make a named pipe for sending commands to Spigot. It is important that the permissions are 700
# because, if they were world writeable, any user could run a Spigot command with administrator
# priviledges.
mkfifo -m700 "$COMMAND_INPUT_FILE"

# Enter the Spigot directory because the Minecraft server checks the current directory for
# configuration files.
cd "$SPIGOT_DIRECTORY"
# Start the launcher with the specified memory amounts. Execute it in the background, so that this
# script can still recieve signals.
# shellcheck disable=SC2086
java $JVM_OPTS -Xmx${SPIGOT_MEMORY_AMOUNT} -Xms${SPIGOT_MEMORY_AMOUNT} -jar "$SPIGOT_RUN_JAR" \
    nogui --plugins $SPIGOT_PLUGIN_DIRECTORY < <(tail -f "$COMMAND_INPUT_FILE") &
# Don't exit this script before the Java process does.
wait