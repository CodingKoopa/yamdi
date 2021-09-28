# Yet Another Minecraft Docker Image
**Yet Another Minecraft Docker Image** (YAMDI) is a Docker image for running server software for *Minecraft: Java Edition*, such as Spigot and Paper, that aims to do everything securely and tactfully. Each part of YAMDI is designed to take full advantage of the features and optimizations that Docker can bring. The code is written for high readability and modifiability without making any sacrifices. YAMDI is a technical product for technical users who wish to understand the systems they run, and who like to tinker with them. If this doesn't sound like you, you may have a better time with the [`itzg/docker-minecraft-server`](https://github.com/itzg/docker-minecraft-server) image that is more geared towards being friendly for end-users.

The difference between this image and `itzg/docker-minecraft-server` is best exemplified in the handling of server configuration files. YAMDI encourages you to bind mount a version controlled server configuration directory into Docker, and uses Git to deploy it and print the changes as the server quits. `itzg/docker-minecraft-server`, on the other hand, offers the user the choices of either directly copying your configuration files into the container, or use some of the convenience environment variables provided to set server properties during startup. YAMDI makes it easier for you to manage your files in a VCS, but perhaps you do or don't care about that. The intent of this comparison is not at all to diminish the hard work that goes into that image, but to highlight how they are simply for different audiences.

## Usage

### How to use this Manual
There are two official ways to start a Docker container that will be explored in this manual:
- The [Docker CLI](https://docs.docker.com/engine/reference/run/), which is configured using commands alone. This entails creating a `docker` command that will be invoked in order to start the server.
- The [Docker Compose CLI](https://docs.docker.com/compose/reference/), which is configured using Compose files, which use [YAML](https://yaml.org/). This entails creating a Compose file that will be used by `docker-compose`.

Docker Compose's configuration format and additional organizational tools often make it a good choice, but the startup process Docker CLI too can be automated by keeping the commands in a script. Although both of these options use the underlying Docker Engine, when it comes to starting the container, you only use one or the other to start YAMDI.

#### Using Docker CLI
The Docker CLI comes with any installation of Docker. If you have not yet installed it to your computer and/or server, see [Docker's guide](https://docs.docker.com/get-docker/) to do so.

To get started, make a copy of the sample script in the YAMDI directory:
```sh
cp start.sample.sh start.sh
```

Now, to understand how to read the example snippets found throughout this documentation, let's use an example:

---
```sh
docker run --env YAMDI_SERVER_TYPE="paper" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_SERVER_TYPE: "paper"
```
---
The first code block is what applies to you - you don't need to worry about the YAML configuration at the bottom. The `docker run` signifies the command that's being run, and the `--env YAMDI_SERVER_TYPE=paper` signifies the argument that this is showing you to run. Most importantly, the `...` signifies that **this command is not meant to be run as-is!** These snippets do not stand on their own - you must integrate them into your script.

The Docker commands can get really long! For this reason, it's useful to break them up into multiple lines by escaping the newline:
```sh
docker run yamdi/yamdi:latest \
  --env YAMDI_SERVER_TYPE="paper"
```
The backslash "cancels out" the newline, making it look like all the same line to the shell.

If you don't include the backslash, bad things will happen. For instance:
```sh
docker run yamdi/yamdi:latest
  --env YAMDI_SERVER_TYPE="paper"
```
The shell sees this as two separate commands that it will try and run, which is undesired.

### Using Docker Compose CLI
In order to use Docker Compose, you must install both the [main Docker engine and CLI](https://docs.docker.com/get-docker/), as well as the separate [Docker Compose program](https://docs.docker.com/compose/install/).

To get started, make a copy of the sample configuration in the YAMDI directory:
```sh
cp docker-compose-sample.yml docker-compose.yml
```

Now, to understand how to read the example snippets found throughout this documentation, let's use an example from later in this document:

---
```sh
docker run --env YAMDI_SERVER_TYPE="paper" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_SERVER_TYPE: "paper"
```
---
In most cases, second code block is what applies to you - you don't need to worry about the command at the top unless it's for `docker-compose`. This is a YAML "snippet" that you would merge with your existing configuration. For example, starting with a more functional Compose file:
```yaml
version: "3.9"
services:
  yamdi:
    image: yamdi/yamdi:latest
    # <This is where the "environment" key goes!>
```

### Starting the Server

#### Choosing an Image
There are a couple of options for the YAMDI image to use:
- Use a prebuilt image with a preselected common Java base image.
- Build YAMDI yourself with whichever Java base image you want.

For more info on the variety of Java installations that can be used, see [Java Distributions](JavaDistributions.md).

##### Prebuilt YAMDI
YAMDI's [Continuous Integration (CI)](https://docs.gitlab.com/ee/ci/) provides prebuilt YAMDI images, updated when there is a new commit, as well as on a nightly basis for security updates.

The images are pushed to [Docker Hub](https://hub.docker.com/r/yamdi/yamdi), with the following tags (currently very limited due to upstream changes):

| Tags     | Distributor      | Java | JVM     | Type | OS     | Architecture                              |
| -------- | ---------------- | ---- | ------- | ---- | ------ | ----------------------------------------- |
| `latest` | Eclipse Adoptium | 16   | Hotspot | JRE  | Ubuntu | `linux/amd64`, `linux/arm64`, `linux/arm` |

If unsure, start with the `latest` image, as that tag corresponds with a safe default. Be careful with the Alpine Linux images: Although the smaller image size and more slim image contents make them a tempting pick, there may be performance implications to using it on a production Minecraft server.

Multi arch support is provided where the base images provide it, for `amd64` (`x86_64`), `arm32v7` (`arm`), and `arm64v8` (`arm64`, `aarch64`). This spread has been selected to cover desktop servers as well as Raspberry Pi devices, but feel free to [make your case](https://gitlab.com/CodingKoopa/yamdi/-/issues/new) for another architecture you want to use.

If you need to use a YAMDI build from a specific date (noting that that same tag may be pushed to more than once if there is a new commit on that day), every one of the tags above has a variant with the date appended in `-YYYYMMDD` format. For instance, for the `latest-ubuntu` tag, there is a `latest-ubuntu-20210630` tag and a `latest-ubuntu-20210701` tag and so on. This should only be used temporarily, if a new YAMDI build breaks functionality for you, as images tagged with older dates **will not be updated with security fixes**.

If using the Docker CLI to launch YAMDI, the image is ran using the `docker run`.
```sh
docker run yamdi/yamdi:latest ...
```

If using Docker Compose to launch YAMDI, the image is built using `docker-compose up`. If there is more than one service defined in the Compose file, you can use `docker-compose up yamdi` to only start YAMDI.
```sh
docker-compose up
```
```yml
services:
  yamdi:
    image: yamdi/yamdi:latest
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

###### Building the Image
If using the Docker CLI to launch YAMDI, the image is built using  `docker build`.
```sh
docker build -t yamdi .
```

Then, the image is then ran using `docker run`.
```sh
docker run yamdi ...
```

If using Docker Compose to launch YAMDI, the image is built using `docker-compose build`, or `docker-compose up --build` to do so while starting the container.
```sh
docker-compose build
```
```yaml
services:
  yamdi:
    build:
      context: .
      image: yamdi
```

Then, the image is then ran using `docker-compose up`. If there is more than one service defined in the Compose file, you can use `docker-compose up yamdi` to only start YAMDI.
```sh
docker-compose up
```
(There is no YAML snippet that pertains to this step.)

###### Specifying Base Image

The Dockerfile is designed to adapt to whatever base image you give it. You can specify what base image you want to use by setting the `YAMDI_BASE_IMAGE` build-time variable to the full tag referring to the Java image you want to use. The vast array of Java images available is documented in [Java Distributions](JavaDistributions.md).
```sh
docker build --build-arg YAMDI_BASE_IMAGE="adoptopenjdk/openjdk16:jre" ...
```
```yaml
services:
  yamdi:
    build:
      args:
      - YAMDI_BASE_IMAGE="adoptopenjdk/openjdk16:jre"
```

### Server Type
The type of server can be specified by setting the `YAMDI_SERVER_TYPE` environment variable. Currently supported values are `paper` (default) and `spigot`, case sensitive.
```sh
docker run --env YAMDI_SERVER_TYPE="paper" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_SERVER_TYPE: "paper"
```

### Server Version
The target Minecraft version, can be adjusted by setting the `YAMDI_MINECRAFT_VERSION` variable either to `latest` (default) or a specific game version. Setting this to a specific version is **strongly recommended**, because of server software being buggy in the beginning, and plugin support not being guaranteed. You should aim for the most recent version that is considered to be stable on your server software. To use [Minecraft 1.8.9](https://minecraft.fandom.com/wiki/Java_Edition_1.8.9) - to give an example of a popular but older update, so this documentation doesn't become outdated:
```sh
docker run --env YAMDI_MINECRAFT_VERSION="1.8.9" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_MINECRAFT_VERSION: "1.8.9"
```

### Paper Version
For Paper, `YAMDI_PAPER_BUILD` (a build for a particular revision of Paper) can be set in the same way. To use build 500 of the branch for this Minecraft version:
```sh
docker run --env YAMDI_PAPER_BUILD="500" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_PAPER_BUILD: "500"
```

### Server Data
YAMDI exposes three volumes:
- `/opt/yamdi/user/server`, the server installation. This contains the server `JAR`, some world-specific configurations, and world data.
- `/opt/yamdi/server-config-host`, the server configuration. This contains server-related configurations.
- `/opt/yamdi/server-plugins-host`, the server plugins. This contains plugins that are to be loaded by the server, and their own configurations.

#### Server Installation
The server installation volume, `/opt/yamdi/user/server` must be mounted in order for server data to persist. YAMDI enforces this by having a file in `/opt/yamdi/user/server/`, which will not be present if `/opt/yamdi/user/server` becomes a mountpoint directly. Unfortunately, [Docker's default behavior with an empty volume is to copy the file into the volume](https://docs.docker.com/storage/#tips-for-using-bind-mounts-or-volumes), which causes a false positive. We specify the `nocopy` volume option to disable this behavior.

To use a named volume to hold server data:
```sh
docker run --mount type=volume,source=mc_server_data,target=/opt/yamdi/user/server,volume-nocopy=true ...
```
```yml
services:
  yamdi:
    volumes:
      - type: volume
        source: mc_server_data
        target: /opt/yamdi/user/server
        volume:
          nocopy: true

volumes:
  mc_server_data:
```

Alternatively, rather than using Docker's volume system, you could create a directory (`mc-data`) and use it as a bind mount:
```sh
docker run --mount type=bind,source="$(pwd)/mc-data",target=/opt/yamdi/user/server ...
```
```yml
services:
  yamdi:
    volumes:
      - type: bind
        source: ./mc-data
        target: /opt/yamdi/user/server
```
This not recommended because of potential permission conflicts that can occur.

#### Server Configuration and Server Plugins
Unlike the server installation, the volumes for the server configurations and plugins are optional - if you'd like, you could just use that volume to edit server configuration files and update plugins. However, this presents the following shortcomings:
- The Docker volume's underlying files are in an inconvenient location to edit manually, unless you are using a bind mount.
- With user namespace remapping, the underlying files will not be editable by nonroot users.
- There's no way to put the configuration files of interest alone in a version control system.

The `/opt/yamdi/server-config-host` and `/opt/yamdi/server-plugins-host` mount points allow for isolating the server configuration and plugins so that they may be managed separately with relative ease. If they are mounted, then YAMDI will use Git to deploy them to `/opt/yamdi/user/server`.

To accomplish this, every startup, for each of the two mount points, YAMDI does the following:
- Copy the contents of the host directory bind mount, because Git requires rw access to the files, which is not guaranteed for the YAMDI user if user namespace remapping is being used.
- In YAMDI's copy of the directory, establish a Git repository.
- In the Git repository, create an initial commit that adds all of the files.
- Use the `git checkout` deploy technique from [here](https://gitolite.com/deploy.html) to establish a bare repository in `/opt/yamdi/user/server` and deploy the files to it.
- Display a condensed `git diff`, to indicate what changes are being made to the pre-existing `/opt/yamdi/user/server`. If it's detected that this is the first run, this will not be printed as it would be overwhelming.
- YAMDI allows the server to run before further action.
- During shutdown, display a `git diff`, to indicate what changes the server software has made, such as adding an option added in an update.
- A patch is produced with the changes made by the server software.

Given these details, there are multiple consequences that should be understood:
- Files in `/opt/yamdi/user/server` that are not in the host directory will be left as-is.
- Files in `/opt/yamdi/user/server` that have changed versions in the host directory will be updated.
- Files in `/opt/yamdi/user/server` that have been deleted in the host directory will **not** be deleted. This is a limitation of how YAMDI's temporary Git directory works, in that it only tracks file creations. To remedy this, `JAR`s in the server plugin directory will be removed before the import process, to avoid any duplicate plugins of different versions.
- Permissions of files in the host directory will not be retained. The purpose/desirableness of this is that it makes the files safe for YAMDI to write to.
- As a result of YAMDI is using its own Git directory, it will neither not collide with any preexisting Git repository, nor require any Git setup on your part.

To use this, firstly, create the directories to hold the files on the host:
```sh
mkdir mc-config mc-plugins
```

TODO: Wizard to setup template.

Then, to bind mount them to the container:
```sh
docker run --mount type=bind,source="$(pwd)/mc-config",target=/opt/server-config-host --mount type=bind,source="$(pwd)/mc-plugins",target=/opt/server-plugins-host ...
```
```yml
services:
  yamdi:
    volumes:
      - type: bind
        source: ./mc-config
        target: /opt/yamdi/server-config-host
      - type: bind
        source: ./mc-plugins
        target: /opt/yamdi/server-plugins-host
```

##### Using the Git Patch
The changes made by the server to the configuration files can be written back like so:
```sh
#!/bin/bash
set -e
VOLUME_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' mc_server_data)
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
docker run --expose 25565 ...
```
```yml
services:
  yamdi:
    ports:
      - "25565:25565"
```

### JVM Configuration

#### General Options
The options passed to the Java Virtual Machine can be adjusted by setting the `YAMDI_JVM_OPTS` environment variable. This will be passed to both BuildTools and the server. For instance, if you are
using a OpenJ9 image, and will be running YAMDI in a virtual machine (e.g. if your cloud provider uses virtualization), you may want to use [`-Xtune:virtualized`](https://www.eclipse.org/openj9/docs/xtunevirtualized/):
```sh
docker run --env YAMDI_JVM_OPTS="-Xtune:virtualized" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_JVM_OPTS: "-Xtune:virtualized"
```

#### Memory Options
The amount of memory allotted to the JVM should be set using the `YAMDI_GAME_MEMORY_AMOUNT` variable:
```sh
docker run --env YAMDI_GAME_MEMORY_AMOUNT="1G" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_GAME_MEMORY_AMOUNT: "1G"
```

You can also set the minimum and maximum memory amounts separately, using the `YAMDI_GAME_MEMORY_AMOUNT_MIN` and `YAMDI_GAME_MEMORY_AMOUNT_MAX` variables, which have a higher precedence than `YAMDI_GAME_MEMORY_AMOUNT`

##### BuildTools Memory Options
The amount of memory alloted to the JVM while running BuildTools can be set using the `YAMDI_BUILDTOOLS_MEMORY_AMOUNT` variable:
```sh
docker run --env YAMDI_BUILDTOOLS_MEMORY_AMOUNT="800M" --env YAMDI_GAME_MEMORY_AMOUNT="1G" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_BUILDTOOLS_MEMORY_AMOUNT: "800M"
      YAMDI_GAME_MEMORY_AMOUNT: "1G"
```
Here, the device only has 2GB of RAM available. BuildTools needs at least approximately 700 MB of RAM. However, if 1 GB is used for BuildTools, the same amount is also used for the child Java processes that BuildTools spawns, effectively doubling the amount of RAM that Java uses overall. Therefore, on limited machines, it is wise to use as little RAM for BuildTools as possible. Since it will be probably be desired for more RAM to be used for the server itself, two separate variables are provided.

You can also use `YAMDI_BUILDTOOLS_MEMORY_AMOUNT_MIN` and `YAMDI_BUILDTOOLS_MEMORY_AMOUNT_MAX` in the same way as their analogues for the game process.

If unspecified, the BuildTools variables will default

#### Experimental Options
By default, for HotSpot images, YAMDI applies experimental JVM options [suggested by Aiker](https://mcflags.emc.gs/) for performance. For OpenJ9 images, [Tux's JVM options](https://steinborn.me/posts/tuning-minecraft-openj9/) are used. This behavior can be disabled by setting `YAMDI_USE_SUGGESTED_JVM_OPTS` to false, although this shouldn't be done unless you have good reason to.

```sh
docker run --env YAMDI_USE_SUGGESTED_JVM_OPTS="false" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_USE_SUGGESTED_JVM_OPTS: "false"
```

### Sending Commands to the Server
YAMDI comes with an helper script to send commands to the server while it is running in another container.
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
This should print something like `This server is running CraftBukkit version git-Spigot-f09662d-7c395d4 (MC: 1.13.2) (Implementing API version 1.13.2-R0.1-SNAPSHOT)`.

### Shutting the Server Down
YAMDI properly traps the SIGINT and SIGTERM signals (sent when running `docker stop` / `docker-compose down` / `docker-compose stop` or sending `Ctrl` + `C` in a `docker-compose` session), and properly shuts down the server (saving worlds, shutting down plugins, etc.) when they are received.

Conversely, when the server shuts down on its own accord, the exit code of YAMDI will be equivalent to the exit code of the Java process, therefore YAMDI is compatible with Docker restart techniques:
```sh
docker run --restart on-failure ...
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
It's important to mention that, when `Ctrl` + `C` is sent in a `docker-compose` session, the log feed will always prematurely end. This gives the effect that the server has been stopped before it's gotten the chance to save, when really it's still running in the background.

### File Cleaning
YAMDI can be made to clean unneeded files by setting the `YAMDI_CLEAN_FILES` variable. This purges crash dumps, crash logs, and plugin JARs beyond those directly in `/plugins` (these are most likely dependency JARs that have been automatically downloaded).
```sh
docker run --env YAMDI_CLEAN_FILES="true" ...
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
docker run --env YAMDI_DEBUG="true" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_DEBUG: "true"
```

### Trace Mode
YAMDI can be made to print every command it runs by setting the `YAMDI_TRACE` variable.
```sh
docker run --env YAMDI_TRACE="true" ...
```
```yml
services:
  yamdi:
    environment:
      YAMDI_TRACE: "true"
```

## Credits
YAMDI was started from [`docker-spigot`](https://github.com/AshDevFr/docker-spigot/) by AshDevFr, before everything was rewritten over time.

Thanks to [nimmis](https://github.com/nimmis/docker-spigot) and [itzg](https://github.com/itzg/docker-minecraft-server) for their work with running Spigot in Docker.

Thanks to [electronicboy](https://github.com/electronicboy/parchment-docker) for their work with running Paper in Docker.

Thanks to [Aikar](https://aikar.co/2018/07/02/tuning-the-jvm-g1gc-garbage-collector-flags-for-minecraft/) and [Tux](https://steinborn.me/posts/tuning-minecraft-openj9/) for their work with optimizing Spigot and Paper.

Thanks to [Flame Sage](https://github.com/chris062689) and [Byteflux](https://github.com/Byteflux) for their help and guidance.

## License
This project is licensed under the MIT license.
