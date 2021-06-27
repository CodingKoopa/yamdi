# syntax=docker/dockerfile:1.2

# Set a reasonable default value for the base image.
ARG YAMDI_BASE_IMAGE=adoptopenjdk/openjdk16:jre

# Source the specified base image.
FROM ${YAMDI_BASE_IMAGE}

# For each of the command tests, we use the ">" redirector as opposed to the "&>" because sh seems
# to erroneously think that the command succeeded when it didn't.
RUN \
  # Quit on error (this makes it unnecessary to use "&&"), disallow undefined variable substitution,
  # and print commands as they are executed.
  set -eux; \
  \
  # Install the dependencies:
  # - bash    Bash, for running the server startup script.
  # - git     Git, for BuildTools to clone the repositories.
  # - curl    Curl, for downloading Spigot BuildTools and using the Paper build API.
  # - jq      jq, for parsing the Paper API response.
  #
  \
  # Handle Advanced Package Tool, used on Debian, Ubuntu, and other Debian derivations. Both apt-get
  # and apt are usually available; the former is preferable for scripting purposes.
  if command -v apt-get > /dev/null; then \
  # Indicate that no input can be given. This is for any tools that may be called by apt-get; for
  # apt-get itself we still have to use the command line argument.
  export DEBIAN_FRONTEND=noninteractive; \
  # Re-synchronize the package index, because the base image may not be caught up.
  apt-get update; \
  # Install the newest versions of all packages.
  apt-get --assume-yes upgrade; \
  # Install the dependencies, without recommended packages.
  apt-get --assume-yes --no-install-recommends install bash git curl jq; \
  # Clear the local repository of retrieved package files.
  apt-get clean; \
  # Remove the package index cache.
  rm --recursive --force /var/lib/apt/lists/*; \
  \
  # Handle Alpine Package Keeper, used on Alpine Linux.
  elif command -v apk > /dev/null; then \
  # Update the package index, because the official Alpine Linux package does not ship with one,
  # since it would get stale quickly.
  apk update; \
  # Upgrade the currently installed packages, because the base image may not be caught up.
  apk upgrade; \
  # Install the dependencies.
  apk add bash git curl jq; \
  # Remove the package index cache.
  rm --recursive --force /var/cache/apk/*; \
  \
  # Handle Dandified YUM, used by newer versions of RHEL and Fedora.
  elif command -v dnf > /dev/null; then \
  \
  # Update the currently installed packages, limited to upgrades that provide a bugfix, enhancement,
  # or fix for a security issue.
  dnf --assumeyes --nodocs upgrade-minimal; \
  # Install the dependencies, without recommended packages.
  dnf --assumeyes --nodocs --setopt=install_weak_deps=False install bash git curl jq; \
  # Clean the package manager cache.
  dnf clean all; \
  \
  # Handle Yellowdog Updater, Modified, used by Oracle Linux.
  elif command -v yum > /dev/null; then \
  # Update the currently installed packages, because the base image may not be caught up.
  yum --assumeyes update; \
  # Install the dependencies.
  yum --assumeyes --setopt=tsflags=nodocs install bash git curl jq; \
  # Clean the package manager cache.
  yum clean all; \
  \
  # Handle any other cases.
  else \
  echo >&2 "Error: Could not find a suitable package manager to use in this image."; \
  return 1; \
  fi; \
  \
  # Add the non-root group that we'll add the non-root user to. We create the group in a separate
  # step in order to set its GID manually.
  #
  # This non-root user will be a system user with a static UID and GID that should never conflict
  # with any existing user or group on the host system. See here for more info:
  # https://github.com/hexops/dockerfile#use-a-static-uid-and-gid.
  #
  # When it comes to Debian and friends, confusingly, both "addgroup" and "groupadd" exist, as well
  # as their "user" counterparts. Generally, the former is preferrable, as a higher level utiltiy.
  #
  # In Alpine Linux, the former is the only option.
  #
  # See here for more info: https://unix.stackexchange.com/q/121071.
  \
  # Handle addgroup.
  if command -v addgroup > /dev/null; then \
  addgroup --gid 10001 --system nonroot; \
  # Handle groupadd.
  elif command -v groupadd > /dev/null; then \
  groupadd --gid 10001 --system nonroot; \
  # Handle any other cases.
  else \
  echo >&2 "Error: Could not find a way to add a group to use in this image."; \
  return 1; \
  fi; \
  \
  # Add the non-root user that we'll add the non-root user to. See here for more info:
  # https://stackoverflow.com/a/55757473.
  \
  # Handle adduser.
  if command -v adduser > /dev/null; then \
  # We need to try a couple of different commands, because the BusyBox implementation of adduser
  # only supports specifying a group via "--ingroup". This option is supported by *most* other
  # adduser impls, but not, for example, that which is included with CentOS.
  adduser --uid 10001 --ingroup nonroot --system --home /home/nonroot nonroot || \
  adduser --uid 10001 --gid 10001 --system --home /home/nonroot nonroot; \
  \
  # Handle useradd.
  elif command -v useradd > /dev/null; then \
  useradd --uid 10001 --no-user-group --gid 10001 --system --create-home nonroot; \
  \
  # Handle any other cases.
  else \
  echo >&2 "Error: Could not find a way to add a user in this image."; \
  return 1; \
  fi; \
  \
  # Create the user subdirectory that the non-root user will be using. It's necessary to create and
  # own the "server" subdirectory ahead of time because, by default, the volume will be mounted and
  # owned by root.
  \
  mkdir --parents /opt/yamdi/user/server; \
  # The presence of this file indicates that no volume has been mounted here, which is really bad
  # because it means that server data will not persist.
  touch /opt/yamdi/user/server/volume-not-mounted; \
  chown -R nonroot:nonroot /opt/yamdi/user;

# Copy the Git configuration into the non-root user's home directory.
COPY --chown=nonroot:nonroot src/.gitconfig /home/nonroot/

# Change to the non-root user when running the container.
USER nonroot

# Run from the server directory because we will use Git to update files here, and the Minecraft
# server will check the current directory for configuration files.
WORKDIR /opt/yamdi/user/server

# Create a mount point for the server installation directory and plugin directory.
VOLUME /opt/yamdi/user/server /opt/yamdi/server-config-host /opt/yamdi/server-plugins-host

# Expose the Minecraft server port and Dynmap web port.
EXPOSE 25565 8123

# Append the YAMDI directory to the path to make it accessible.
ENV PATH=/opt/yamdi:$PATH

# Set the container entrypoint to the startup script.
ENTRYPOINT ["yamdi"]

# Copy the scripts into the YAMDI directory. This step is done last to get the fastest builds while
# developing YAMDI.
COPY src/yamdi src/cmd src/yamdi-utils /opt/yamdi/
