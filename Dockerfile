# Set the base image to the official Alpine Linux image. This version is specified because the latest tag didn't pull
# a functioning manifest list for aarch64.
FROM alpine:3.8

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

# Install Java8
RUN apk add openjdk8-jre

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
ENV LEVEL=world \
  PVP=true \
  VDIST=10 \
  OPPERM=4 \
  NETHER=true \
  FLY=false \
  MAXBHEIGHT=256 \
  NPCS=true \
  WLIST=false \
  ANIMALS=true \
  HC=false \
  ONLINE=true \
  RPACK='' \
  DIFFICULTY=3 \
  CMDBLOCK=false \
  MAXPLAYERS=20 \
  MONSTERS=true \
  STRUCTURES=true \
  SPAWNPROTECTION=16

#ENV DYNMAP=true ESSENTIALS=false ESSENTIALSPROTECT=false PERMISSIONSEX=false CLEARLAG=false

#set default command
CMD trap 'exit' INT; /spigot_init.sh
