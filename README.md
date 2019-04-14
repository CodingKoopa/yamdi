# Yet Another Spigot Docker Image

Yet Another Spigot Docker Image is a Docker image for running the Spigot Minecraft server software that aims to be as clean as possible while maintaining functionality. This is a fork of [this](https://github.com/AshDevFr/docker-spigot/) setup, but with many changes made with this philosphy in mind:
- The code for both the Docker image building and the script starting up Spigot should be understandable. Important design decisions should be properly documented.
- The code should be concise, combining statements where it makes sense.
- The code shouldn't do anything unnecessary.

The last point is particularly relevant. The original setup offers functionality for specifying server properties via environment variables (which does work very well), as well as running it as a `minecraft` user with restricted permissions. This image has both of these things stripped out because, as a system administrator, you are expected to:
- Use [bind mounts](https://docs.docker.com/storage/bind-mounts/) to bind the configuration volume and manually edit the configuration that way.
- Use a [user namespace](https://docs.docker.com/engine/security/userns-remap/) to have Spigot run as an unprivledged user.

An additional motivation for making things light and clean is that this image is particularly made to be very portable, that is, able to run on embedded devices like a Raspberry Pi as well as a traditional server.

These decisions were made because of how, ultimately, Docker does handle these things better and/or than a container-level mechanism can. To reiterate, if you're an end-user-ish person looking for a setup that just works with little finicking, then I would recommend the aforementioned setup. If you are someone that does care about the underlying code and security, then this might be a good setup.

## Usage
In this sections, excerpts from both a Bash command line with Docker and a [Docker Compose](https://docs.docker.com/compose/overview/) `yml` configuration, with `version: "3.7"`.

### Starting Spigot
Images for YASDI are not provided, so it must be built:
```sh
docker build . -t spigot
```
```yml
services:
  spigot:
    build: .
```
As the `Dockerfile` is (deliberately) placed in the root of this repository, this repository can somewhat cleanly be added as a submodule for another repo if you're using this in a larger setup.
```yml
services:
  spigot:
    build: ./Spigot
```
It is also worth noting that the OpenJDK base image is multiarch, so this should work seamlessly across platforms.

### Spigot Data
YASDI exposes three volumes:
- `/opt/spigot`, the Spigot installation. This contains the Spigot `JAR`, some world-specific configurations, and world data.
- `/opt/spigot-config`, the Spigot config. This contains server-related configurations. The configurations are handpicked by the startup script, and so it is possible that a configuration is left out of here.
- `/opt/spigot-plugins`, the Spigot plugins. This contains plugins that are to be loaded by Spigot, and their own configurations.

### Sending Commands to Spigot
YASDI comes with an helper script (thanks @AshDevFr) to send commands to Spigot while it is running in another container.
```sh
docker exec spigot cmd $COMMAND
```
```sh
docker-compose exec spigot cmd $COMMAND
```
A command that can be used here (see `help` for more commands) is `version`.
```sh
docker exec spigot cmd version
```
```sh
docker-compose exec spigot cmd version
```
This should print something like `This server is running CraftBukkit version git-Spigot-f09662d-7c395d4 (MC: 1.13.2) (Implementing API version 1.13.2-R0.1-SNAPSHOT)` (It is supposed to say `CraftBukkit`.).

### Shutting Spigot Down
YASDI properly traps the SIGINT and SIGTERM signals (for more info on when these are passed, see the Spigot startup script), and properly shuts down Spigot (saving worlds, shutting down plugins, etc.) when they are recieved.

### JVM Configuration

#### General Options
The options passed to the Java Virtual Machine can be adjusted by setting the `JVM_OPTS` environment variable. This will be passed to both BuildTools and Spigot.

#### Memory Options
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

## Credits
Thanks to [AshDevFr](https://github.com/AshDevFr/docker-spigot/), [nimmis](https://github.com/nimmis/docker-spigot), and [itzg](https://github.com/itzg/dockerfiles/tree/master/minecraft-server) for their work with running Spigot in Docker.

## License
This project is licensed under the MIT license.