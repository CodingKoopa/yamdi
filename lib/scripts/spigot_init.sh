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
if [ -z "$BUILDTOOLS_MEMORY_AMOUNT" ]; then
    BUILDTOOLS_MEMORY_AMOUNT="1024M"
fi
if [ -z "$SPIGOT_MEMORY_AMOUNT" ]; then
    SPIGOT_MEMORY_AMOUNT="1024M"
fi

# Force rebuild of spigot.jar if REV is latest.
rm -f $SPIGOT_DIRECTORY/spigot-latest.jar

# Only build a new spigot.jar if a jar for this REV does not already exist.
if [ ! -f $SPIGOT_DIRECTORY/spigot-$REV.jar ]; then
  echo "Building spigot jar file, be patient"
  mkdir -p /tmp/buildSpigot
  pushd /tmp/buildSpigot
  wget https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
  HOME=/tmp/buildSpigot java $JVM_OPTS -Xmx${BUILDTOOLS_MEMORY_AMOUNT} -Xms${BUILDTOOLS_MEMORY_AMOUNT} -jar BuildTools.jar --rev $REV
  cp /tmp/buildSpigot/Spigot/Spigot-Server/target/spigot-*.jar $SPIGOT_DIRECTORY/spigot-$REV.jar
  popd
  rm -rf /tmp/buildSpigot
  mkdir -p $SPIGOT_DIRECTORY/plugins
fi

# Select the spigot.jar for this particular rev.
rm -f $SPIGOT_DIRECTORY/spigot.jar && ln -s $SPIGOT_DIRECTORY/spigot-$REV.jar $SPIGOT_DIRECTORY/spigot.jar

cd $SPIGOT_DIRECTORY/

/spigot_run.sh java "$JVM_OPTS" "-Xmx${SPIGOT_MEMORY_AMOUNT} -Xms${SPIGOT_MEMORY_AMOUNT}" -jar spigot.jar nogui

# fallback to root and run shell if spigot don't start/forced exit
bash
