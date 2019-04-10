#!/bin/bash
set -e

# Some variables are mandatory.
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
if [ "$FORCE_SPIGOT_REBUILD" = true ] || [ ! -f $SPIGOT_DIRECTORY/spigot-$REV.jar ]; then
  echo "Building Spigot."
  # Build in a temporary directory.
  declare -r SPIGOT_BUILD_DIRECTORY=/tmp/spigot-build
  mkdir -p "$SPIGOT_BUILD_DIRECTORY"
  pushd "$SPIGOT_BUILD_DIRECTORY"
  # Download the latest BuildTools JAR.
  wget https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
  # Run BuildTools with the specified RAM, for the specified revision.
  java $JVM_OPTS -Xmx${BUILDTOOLS_MEMORY_AMOUNT} -Xms${BUILDTOOLS_MEMORY_AMOUNT} -jar BuildTools.jar --rev $REV
  # Copy the Spigot build to the Spigot directory.
  cp spigot-*.jar "$SPIGOT_DIRECTORY/spigot-$REV.jar"
  popd
  # Remove the build files to preserve space.
  rm -rf "$SPIGOT_BUILD_DIRECTORY"
  # Make a plugin directory.
  mkdir -p $SPIGOT_DIRECTORY/plugins
fi

# Remove any preexisting build.
rm -f $SPIGOT_DIRECTORY/spigot.jar
# Select the specified revision.
ln -s $SPIGOT_DIRECTORY/spigot-$REV.jar $SPIGOT_DIRECTORY/spigot.jar

# Make sure the command input file is clear.
rm -f "$COMMAND_INPUT_FILE_PATH"
# Make a named pipe for sending commands to Spigot. It is important that the permissions are 700 because, if they were
# world writeable, any user could run a Spigot command with administrator priviledges.
mkfifo -m700 "$COMMAND_INPUT_FILE_PATH"
# Enter the Spigot directory because the Minecraft server checks the current directory for configuration files.
cd $SPIGOT_DIRECTORY/
# Start the launcher with the specified memory amounts.
java $JVM_OPTS -Xmx${SPIGOT_MEMORY_AMOUNT} -Xms${SPIGOT_MEMORY_AMOUNT} -jar spigot.jar nogui \
    < <(tail -f "$COMMAND_INPUT_FILE_PATH")