# syntax=docker/dockerfile:1.2

# Set a reasonable default value for the base image.
ARG YAMDI_BASE_IMAGE=adoptopenjdk/openjdk16:alpine-jre

# Source the specified base image.
FROM ${YAMDI_BASE_IMAGE}

RUN \
  # Install the dependencies:
  # - bash    Bash, for running the server startup script.
  # - git     Git, for BuildTools to clone the repositories.
  # - curl    Curl, for downloading Spigot BuildTools and using the Paper build API.
  # - jq      jq, for parsing the Paper API response.
  #
  # For each of the package manager tests, we use the ">" redirector as opposed to the "&>" because sh
  # seems to erroneously think that the command succeeded when it didn't.
  \
  # Handle Alpine Package Keeper, used on Alpine Linux.
  if command -v apk > /dev/null; then \
  # Update the package index, because the official Alpine Linux package does not ship with one,
  # since it would get stale quickly.
  apk update && \
  # Upgrade the currently installed packages, because the base image may not be caught up.
  apk upgrade && \
  # Install the dependencies.
  apk add bash git curl jq && \
  # Remove the package index cache.
  rm -rf /var/cache/apk/*; \
  \
  # Handle Yellowdog Updater, Modified, used by Oracle Linux.
  elif command -v yum > /dev/null; then \
  # Update the currently installed packages, because the base image may not be caught up.
  yum --assumeyes update && \
  # Install the dependencies.
  yum --assumeyes install bash git curl jq && \
  # Clean the package manager cache.
  yum clean all; \
  \
  # Handle any other cases.
  else \
  echo "Error: Could not find a suitable package manager to use in this image." && \
  return 1; \
  fi && \
  \
  # Add the non-root group that we'll add the non-root user to. This is a system user with a static
  # UID and GID that should never conflict with any existing user or group on the host system. See
  # here for more info: https://github.com/hexops/dockerfile#use-a-static-uid-and-gid.
  #
  # Confusingly, both "addgroup" and "groupadd" exist, as well as their "user" counterparts. On
  # Alpine (which we put first), the former is the only option. On Debian and most Debian,
  # derivations, both are present, and it doesn't matter very much for our purposes which one is
  # used.
  \
  # Handle addgroup.
  if command -v addgroup > /dev/null; then \
  addgroup --gid 10001 --system nonroot; \
  # Handle groupadd.
  elif command -v groupadd > /dev/null; then \
  groupadd --gid 10001 --system nonroot; \
  # Handle any other cases.
  else \
  echo "Error: Could not find a way to add a group in this image." && \
  return 1; \
  fi && \
  \
  # Add the non-root user that we'll add the non-root user to.
  \
  # Handle adduser.
  if command -v adduser > /dev/null; then \
  # See here (https://stackoverflow.com/a/55757473) for more info about this command.
  adduser --uid 10001 --ingroup nonroot --system --no-create-home --gecos "" nonroot; \
  \
  # Handle useradd.
  elif command -v useradd > /dev/null; then \
  useradd --uid 10001 --no-user-group --gid 10001 --system nonroot; \
  \
  # Handle any other cases.
  else \
  echo "Error: Could not find a way to add a user in this image." && \
  return 1; \
  fi && \
  \
  # Create the user subdirectory that the non-root user will be using.
  \
  mkdir --parents /opt/yamdi/user && \
  chown nonroot:nonroot /opt/yamdi/user

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
COPY yamdi cmd yamdi-utils /opt/yamdi/
