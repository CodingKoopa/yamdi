# Yet Another Minecraft Docker Image

Yet Another Minecraft Docker Image is a Docker image for running the Spigot and Paper Minecraft server softwares that aims to do everything securely and tactfully. This is a fork of [this](https://github.com/AshDevFr/docker-spigot/) setup, but with many changes made with this philosphy in mind:
- The code for both the Docker image building and the script starting up Spigot should be understandable. Important design decisions should be properly documented.
- The code should be concise, combining statements where it makes sense.
- The code shouldn't do anything unnecessary.

The last point is particularly relevant. The original setup offers functionality for specifying server properties via environment variables (which does work very well), as well as running it as a `minecraft` user with restricted permissions. This image has both of these things stripped out because, as a system administrator, you are expected to:
- Use [bind mounts](https://docs.docker.com/storage/bind-mounts/) to bind the configuration volume and manually edit the configuration that way.
- Use a [user namespace](https://docs.docker.com/engine/security/userns-remap/) to have Spigot run as an unprivledged user.

These decisions were made because of how, ultimately, Docker does handle these things better and/or than a container-level mechanism can. To reiterate, if you're an end-user-ish person looking for a setup that just works with little finicking, then I would recommend the aforementioned setup. If you are someone that does care about the underlying code and security, then this might be a good setup. YAMDI is carefully designed to be secure, work in many different environments, and be customizeable.

## Usage
In this sections, excerpts from both a Bash command line with Docker and a [Docker Compose](https://docs.docker.com/compose/overview/) `yml` configuration, with `version: "3.7"`. Reading through this manual is recommended, to take full advantage of what YAMDI has to offer.

### Server Type
The type of server can be specified by setting the `SERVER_TYPE` environment variable. Currently supported values are `spigot` (default) and `paper`, case sensitive.
```sh
docker run --env SERVER_TYPE=paper
```
```yml
services:
  yamdi:
    environment:
      SERVER_TYPE: "paper"
```

### Server Version
The target revision, or game version, can be adjusted by setting the `REV` variable either to `latest` (default) or a supported game version. Setting it to a version is recommended because of how plugins may not work on newer versions.
```sh
docker run --env REV=1.14.1
```
```yml
services:
  yamdi:
    environment:
      REV: "1.14.1"
```
For Paper, `PAPER_BUILD` (a build for a particular revision) can be set in the same way.

### Starting the Server
Images for YAMDI are not provided, so it must be built:
```sh
docker build . -t yamdi
```
```yml
services:
  yamdi:
    build: .
```
As the `Dockerfile` is (deliberately) placed in the root of this repository, this repository can somewhat cleanly be added as a submodule for another repo if you're using this in a larger setup.
```yml
services:
  yamdi:
    build: ./yamdi
```
It is also worth noting that the OpenJDK base image is multiarch, so this should work seamlessly across platforms.

If using Docker Compose, it may also be desireable to have the server restart if it crashes.
```yml
services:
  yamdi:
    restart: on-failure
```

### Server Data
YAMDI exposes three volumes:
- `/opt/server`, the server installation. This contains the server `JAR`, some world-specific configurations, and world data.
- `/opt/server-config-host`, the server config. This contains server-related configurations. The configurations are handpicked by the startup script, and so it is possible that a configuration is left out of here.
- `/opt/server-plugins-host`, the server plugins. This contains plugins that are to be loaded by Spigot, and their own configurations.
`/opt/server` must be mounted, both for server data to persist, and to accept the EULA. The other volumes are technically optional, but recommended for reasons that will be explained.
```sh
docker run --mount type=volume,source=mc-server-data,target=/opt/server --mount type=bind,source=./mc-config,target=/opt/server-config-host --mount type=bind,source=./mc-plugins,target=/opt/server-plugins-host
```
```yml
services:
  yamdi:
    volumes:
      - type: volume
        source: mc-server-data
        target: /opt/server
      - type: bind
        source: ./mc-config
        target: /opt/server-config-host
      - type: bind
        source: ./mc-plugins
        target: /opt/server-plugins-host
```
The `/opt/server-config-host` and `/opt/server-plugins-host` volumes are particularly interesting. If they are mounted, then YAMDI will use Git to deploy them to `/opt/server`.

The technical details of how YAMDI implements this isn't strictly required for usage, but is educational to have an understanding of. When YAMDI is starting up, it will first copy the contents of the host directory bind mount to another location, within the temporary container filesystem. In some cases this is necessary because, in order for Git to function, even if r/w access to the files isn't needed, Git still requires it. This is necessary when user namespace remapping is being used, and the user running YAMDI does not have r/w access to the original files. In YAMDI's copy of the directory, a Git repository is established, and a commit is made containing the changes (Given the nature of an initial commit, this is every file creation.). Then, using the `git checkout` deploy technique from [here](https://gitolite.com/deploy.html), YAMDI establishes a bare repository in `/opt/server` and deploys to there. Both during the deploy, and during shutdown, YAMDI will execute `git diff` (With the exception of when an initial run is detected, because then a diff would be overwhelming.). The former of the two `diff`s is condensed for brevity.

Given these details, there are multiple results and further specifications that should be understood:
- When initially deploying, and shutting down, the changes between the server configuration, and the host configuration will be printed. The purpose of this is, respectively, to understand what changes will be made, and what changes the server has made to the files that you may want to consider adding to your configuration. This is especially useful when the server software has introduced a new configuration option. The pitfall here is that `server.properties` will constantly be updated with a timestamp, and reordering of its properties, and thus it is a false positive.
- Files in `/opt/server` that are not in the host directory will be left as-is.
- Files in `/opt/server` that have changed versions in the host directory will be updated.
- Files in `/opt/server` that have been deleted in the host directory will **not** be deleted. This is a limitation of how YAMDI's temporary Git directory works, in that it only tracks file creations.
- Permissions of files in the host directory will not be retained. The purpose/disireableness of this is that it makes the files safe for YAMDI to write to.
- As a result of YAMDI is using its own Git directory, it will neither not collide with any preexisting Git repository, nor require any Git setup.

To get started, first you should mount `/opt/server`, and let the server run and exit due to not having the EULA accepted, and then set `eula` to `true` in the docker volume. After rerunning the server, and letting it generate configuration files, you can then copy them to your preferred location, and bind them mount to YAMDI as shown in the above examples. When running with the bind mounts properly setup YAMDI will replace the generated configuration files with the new ones.

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

#### Ignore `server.properties`
The `server.properties` configuration file is internally stored as a [`Map`](https://docs.oracle.com/en/java/javase/12/docs/api/java.base/java/util/Map.html), therefore it does not have any ordering. As a result, the order of the file is random, and as such brings up false positives when put in a Git repo. This behavior can be disabled by setting `IGNORE_SERVER_PROPERTY_CHANGES` to false, although this shouldn't be done unless you have good reason to.

### Server Ports
The Mineecraft Server port can be opened by exposing port `25565`.
```sh
docker run --expose 25565
```
```yml
services:
  yamdi:
    ports:
      - "25565:25565"
```

### Java Distributions
YAMDI provides support for a few different Java distributions.

#### OpenJDK 12 Hotspot (Default)
OpenJDK 12 Hotspot is the latest OpenJDK version, with the [Hotspot VM](https://openjdk.java.net/groups/hotspot/). Hotspot is the well established VM, that has been thoroughly used over many years. If unsure, use this. This is buildable as `Dockerfile.openjdk.hotspot`, or just `Dockerfile`. The Java build is provided by [AdoptOpenJDK](https://adoptopenjdk.net/).

#### OpenJDK 12 OpenJ9
OpenJDK 12 OpenJ9 is the latest OpenJDK version, with the [OpenJ9 VM](https://www.eclipse.org/openj9/). OpenJ9 is the newer VM, that that has better memory usage (among other improvements). If better performance is needed, use this. This is buildable as `Dockerfile.openjdk.openj9`. The Java build is provided by [AdoptOpenJDK](https://adoptopenjdk.net/).

#### Oracle Java 8 SE
Oracle Java 8 SE is the latest Oracle SE version, with the Hotspot VM. This is not recommended, unless you have *very* good reason to be using it. This is buildable as `Dockerfile.oracle.hotspot`. The Java build is provided by [Oracle](https://www.oracle.com/).

### JVM Configuration

#### General Options
The options passed to the Java Virtual Machine can be adjusted by setting the `JVM_OPTS` environment variable. This will be passed to both BuildTools and Spigot.

#### Memory Options
The amount of memory to be used by the JVM for the BuildTools and the server can be separately set with the custom `BUILDTOOLS_MEMORY_AMOUNT` and `GAME_MEMORY_AMOUNT` variables, for example:
```sh
docker run --env BUILDTOOLS_MEMORY_AMOUNT=800M --env GAME_MEMORY_AMOUNT=1G
```
```yml
services:
  yamdi:
    environment:
      BUILDTOOLS_MEMORY_AMOUNT: "800M"
      GAME_MEMORY_AMOUNT: "1G"
```
Here, the device only has 2GB of RAM available. BuildTools needs at least approximately 700 MB of RAM. However, if 1 GB is used for BuildTools, the same amount is also used for the child Java processes that BuildTools spawns, effectively doubling the amount of RAM that Java uses overall. Therefore, on limited machines, it is wise to use as little RAM for BuildTools as possible. Since it will be probably be desired for more RAM to be used for Spigot itself, two separate variables are provided.

These variables will be assuming that you want to set the maximum and minimum memory amounts as the same, as this is usually desireable. However, `BUILDTOOLS_MEMORY_AMOUNT_MIN` and `BUILDTOOLS_MEMORY_AMOUNT_MAX`, as well as equivalents for `GAME_MEMORY_AMOUNT` are usable. If only one out of the `MIN` and `MAX` are provided, then it will be used for both.

If nothing is specified, YAMDI defaults to a safe 1GB for both.

#### Experimental Options
By default, for Hotspot images, YAMDI applies experimental JVM options [suggested by Aiker](https://mcflags.emc.gs/) for performance. For OpenJ9 images, [Tux's JVM options](https://steinborn.me/posts/tuning-minecraft-openj9/) are used. This behavior can be disabled by setting `USE_SUGGESTED_JVM_OPTS` to false, although this shouldn't be done unless you have good reason to.

### Sending Commands to Spigot
YAMDI comes with an helper script (thanks @AshDevFr) to send commands to Spigot while it is running in another container.
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
YAMDI properly traps the SIGINT and SIGTERM signals (sent when running `docker stop` / `docker-compose down` / `docker-compose stop` or sending `Ctrl` + `C` in a `docker-compose` session), and properly shuts down Spigot (saving worlds, shutting down plugins, etc.) when they are recieved. Additionally, any changes made to the configuration files by the server will be printed out, unless quitting via `Ctrl + C`, because then log output in the view will have already been stopped.

Conversely, when the server shuts down, the exit code of YAMDI will be equivalent to the exit code of the Java process, therefore YAMDI is compatible with Docker restart techniques:
```sh
docker run --restart always
```
```yml
services:
  yamdi:
    restart: on-failure
```

## Credits
Thanks to [AshDevFr](https://github.com/AshDevFr/docker-spigot/), [nimmis](https://github.com/nimmis/docker-spigot), and [itzg](https://github.com/itzg/dockerfiles/tree/master/minecraft-server) for their work with running Spigot in Docker.

Thanks to [electronicboy](https://github.com/electronicboy/parchment-docker) for their work with running Paper in Docker.

Thanks to [Aikar](https://aikar.co/2018/07/02/tuning-the-jvm-g1gc-garbage-collector-flags-for-minecraft/) and [Tux](https://steinborn.me/posts/tuning-minecraft-openj9/) for their optimizing Spigot and Paper.

Thanks to [Flame Sage](https://github.com/chris062689) and [Byteflux](https://github.com/Byteflux) for their help and guidance.

## License
This project is licensed under the MIT license.