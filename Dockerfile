# Set the base image to the official OpenJDK image. 8 is an LTS release, with Alpine Linux support.
FROM openjdk:8-alpine

# Install the dependencies and clean the cache.
# - bash    Bash, for running the server startup script.
# - git     Git, for BuildTools to clone the repositories.
# - curl    Curl, for using the Paper build API.
# - jq      jq, for parsing the Paper API response.
RUN apk upgrade --update --no-cache && \
    apk add --update bash git curl jq && \
    rm -rf /var/cache/apk/*

#RUN yum upgrade -y && \
#    yum install -y bash git curl jq && \

# Set the directory for the server installation to be kept.
ENV SERVER_DIRECTORY /opt/server
# Set the directory for the server host configuration to be kept.
ENV SERVER_CONFIG_HOST_DIRECTORY /opt/server-config-host
# Set the directory for the server host plugins to be kept.
ENV SERVER_PLUGINS_HOST_DIRECTORY /opt/server-plugins-host
# Set the directory for the command named pipe to be.
ENV COMMAND_INPUT_FILE=/tmp/server-commmand-input

# Expose the Minecraft server port and Dynmap web port.
EXPOSE 25565 8123

# Create a mount point for the server installation directory and plugin directory.
VOLUME /opt/server /opt/server-config-host /opt/server-plugins-host

# Set the container entrypoint to the startup script.
ENTRYPOINT ["/usr/bin/yamdi"]

# Add the server launch Bash script to the image.
ADD ./yamdi.sh /usr/bin/yamdi
# Make the script executable.
RUN chmod +x /usr/bin/yamdi
# Add the server command running script to the image.
ADD ./cmd.sh /usr/bin/cmd
# Make the script executable.
RUN chmod +x /usr/bin/cmd