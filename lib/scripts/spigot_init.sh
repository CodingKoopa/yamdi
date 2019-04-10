#!/bin/bash
set -e

if [ ! -e $SPIGOT_DIRECTORY/eula.txt ]; then
  if [ "$EULA" != "" ]; then
    echo "# Generated via Docker on $(date)" > $SPIGOT_DIRECTORY/eula.txt
    echo "eula=$EULA" >> $SPIGOT_DIRECTORY/eula.txt
  else
    echo "*****************************************************************"
    echo "*****************************************************************"
    echo "** To be able to run spigot you need to accept minecrafts EULA **"
    echo "** see https://account.mojang.com/documents/minecraft_eula     **"
    echo "** include -e EULA=true on the docker run command              **"
    echo "*****************************************************************"
    echo "*****************************************************************"
    exit
  fi
fi

# Some variables are mandatory.
if [ -z "$REV" ]; then
    REV="latest"
fi
if [ -z "$BUILD_MEMORY_AMOUNT" ]; then
    BUILD_MEMORY_AMOUNT="1024M"
fi
if [ -z "$GAME_MEMORY_AMOUNT" ]; then
    GAME_MEMORY_AMOUNT="1024M"
fi

# Force rebuild of spigot.jar if REV is latest.
rm -f $SPIGOT_DIRECTORY/spigot-latest.jar

# Only build a new spigot.jar if a jar for this REV does not already exist.
if [ ! -f $SPIGOT_DIRECTORY/spigot-$REV.jar ]; then
  echo "Building spigot jar file, be patient"
  mkdir -p /tmp/buildSpigot
  pushd /tmp/buildSpigot
  wget https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
  HOME=/tmp/buildSpigot java $JVM_OPTS "-Xmx${BUILD_MEMORY_AMOUNT} -Xms${BUILD_MEMORY_AMOUNT}" -jar BuildTools.jar --rev $REV
  cp /tmp/buildSpigot/Spigot/Spigot-Server/target/spigot-*.jar $SPIGOT_DIRECTORY/spigot-$REV.jar
  popd
  rm -rf /tmp/buildSpigot
  mkdir -p $SPIGOT_DIRECTORY/plugins
fi

# Select the spigot.jar for this particular rev.
rm -f $SPIGOT_DIRECTORY/spigot.jar && ln -s $SPIGOT_DIRECTORY/spigot-$REV.jar $SPIGOT_DIRECTORY/spigot.jar

if [ ! -f $SPIGOT_DIRECTORY/ops.txt ]
then
    cp /usr/local/etc/minecraft/ops.txt $SPIGOT_DIRECTORY/
fi

if [ ! -f $SPIGOT_DIRECTORY/white-list.txt ]
then
    cp /usr/local/etc/minecraft/white-list.txt $SPIGOT_DIRECTORY/
fi

function setServerProp {
  local prop=$1
  local var=$2
  if [ -n "$var" ]; then
    echo "Setting $prop to $var"
    sed -i "/$prop\s*=/ c $prop=$var" $SPIGOT_DIRECTORY/server.properties
  fi
}

if [ ! -f $SPIGOT_DIRECTORY/server.properties ]
then
  cp /usr/local/etc/minecraft/server.properties $SPIGOT_DIRECTORY/

  setServerProp "motd" "$MOTD"
  setServerProp "level-name" "$LEVEL"
  setServerProp "level-seed" "$SEED"
  setServerProp "pvp" "$PVP"
  setServerProp "view-distance" "$VDIST"
  setServerProp "op-permission-level" "$OPPERM"
  setServerProp "allow-nether" "$NETHER"
  setServerProp "allow-flight" "$FLY"
  setServerProp "max-build-height" "$MAXBHEIGHT"
  setServerProp "spawn-npcs" "$NPCS"
  setServerProp "white-list" "$WLIST"
  setServerProp "spawn-animals" "$ANIMALS"
  setServerProp "hardcore" "$HC"
  setServerProp "online-mode" "$ONLINE"
  setServerProp "resource-pack" "$RPACK"
  setServerProp "difficulty" "$DIFFICULTY"
  setServerProp "enable-command-block" "$CMDBLOCK"
  setServerProp "max-players" "$MAXPLAYERS"
  setServerProp "spawn-monsters" "$MONSTERS"
  setServerProp "generate-structures" "$STRUCTURES"
  setServerProp "spawn-protection" "$SPAWNPROTECTION"
  setServerProp "max-tick-time" "$MAX_TICK_TIME"
  setServerProp "max-world-size" "$MAX_WORLD_SIZE"
  setServerProp "resource-pack-sha1" "$RPACK_SHA1"
  setServerProp "network-compression-threshold" "$NETWORK_COMPRESSION_THRESHOLD"

  if [ -n "$MODE" ]; then
    case ${MODE,,?} in
      0|1|2|3)
        ;;
      s*)
        MODE=0
        ;;
      c*)
        MODE=1
        ;;
      *)
        echo "ERROR: Invalid game mode: $MODE"
        exit 1
        ;;
    esac

    sed -i "/gamemode\s*=/ c gamemode=$MODE" $SPIGOT_DIRECTORY/server.properties
  fi
fi

if [ -n "$OPS" -a ! -e $SPIGOT_DIRECTORY/ops.txt.converted ]; then
  echo $OPS | awk -v RS=, '{print}' >> $SPIGOT_DIRECTORY/ops.txt
fi

if [ -n "$ICON" -a ! -e $SPIGOT_DIRECTORY/server-icon.png ]; then
  echo "Using server icon from $ICON..."
  # Not sure what it is yet...call it "img"
  wget -q -O /tmp/icon.img $ICON
  specs=$(identify /tmp/icon.img | awk '{print $2,$3}')
  if [ "$specs" = "PNG 64x64" ]; then
    mv /tmp/icon.img $SPIGOT_DIRECTORY/server-icon.png
  else
    echo "Converting image to 64x64 PNG..."
    convert /tmp/icon.img -resize 64x64! $SPIGOT_DIRECTORY/server-icon.png
  fi
fi

cd $SPIGOT_DIRECTORY/

/spigot_run.sh java "$JVM_OPTS" "-Xmx${GAME_MEMORY_AMOUNT} -Xms${GAME_MEMORY_AMOUNT}" -jar spigot.jar nogui

# fallback to root and run shell if spigot don't start/forced exit
bash
