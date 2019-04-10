# Minecraft server SPIGOT

[![Docker Automated build](https://img.shields.io/docker/automated/ashdev/minecraft-spigot.svg)](https://hub.docker.com/r/ashdev/minecraft-spigot)
[![Docker Stars](https://img.shields.io/docker/stars/ashdev/minecraft-spigot.svg)](https://hub.docker.com/r/ashdev/minecraft-spigot)
[![Docker Pulls](https://img.shields.io/docker/pulls/ashdev/minecraft-spigot.svg)](https://hub.docker.com/r/ashdev/minecraft-spigot)
[![Docker Build Status](https://img.shields.io/docker/build/ashdev/minecraft-spigot.svg)](https://hub.docker.com/r/ashdev/minecraft-spigot/builds)

**This image replace the old image: [ashdev/docker-spigot](https://hub.docker.com/r/ashdev/docker-spigot)**

## Minecraft 1.13 Update Aquatic

This docker image is ready to use the latest version of Minecraft (1.13 Update Aquatic)

### Available tags

All available tags are always listed [in Docker Hub](https://hub.docker.com/r/ashdev/minecraft-spigot/tags):

- `1.13`, `latest`: Latest server for Minecraft 1.13.
- `1.13-alpine`, `alpine`: Latest server using Alpine for Minecraft 1.13.

The plugins are using the latest version. In case of issue, disable them.

To use the version 1.13 of docker run

    docker run -d -e REV=1.13 -p 25565:25565 ashdev/minecraft-spigot:latest

## Description

This docker image provides a Minecraft Server with Spigot that will automatically download the latest stable version at startup.

To simply use the latest stable version, run

    docker run -d -p 25565:25565 ashdev/minecraft-spigot:latest

where the standard server port, 25565, will be exposed on your host machine.

If you want to serve up multiple Minecraft servers or just use an alternate port,
change the host-side port mapping such as

    docker run -p 25566:25565 ...

will serve your Minecraft server on your host's port 25566 since the `-p` syntax is
`host-port`:`container-port`.

Speaking of multiple servers, it's handy to give your containers explicit names using `--name`, such as

    docker run -d -p 25565:25565 --name mc ashdev/minecraft-spigot:latest

With that you can easily view the logs, stop, or re-start the container:

    docker logs -f mc
        ( Ctrl-C to exit logs action )

    docker stop mc

    docker start mc

## Interacting with the server

In order to attach and interact with the Minecraft server, add `-it` when starting the container, such as

    docker run -d -it -p 25565:25565 --name mc ashdev/minecraft-spigot:latest

With that you can attach and interact at any time using

    docker attach mc

and then Control-p Control-q to **detach**.

For remote access, configure your Docker daemon to use a `tcp` socket (such as `-H tcp://0.0.0.0:2375`)
and attach from another machine:

    docker -H $HOST:2375 attach mc

Unless you're on a home/private LAN, you should [enable TLS access](https://docs.docker.com/articles/https/).

## Run commands in the Minecraft servers

You can send commands in the server by calling

    docker exec mc /spigot_cmd.sh <command>

example:

    docker exec mc /spigot_cmd.sh op AshDevFr

## EULA Support

Mojang now requires accepting the [Minecraft EULA](https://account.mojang.com/documents/minecraft_eula). To accept add

    -e EULA=TRUE

such as

    docker run -d -it -e EULA=TRUE -p 25565:25565 ashdev/minecraft-spigot:latest

## Attaching data directory to host filesystem

In order to readily access the Minecraft data, use the `-v` argument
to map a directory on your host machine to the container's `/minecraft` directory, such as:

    docker run -d -v /path/on/host:/minecraft ...

When attached in this way you can stop the server, edit the configuration under your attached `/path/on/host`
and start the server again with `docker start CONTAINERID` to pick up the new configuration.

### In ubuntu you can specify the UID of the user

**NOTE**: By default, the files in the attached directory will be owned by the host user with UID of 1000.
You can use an different UID by passing the option:

    -e UID=1000

replacing 1000 with a UID that is present on the host.
Here is one way to find the UID given a username:

    grep some_host_user /etc/passwd|cut -d: -f3

## Running with Plugins

In order to add mods, you will need to attach the container's `/minecraft` directory
(see "Attaching data directory to host filesystem”).
Then, you can add mods to the `/path/on/host/mods` folder you chose. From the example above,
the `/path/on/host` folder contents look like:

```
/path/on/host
├── plugins
│   └── ... INSTALL PLUGINS HERE ...
├── ops.json
├── server.properties
├── whitelist.json
└── ...
```

If you add mods while the container is running, you'll need to restart it to pick those
up:

    docker stop $ID
    docker start $ID

## JVM Configuration

### General Options
The options passed to the Java Virtual Machine can be adjusted by setting the `JVM_OPTS` environment variable. This will be passed to both BuildTools and Spigot.

### Memory Options
The amount of memory to be used by the JVM for the BuildTools and Spigot can be separately set with the custom `BUILDTOOLS_MEMORY_AMOUNT` and `SPIGOT_MEMORY_AMOUNT` variables, for example:
```sh
docker run --env BUILDTOOLS_MEMORY_AMOUNT=800M --env SPIGOT_MEMORY_AMOUNT=1G
```
```yml
services:
  spigot:
    environment:
      BUILDTOOLS_MEMORY_AMOUNT: "800M"
      SPIGOT_MEMORY_AMOUNT: "1G"
```
Here, the device only has 2GB of RAM available. BuildTools needs at least approximately 700 MB of RAM. However, if 1 GB is used for BuildTools, the same amount is also used for the child Java processes that BuildTools spawns, effectively doubling the amount of RAM that Java uses overall. Therefore, on limited machines, it is wise to use as little RAM for BuildTools as possible. Since it will be probably be desired for more RAM to be used for Spigot itself, two separate variables are provided.

## Issues

If you have any problems with or questions about this image, please contact me by submitting a ticket through a [GitHub issue](https://github.com/AshDevFr/docker-spigot/issues)



Thanks to [nimmis](https://github.com/nimmis/docker-spigot) & [itzg](https://github.com/itzg/dockerfiles/tree/master/minecraft-server)
