# Set the base image to the official OpenJDK image. 8 is an LTS release, with Alpine Linux support.
FROM openjdk:8-alpine

# Install the dependencies and clean the cache.
# - bash    Bash, for running the server startup script.
# - git     Git, for BuildTools to clone the repositories.
# - curl    Curl, for using the Paper build API.
# - jq      jq, for parsing the Paper API response.
RUN apk upgrade --update --no-cache && \
    apk add --update --no-cache \
      bash \
      git \
      curl \
      jq && \

# Create a mount point for the server installation directory and plugin directory.
VOLUME /opt/server /opt/server-config-host /opt/server-plugins-host

# Expose the Minecraft server port and Dynmap web port.
EXPOSE 25565 8123

# Set the container entrypoint to the startup script.
ENTRYPOINT ["/usr/bin/yamdi"]

# Add the server command running script to the image.
ADD ./cmd.sh /usr/bin/cmd
# Make the script executable.
RUN chmod +x /usr/bin/cmd
# Add the utility function script to the image.
ADD ./utils.sh /usr/lib/utils
# Make the script executable.
RUN chmod +x /usr/lib/utils
# Add the server launch Bash script to the image.
ADD ./yamdi.sh /usr/bin/yamdi
# Make the script executable.
RUN chmod +x /usr/bin/yamdi