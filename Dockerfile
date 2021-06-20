# Set a reasonable default value for the base image.
ARG YAMDI_BASE_IMAGE=adoptopenjdk/openjdk16:alpine-jre

# Source the specified base image.
FROM ${YAMDI_BASE_IMAGE}

# Install the dependencies:
# - bash    Bash, for running the server startup script.
# - git     Git, for BuildTools to clone the repositories.
# - curl    Curl, for using the Paper build API.
# - jq      jq, for parsing the Paper API response.
#
# For each of the package manager tests, we use the ">" redirector as opposed to the "&>" because sh
# seems to erroneously think that the command succeeded when it didn't.
RUN \
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
  yum -y update && \
  # Install the dependencies.
  yum -y install bash git curl jq && \
  # Clean the package manager cache.
  yum clean all; \
  \
  # Handle any other cases.
  else \
  echo "Error: Could not find a suitable package manager to use in this image." && \
  return 1; \
  fi

# Create a mount point for the server installation directory and plugin directory.
VOLUME /opt/server /opt/server-config-host /opt/server-plugins-host

# Expose the Minecraft server port and Dynmap web port.
EXPOSE 25565 8123

# Set the container entrypoint to the startup script.
ENTRYPOINT ["/usr/bin/yamdi"]

# Copy the server command running script to the image.
COPY ./cmd.sh /usr/bin/cmd
# Make the script executable.
RUN chmod +x /usr/bin/cmd
# Copy the utility function script to the image.
COPY ./utils.sh /usr/lib/utils
# Make the script executable.
RUN chmod +x /usr/lib/utils
# Copy the server launch Bash script to the image.
COPY ./yamdi.sh /usr/bin/yamdi
# Make the script executable.
RUN chmod +x /usr/bin/yamdi
