# Set the base image to the official OpenJDK image. 8 is an LTS release, with Alpine Linux support.
FROM openjdk:8-alpine

# Install the dependencies.
# - bash    Bash, for running the Spigot startup script.
# - git     Git, for BuildTools to clone the repositories.
RUN apk upgrade --update --no-cache && \
    apk add --update bash git && \
    rm -rf /var/cache/apk/*

# Set the directory for the Spigot installation to be kept.
ENV SPIGOT_DIRECTORY /opt/spigot
# Set the directory for the command named pipe to be.
ENV COMMAND_INPUT_FILE_PATH=/tmp/spigot-commmand-input

# Add the Spigot launch Bash script to the image.
ADD ./spigot.sh /spigot.sh
# Add the Spigot command running script to the image.
ADD ./spigot_cmd.sh /spigot_cmd.sh

# Expose the Minecraft server port.
EXPOSE 25565
# Expose the Dynmap web port.
EXPOSE 8123

# Create a mount point for the Spigot installation directory.
VOLUME ["/opt/spigot"]

# Set the container entrypoint to the startup script.
ENTRYPOINT /spigot.sh
