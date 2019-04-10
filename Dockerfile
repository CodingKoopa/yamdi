# Set the base image to the official OpenJDK image. 8 is an LTS release, with Alpine Linux support.
FROM openjdk:8-alpine

# Install dependencies
# TODO: Some of these can probably be reduced.
RUN apk upgrade --update && \
    apk add --update wget curl ca-certificates openssl bash git screen util-linux sudo shadow nss imagemagick && \
    update-ca-certificates

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

#set default command
CMD trap 'exit' INT; /spigot_init.sh
