#!/bin/bash

# Set the directory for the server installation to be kept.
export SERVER_DIRECTORY="/opt/server"
# Set the directory for the server host configuration to be kept.
export SERVER_CONFIG_HOST_DIRECTORY="/opt/server-config-host"
# Set the directory for the server host plugins to be kept.
export SERVER_PLUGINS_HOST_DIRECTORY="/opt/server-plugins-host"
# Set the directory for the command named pipe to be.
export COMMAND_INPUT_FILE="/tmp/server-commmand-input"

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

  # If the directory is empty or doesn't exist. An unmounted Docker volume should be an empty
  # directory.
  if [ -z "$(ls -A "$SOURCE_DIRECTORY")" ] || [ ! -d "$SOURCE_DIRECTORY" ]; then
    echo "No files to import."
    return 0
  fi

  echo "Making copy of host files."
  declare -r SOURCE_DIRECTORY_VCS="$SOURCE_DIRECTORY-copy"
  # Ensure that the VCS directory isn't present to begin with, because if it is then the source
  # directory will be copied inside of the VCS directory, effectively discarding any new changes.
  rm -rf "$SOURCE_DIRECTORY_VCS"
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
  git reset -q -- "$GIT_DIR"
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
    # Right now, reverse the input so it makes more sense.
    if [ "$DIST" = "oracle" ]; then
      # Condensed summaries aren't available on the Git version in the repos for the Oracle Java
      # image, so go with normal summaries.
      git diff --color -R --summary
    else
      # Condense the summary because otherwise the full contents of new additions will be
      # displayed.
      git diff --color -R --compact-summary
    fi
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

# Given a minimum, maximum and "both" value, generate a JVM memory option string. If both the
# min and max and set, they will be use respectively. If only one is set, it will be used for
# both.
# Arguments:
#   Number of minimum MB.
#   Number of maximum MB.
#   Number to be used for both minimum and maximum MB.
# Returns:
#   The generated JVM option string.
function generate-memory-opts() {
  MINIMUM="$1"
  MAXIMUM="$2"
  BOTH="$3"

  if [ -n "$MINIMUM" ] && [ -z "$MAXIMUM" ]; then
    OUTPUT="-Xms${MINIMUM} -Xmx${MINIMUM}"
  elif [ -z "$MINIMUM" ] && [ -n "$MAXIMUM" ]; then
    OUTPUT="-Xms${MAXIMUM} -Xmx${MAXIMUM}"
  elif [ -n "$BOTH" ]; then
    OUTPUT="-Xms${BOTH} -Xmx${BOTH}"
  else
    OUTPUT="-Xms1024M -Xmx1024M"
  fi

  # See the setting of most of these options, in the main script.
  if [ ! "$USE_SUGGESTED_JVM_OPTS" = false ]; then
    if [ "$JVM" = "openj9" ]; then
      if [ -n "$MAXIMUM" ]; then
        UPPER_BOUND="$MAXIMUM"
      elif [ -n "$BOTH" ]; then
        UPPER_BOUND="$BOTH"
      else
        UPPER_BOUND="1024"
      fi
      # Strip out the letter indicating the storage unit.
      UPPER_BOUND=${UPPER_BOUND//[!0-9]/}
      # Set the nursery minimum to 50% of the heap size from 25%, to allow more space for short
      # lived objects.
      OUTPUT+=" -Xmns$(("$UPPER_BOUND" / 2))M"
      # Set the nursery maximum to 80% of the heap size to allow the server to grow it.
      OUTPUT+=" -Xmnx$(("$UPPER_BOUND" * 4 / 5))M"
    fi
  fi

  echo "$OUTPUT"
}