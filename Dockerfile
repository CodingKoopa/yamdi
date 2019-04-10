# Set the base image to the official OpenJDK image. 8 is an LTS release, with Alpine Linux support.
FROM openjdk:8-alpine

# Java Version and other ENV
ENV JAVA_VERSION_MAJOR=8 \
    JAVA_VERSION_MINOR=112 \
    JAVA_VERSION_BUILD=15 \
    JAVA_PACKAGE=server-jre \
    JAVA_HOME=/opt/jdk \
    PATH=${PATH}:/opt/jdk/bin \
    LANG=C.UTF-8

# Install dependencies
# TODO: Some of these can probably be reduced.
RUN apk upgrade --update && \
    apk add --update wget curl ca-certificates openssl bash git screen util-linux sudo shadow nss imagemagick && \
    update-ca-certificates

ENV APP_NAME=server
#default directory for SPIGOT-server
ENV SPIGOT_DIRECTORY /opt/spigot
ENV RUN_DIR /minecraft_run

RUN mkdir $RUN_DIR

ADD ./lib/scripts/spigot_init.sh /spigot_init.sh
ADD ./lib/scripts/spigot_run.sh /spigot_run.sh
ADD ./lib/scripts/spigot_cmd.sh /spigot_cmd.sh

RUN chmod +x /spigot_init.sh
RUN chmod +x /spigot_run.sh
RUN chmod +x /spigot_cmd.sh

EXPOSE 25565
EXPOSE 8123
VOLUME ["/opt/spigot"]

ENV MOTD A Minecraft Server Powered by Spigot & Docker
ENV REV latest

#set default command
CMD trap 'exit' INT; /spigot_init.sh
