#!/bin/bash

# Set the directory for the server installation to be kept.
export SERVER_DIRECTORY="/opt/server"
# Set the directory for the server host configuration to be kept.
export SERVER_CONFIG_HOST_DIRECTORY="/opt/server-config-host"
# Set the directory for the server host plugins to be kept.
export SERVER_PLUGINS_HOST_DIRECTORY="/opt/server-plugins-host"
# Set the directory for the command named pipe to be.
export COMMAND_INPUT_FILE="/tmp/server-commmand-input"

# Prints a debug message, if enabled.
# Arguments:
#   - The message.
# Outputs:
#   - The formatted message.
function debug() {
  if [ "$YAMDI_DEBUG" = "true" ]; then
    printf "[$(date +%R:%S) DEBUG]: [YAMDI] %s\n" "$*"
  fi
}

# Prints an info message.
# Arguments:
#   - The message.
# Outputs:
#   - The formatted message.
function info() {
  printf "[$(date +%R:%S) INFO]: [YAMDI] %s\n" "$*"
}

# Prints a warning message.
# Arguments:
#   - The message.
# Outputs:
#   - The formatted message.
function warning() {
  printf "[$(date +%R:%S) WARNING]: [YAMDI] %s\n" "$*"
}

# Prints an error message.
# Arguments:
#   - The message.
# Outputs:
#   - The formatted message.
function error() {
  printf "[$(date +%R:%S) ERROR]: [YAMDI] %s\n" "$*"
}

# Initializes a new temporary Git directory, makes a commit for it, and merges its contents with a
# given directory, using Git. It's very important that, if Git will be used after this function be
# called, that `unset GIT_DIR GIT_WORK_TREE` is ran. For more details on the checkout method used
# here, see: https://gitolite.com/deploy.html
# Arguments:
#   - Path to the source directory.
#   - Path to the target directory.
# Outputs:
#   - Status messages.
# Variables Exported:
#   - GIT_DIR: Location of the Git directory.
#   - GIT_WORK_TREE: Location of the Git work tree.
function import_directory() {
  local -r source_directory=$1
  local -r target_directory=$2

  # If the directory is empty or doesn't exist. An unmounted Docker volume should be an empty
  # directory.
  if [ -z "$(ls -A "$source_directory")" ] || [ ! -d "$source_directory" ]; then
    warning "No files to import."
    return 0
  fi

  debug "Making copy of host files."
  local -r source_directory_vcs="$source_directory-copy"
  # Ensure that the VCS directory isn't present to begin with, because if it is then the source
  # directory will be copied inside of the VCS directory, effectively discarding any new changes.
  rm -rf "$source_directory_vcs"
  cp -R "$source_directory" "$source_directory_vcs"

  debug "Initializing Git repo."
  # Use a temporary Git directory. This reduces the need for maintining a repo externally, and
  # reduces any conflict with a preexisting repo.
  export GIT_DIR="$source_directory_vcs/.git-yamdi"
  # For now, use the source directory as Git's working directory, to copy the initial changes.
  export GIT_WORK_TREE="$source_directory_vcs"
  # Initialize the temporary directory, if it hasn't already been initialized.
  git init -q

  debug "Configuring Git repo."
  # git commit --author doesn't seem to work correctly here, so set the author info in its own
  # set of commands.
  git config user.name "YAMDI, with love ♥"
  git config user.email "codingkoopa@gmail.com"

  debug "Making Git commit."
  # Add all files from the directory from the stage. This also stages deletions.
  git add -A
  # Remove our temporary Git directory from the stage.
  git reset -q -- "$GIT_DIR"
  # Make a commit. This is necessary because otherwise, we can't really use this repo for anything.
  # Procede even if failed because that probably just means there haven't been any configuration
  # changes.
  COMMAND="git commit -m \"Automatically generated commit.\""
  if [ "$YAMDI_DEBUG" = "true" ]; then
    eval "$COMMAND" || true
  else
    eval "$COMMAND" >/dev/null || true
  fi

  debug "Switching Git working directory to target."
  # Pull the rug out from under Git - make it use the target directory.
  export GIT_WORK_TREE="$target_directory"

  # If the directory doesn't already exist, create it, and don't show the diff.
  if [ ! -d "$target_directory" ]; then
    info "Making new directory. No changes are being overwritten."
    mkdir -p "$target_directory"
  else
    info "Existing directory found. Changes that will be overwritten:"
    # Right now, reverse the input so it makes more sense (-R).
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

  debug "Updating server directory."
  # Update the directory with new changes. Procede if failed, because if no commit was made, then
  # there won't be a valid master branch to use.
  git checkout -q -f master || true
}

# Given two directories setup by import_directory(), compare them for changes.
# Arguments:
#   - Path to the source directory.
#   - Path to the target directory.
#   - Path to output the patch to.
# Outputs:
#   - Status messages.
# Variables Exported:
#   - GIT_DIR: Location of the Git directory.
#   - GIT_WORK_TREE: Location of the Git work tree.
function get_directory_changes() {
  local -r source_directory=$1
  local -r target_directory=$2
  local -r patch_path=$3

  export GIT_DIR="$source_directory-copy/.git-yamdi"
  export GIT_WORK_TREE="$target_directory"
  if [ ! -d "$GIT_DIR" ]; then
    info "No Git repo found. No changes."
  else
    info "Git repo found. Outputting changes to \"$patch_path\"."
    git diff >"$patch_path"
  fi
}

# Given a minimum, maximum and "both" value, generate a JVM memory option string. If both the
# min and max and set, they will be use respectively. If only one is set, it will be used for
# both.
# Arguments:
#   - Number of minimum MB.
#   - Number of maximum MB.
#   - Number to be used for both minimum and maximum MB.
# Outputs:
#   - The generated JVM option string.
function generate_memory_opts() {
  local -r minimum="$1"
  local -r maximum="$2"
  local -r both="$3"

  local output

  if [ -n "$minimum" ] && [ -z "$maximum" ]; then
    output="-Xms${minimum} -Xmx${minimum}"
  elif [ -z "$minimum" ] && [ -n "$maximum" ]; then
    output="-Xms${maximum} -Xmx${maximum}"
  elif [ -n "$both" ]; then
    output="-Xms${both} -Xmx${both}"
  else
    output="-Xms1024M -Xmx1024M"
  fi

  # See the setting of most of these options, in the main script.
  if [ ! "$YAMDI_USE_SUGGESTED_JVM_OPTS" = false ]; then
    if [ "$JVM" = "openj9" ]; then
      local upper_bound
      if [ -n "$maximum" ]; then
        upper_bound="$maximum"
      elif [ -n "$both" ]; then
        upper_bound="$both"
      else
        upper_bound="1024"
      fi
      # Strip out the letter indicating the storage unit.
      upper_bound=${upper_bound//[!0-9]/}
      # Set the nursery minimum to 50% of the heap size from 25%, to allow more space for short
      # lived objects.
      output+=" -Xmns$(("$upper_bound" / 2))M"
      # Set the nursery maximum to 80% of the heap size to allow the server to grow it.
      output+=" -Xmnx$(("$upper_bound" * 4 / 5))M"
    fi
  fi

  echo "$output"
}
