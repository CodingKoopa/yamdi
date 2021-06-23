# Yet Another Minecraft Docker Image

Yet Another Minecraft Docker Image is a Docker image for running the Spigot and Paper Minecraft server software that aims to do everything securely and tactfully. This is a fork of [this](https://github.com/AshDevFr/docker-spigot/) setup, but with many changes made with this philosophy in mind:
- The code for both the Docker image building and the script starting up the server should be understandable. Important design decisions should be properly documented.
- The code should be concise, combining statements where it makes sense.
- The code shouldn't do anything unnecessary.

The last point is particularly relevant. The original setup offers functionality for specifying server properties via environment variables (which does work very well), as well as running it as a `minecraft` user with restricted permissions. This image has both of these things stripped out because, as a system administrator, you are expected to:
- Use [bind mounts](https://docs.docker.com/storage/bind-mounts/) to bind the configuration volume and manually edit the configuration that way.
- Use a [user namespace](https://docs.docker.com/engine/security/userns-remap/) to have the server run as an unprivileged user.

These decisions were made because of how, ultimately, Docker does handle these things better and/or than a container-level mechanism can. To reiterate, if you're an end-user type person looking for a setup that just works with little finicking, then I would recommend the aforementioned setup. If you are someone that does care about the underlying code and security, then this might be a good setup. YAMDI is carefully designed to be secure, work in many different environments, and be customizeable.

## Usage
In these sections, excerpts from both a Bash command line with Docker and a [Docker Compose](https://docs.docker.com/compose/overview/) `yml` configuration, with `version: "3.7"`. Reading through this manual is recommended, to take full advantage of what YAMDI has to offer.

### Starting the Server

#### Choosing an Image
There are a couple of options for the YAMDI image to use:
- Use a prebuilt image with a preselected common Java base image.
- Build YAMDI yourself with whichever Java base image you want.

##### Prebuilt YAMDI (OUTDATED)
Images for YAMDI are provided for `amd64`, `arm32v7`,  and `arm64v8` (`arm64`, `aarch64`). These prebuilt images can be obtained from the [GitLab Container Registry](https://gitlab.com/help/user/packages/container_registry/index). These are the most important tags:
- `stable-hotspot`: The latest release of YAMDI, with the HotSpot JVM.
- `stable-openj9` The latest release of YAMDI, with the OpenJ9 JVM.
- `latest-hotspot`: The latest commit of YAMDI, with the HotSpot JVM.
- `latest-openj9`: The latest commit of YAMDI, with the OpenJ9 JVM.

For more info on HotSpot and OpenJ9, see [Java Distributions](#java-distributions).
```sh
docker run registry.gitlab.com/codingkoopa/yamdi/amd64:stable-hotspot
```
```yml
services:
  yamdi:
    image: registry.gitlab.com/codingkoopa/yamdi/amd64:stable-hotspot
```
```yml
services:
  yamdi:
    build:
      context: ./yamdi
      dockerfile: yamdi/Dockerfile.openjdk.hotspot
```
It is also worth noting that the OpenJDK base image is multiarch, so this should work seamlessly across platforms. To build for a platform other than `amd64`, you must set the `YAMDI_TARGET_ARCH` variable, e.g. `--build-arg YAMDI_TARGET_ARCH="arm64v8"`.

It may also be desirable to have the server restart if it crashes.
```sh
docker run --restart on-failure
```
```yml
services:
  yamdi:
    restart: on-failure
```

##### Building YAMDI

###### Obtaining the Source Code
In order to build a YAMDI image, you need a copy of this repository. If you don't have one, you can clone it with Git:
```sh
git clone https://gitlab.com/CodingKoopa/yamdi.git
```
Or, perhaps you're in a more limited environment that doesn't have Git:
```sh
curl -O https://gitlab.com/CodingKoopa/yamdi/-/archive/master/yamdi-master.tar.gz
tar xzf yamdi-master.tar.gz
```
Or, maybe you prefer wget:
```sh
wget https://gitlab.com/CodingKoopa/yamdi/-/archive/master/yamdi-master.tar.gz
tar xzf yamdi-master.tar.gz
```

If you would rather use a tagged release (if unsure, you don't), rather than the latest code, you can switch to it if using Git:
```sh
git checkout tags/1.0.3
```
Or, if using wget or curl, download the source code tarball from the [releases page](https://gitlab.com/CodingKoopa/yamdi/-/releases):
```sh
curl -O https://gitlab.com/CodingKoopa/yamdi/-/archive/v1.0.0/yamdi-v1.0.0.tar.gz
tar xzf yamdi-v1.0.0.tar.gz
```
With wget:
```sh
wget https://gitlab.com/CodingKoopa/yamdi/-/archive/v1.0.0/yamdi-v1.0.0.tar.gz
tar xzf yamdi-v1.0.0.tar.gz
```

###### Building the Image
The image is built using the `docker build` command. To build an image and tag it as `yamdi` so that it's not a dangling image:
```sh
docker build -t yamdi .
```
```yaml
services:
  yamdi:
    build:
      context: .
      image: yamdi
```

As the `Dockerfile`s are placed in the root of this repository, this repository could be added as a submodule for, say, a server dotfile repo, and then built like so:
```sh
docker build -t yamdi -f yamdi/Dockerfile ./yamdi
```
```yaml
services:
  yamdi:
    build:
      context: ./yamdi
      dockerfile: yamdi/Dockerfile
      image: yamdi
```

The YAMDI Dockerfile is designed to adapt to whatever base image you give it. You can specify what base image you want to use by setting the `YAMDI_BASE_IMAGE` build-time variable to the full tag referring to the Java image you want to use. To see a vast documentation of your options, see [JavaDistributions.md](JavaDistributions.md).
```sh
docker build --build-arg YAMDI_BASE_IMAGE=adoptopenjdk/openjdk16:alpine-jre
```
```yaml
services:
  yamdi:
    build:
      args:
      - YAMDI_BASE_IMAGE=adoptopenjdk/openjdk16:alpine-jre
```

### Server Type
The type of server can be specified by setting the `YAMDI_SERVER_TYPE` environment variable. Currently supported values are `spigot` (default) and `paper`, case sensitive.
```sh
docker run --env YAMDI_SERVER_TYPE=paper
```
```yml
services:
  yamdi:
    environment:
      YAMDI_SERVER_TYPE: "paper"
```

### Server Version
The target revision, or game version, can be adjusted by setting the `YAMDI_REV` variable either to `latest` (default) or a supported game version. Setting it to a version is recommended because of how plugins may not work on newer versions.
```sh
docker run --env YAMDI_REV=1.14.1
```
```yml
services:
  yamdi:
    environment:
      YAMDI_REV: "1.14.1"
```
For Paper, `YAMDI_PAPER_BUILD` (a build for a particular revision) can be set in the same way.

### Server Data
YAMDI exposes three volumes:
- `/opt/yamdi/user/server`, the server installation. This contains the server `JAR`, some world-specific configurations, and world data.
- `/opt/yamdi/server-config-host`, the server configuration. This contains server-related configurations.
- `/opt/yamdi/server-plugins-host`, the server plugins. This contains plugins that are to be loaded by the server, and their own configurations.

`/opt/yamdi/user/server` must be mounted in order for server data to persist. YAMDI enforces this, but [Docker's default behavior of copying files from the container into an empty volume](https://docs.docker.com/storage/#tips-for-using-bind-mounts-or-volumes) breaks this detection, thus we specify the `nocopy` volume option.

The other volumes are technically optional, but recommended for reasons that will be explained.

```sh
docker run --mount type=volume,source=mc-server-data,target=/opt/server,volume-opt=nocopy=true --mount type=bind,source=./mc-config,target=/opt/server-config-host --mount type=bind,source=./mc-plugins,target=/opt/server-plugins-host
```
```yml
services:
  yamdi:
    volumes:
      - type: volume
        source: mc-server-data
        target: /opt/yamdi/user/server
        volume:
          nocopy: true
      - type: bind
        source: ./mc-config
        target: /opt/yamdi/server-config-host
      - type: bind
        source: ./mc-plugins
        target: /opt/yamdi/server-plugins-host
```
The `/opt/yamdi/server-config-host` and `/opt/yamdi/server-plugins-host` volumes are particularly interesting. If they are mounted, then YAMDI will use Git to deploy them to `/opt/yamdi/user/server`.

The technical details of how YAMDI implements this isn't strictly required for usage, but is educational to have an understanding of. When YAMDI is starting up, it will first copy the contents of the host directory bind mount to another location, within the temporary container filesystem. In some cases this is necessary because, in order for Git to function, even if r/w access to the files isn't needed, Git still requires it. This is necessary when user namespace remapping is being used, and the user running YAMDI does not have r/w access to the original files. In YAMDI's copy of the directory, a Git repository is established, and a commit is made containing the changes (Given the nature of an initial commit, this is every file creation.). Then, using the `git checkout` deploy technique from [here](https://gitolite.com/deploy.html), YAMDI establishes a bare repository in `/opt/yamdi/user/server` and deploys to there. Both during the deploy, and during shutdown, YAMDI will execute `git diff` (With the exception of when an initial run is detected, because then a diff would be overwhelming.). The former of the two `diff`s is condensed for brevity, and the latter is forwarded to a patch file in the volume, as to not spam the log.

Given these details, there are multiple results and further specifications that should be understood:
- When initially deploying, and shutting down, the changes between the server configuration, and the host configuration will be printed. The purpose of this is, respectively, to understand what changes will be made, and what changes the server has made to the files that you may want to consider adding to your configuration. This is especially useful when the server software has introduced a new configuration option.
  - A pitfall with this is that `server.properties` will constantly be updated with a timestamp, and reordering of its properties, and thus it is a false positive. This is mitigated with [Ignore `server.properties`](#ignore-serverproperties`)
- Files in `/opt/yamdi/user/server` that are not in the host directory will be left as-is.
- Files in `/opt/yamdi/user/server` that have changed versions in the host directory will be updated.
- Files in `/opt/yamdi/user/server` that have been deleted in the host directory will **not** be deleted. This is a limitation of how YAMDI's temporary Git directory works, in that it only tracks file creations. To remedy this, `JAR`s in the root server plugin directory will be removed before the import process, to avoid any duplicate plugins of different versions.
- Permissions of files in the host directory will not be retained. The purpose/desirableness of this is that it makes the files safe for YAMDI to write to.
- As a result of YAMDI is using its own Git directory, it will neither not collide with any preexisting Git repository, nor require any Git setup.

To get started, first you should mount `/opt/yamdi/user/server`, and let the server run and exit due to not having the EULA accepted, and then set `eula` to `true` in the docker volume. After rerunning the server, and letting it generate configuration files, you can then copy them to your preferred location, and bind them mount to YAMDI as shown in the above examples. When running with the bind mounts properly setup YAMDI will replace the generated configuration files with the new ones.

After adding your configuration files, and letting YAMDI run with them, your configuration directory (similar to plugin directory) will look something like this:
```
bukkit.yml
commands.yml
eula.txt
.git-yamdi
help.yml
paper.yml
permissions.yml
server.properties
spigot.yml
```
For help with configuring these files for optimal performance, see [this](https://www.spigotmc.org/threads/guide-server-optimization%E2%9A%A1.283181/) thread.

### Using the Git Patch
As the server runs, and updates bring new configuration entries, the server itself will make changes to the configuration files. The automation of writing these changes back to the host can be done with a host script with something like this:
```sh
#!/bin/bash
set -e
VOLUME_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' mc-server-data)
sudo cp "$VOLUME_PATH"/{config,plugins}.patch .
(
  cd mc-config
  patch -p1 <../config.patch
)
(
  cd mc-plugins
  patch -p1 <../plugins.patch
)
rm {config,plugins}.patch
```

#### Ignore `server.properties`
The `server.properties` configuration file is internally stored as a [`Map`](https://docs.oracle.com/en/java/javase/12/docs/api/java.base/java/util/Map.html), therefore it does not have any ordering. As a result, the order of the file is random, and as such brings up false positives when put in a Git repository. This behavior can be disabled by setting `YAMDI_IGNORE_SERVER_PROPERTY_CHANGES` to false, although this shouldn't be done unless you have good reason to.

### Server Ports
The Minecraft Server port can be opened by exposing port `25565`.
```sh
docker run --expose 25565
```
```yml
services:
  yamdi:
    ports:
      - "25565:25565"
```

### JVM Configuration

#### General Options
The options passed to the Java Virtual Machine can be adjusted by setting the `JVM_OPTS` environment variable. This will be passed to both BuildTools and the server.

#### Memory Options
The amount of memory to be used by the JVM for the BuildTools and the server can be separately set with the custom `YAMDI_BUILDTOOLS_MEMORY_AMOUNT` and `YAMDI_GAME_MEMORY_AMOUNT` variables, for example:
```sh
docker run --env YAMDI_BUILDTOOLS_MEMORY_AMOUNT=800M --env YAMDI_GAME_MEMORY_AMOUNT=1G
```
```yml
services:
  yamdi:
    environment:
      YAMDI_BUILDTOOLS_MEMORY_AMOUNT: "800M"
      YAMDI_GAME_MEMORY_AMOUNT: "1G"
```
Here, the device only has 2GB of RAM available. BuildTools needs at least approximately 700 MB of RAM. However, if 1 GB is used for BuildTools, the same amount is also used for the child Java processes that BuildTools spawns, effectively doubling the amount of RAM that Java uses overall. Therefore, on limited machines, it is wise to use as little RAM for BuildTools as possible. Since it will be probably be desired for more RAM to be used for the server itself, two separate variables are provided.

These variables will be assuming that you want to set the maximum and minimum memory amounts as the same, as this is usually desirable. However, `YAMDI_BUILDTOOLS_MEMORY_AMOUNT_MIN` and `YAMDI_BUILDTOOLS_MEMORY_AMOUNT_MAX`, as well as equivalents for `YAMDI_GAME_MEMORY_AMOUNT` are usable. If only one out of the `MIN` and `MAX` are provided, then it will be used for both.

If nothing is specified, YAMDI defaults to a safe 1GB for both.

#### Experimental Options
By default, for HotSpot images, YAMDI applies experimental JVM options [suggested by Aiker](https://mcflags.emc.gs/) for performance. For OpenJ9 images, [Tux's JVM options](https://steinborn.me/posts/tuning-minecraft-openj9/) are used. This behavior can be disabled by setting `YAMDI)YAMDI_USE_SUGGESTED_JVM_OPTS` to false, although this shouldn't be done unless you have good reason to.

### Sending Commands to the Server
YAMDI comes with an helper script (thanks @AshDevFr) to send commands to the server while it is running in another container.
```sh
docker exec yamdi cmd $COMMAND
```
```sh
docker-compose exec yamdi cmd $COMMAND
```
A command that can be used here (see `help` for more commands) is `version`.
```sh
docker exec yamdi cmd version
```
```sh
docker-compose exec yamdi cmd version
```
This should print something like `This server is running CraftBukkit version git-Spigot-f09662d-7c395d4 (MC: 1.13.2) (Implementing API version 1.13.2-R0.1-SNAPSHOT)` (It is supposed to say `CraftBukkit`.).

### Shutting the Server Down
YAMDI properly traps the SIGINT and SIGTERM signals (sent when running `docker stop` / `docker-compose down` / `docker-compose stop` or sending `Ctrl` + `C` in a `docker-compose` session), and properly shuts down the server (saving worlds, shutting down plugins, etc.) when they are received.

Conversely, when the server shuts down, the exit code of YAMDI will be equivalent to the exit code of the Java process, therefore YAMDI is compatible with Docker restart techniques:
```sh
docker run --restart always
```
```yml
services:
  yamdi:
    restart: on-failure
```

**Warning**: Although the server tends to be able to save and completely shutdown within Docker's 10-second grace period, in production, it's **highly** recommended to boost this grace period to avoid corruption in any case where the save takes longer than usual:
```sh
docker stop -t 300
```
```yml
services:
  yamdi:
    stop_grace_period: 5m
```
Having said this, it's important to mention that, when `Ctrl` + `C` is sent in a `docker-compose` session, the log feed will always prematurely end. This gives the effect that the server has been stopped before it's gotten the chance to save, when really it's still running in the background.

### File Cleaning
YAMDI can be made to clean unneeded files by setting the `YAMDI_CLEAN_FILES` variable. This purges crash dumps and crash logs.
```sh
docker run --env YAMDI_CLEAN_FILES=true
```
```yml
services:
  yamdi:
    environment:
      YAMDI_CLEAN_FILES: "true"
```

### Debug Mode
YAMDI can be made to print debug messages from itself by setting the `YAMDI_DEBUG` variable.
```sh
docker run --env YAMDI_DEBUG=true
```
```yml
services:
  yamdi:
    environment:
      YAMDI_DEBUG: "true"
```

## Credits
Thanks to [AshDevFr](https://github.com/AshDevFr/docker-spigot/), [nimmis](https://github.com/nimmis/docker-spigot), and [itzg](https://github.com/itzg/dockerfiles/tree/master/minecraft-server) for their work with running Spigot in Docker.

Thanks to [electronicboy](https://github.com/electronicboy/parchment-docker) for their work with running Paper in Docker.

Thanks to [Aikar](https://aikar.co/2018/07/02/tuning-the-jvm-g1gc-garbage-collector-flags-for-minecraft/) and [Tux](https://steinborn.me/posts/tuning-minecraft-openj9/) for their work with optimizing Spigot and Paper.

Thanks to [Flame Sage](https://github.com/chris062689) and [Byteflux](https://github.com/Byteflux) for their help and guidance.

## License
This project is licensed under the MIT license.
