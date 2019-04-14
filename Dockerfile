# Set the base image to the official OpenJDK image. 8 is an LTS release, with Alpine Linux support.
FROM openjdk:8-alpine

# Install the dependencies and clean the cache.
# - bash    Bash, for running the Spigot startup script.
# - git     Git, for BuildTools to clone the repositories.
RUN apk upgrade --update --no-cache && \
    apk add --update bash git && \
    rm -rf /var/cache/apk/*

# Set the directory for the Spigot installation to be kept.
ENV SPIGOT_DIRECTORY /opt/spigot
ENV SPIGOT_CONFIG_DIRECTORY /opt/spigot-config
ENV SPIGOT_PLUGIN_DIRECTORY /opt/spigot-plugins
# Set the directory for the command named pipe to be.
ENV COMMAND_INPUT_FILE=/tmp/spigot-commmand-input

# Add the Spigot launch Bash script to the image.
ADD ./spigot.sh /usr/bin/spigot
# Make the script exxecutable.
RUN chmod +x /usr/bin/spigot
# Add the Spigot command running script to the image.
ADD ./cmd.sh /usr/bin/cmd
# Make the script executable.
RUN chmod +x /usr/bin/cmd

# Expose the Minecraft server port and Dynmap web port.
EXPOSE 25565 8123

# Create a mount point for the Spigot installation directory and plugin directory.
VOLUME /opt/spigot /opt/spigot-config /opt/spigot-plugins

# Set the container entrypoint to the startup script.
ENTRYPOINT ["/usr/bin/spigot"]