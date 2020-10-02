#!/bin/bash

# Script for auto updating the helium miner.

# Set default values
MINER=miner
REGION=US915
GWPORT=1680
MINERPORT=44158
DATADIR=/home/pi/miner_data

# Read switches to override any default values for non-standard configs
while getopts n:g:p:d:r: flag
do
   case "${flag}" in
      n) MINER=${OPTARG};;
      g) GWPORT=${OPTARG};;
      p) MINERPORT=${OPTARG};;
      d) DATADIR=${OPTARG};;
      r) REGION=${OPTARG};;
   esac
done

# Autodetect running image version and set arch
running_image=$(docker container inspect -f '{{.Config.Image}}' $MINER | awk -F: '{print $2}')
if [ -z "$running_image" ]; then
        ARCH=arm
elif [ `echo $running_image | awk -F_ '{print $1}'` == "miner-arm64" ]; then
        ARCH=arm
elif [ `echo $running_image | awk -F_ '{print $1}'` == "miner-amd64" ]; then
        ARCH=amd
else
        ARCH=arm
        #below is just to make it not null.
        running_image=" "
fi

echo "Fetching the latest version..."
docker pull quay.io/team-helium/miner:latest-amd64 > /dev/null

# Compare image ids
image_id=$(docker image inspect --format '{{.Id}}' quay.io/team-helium/miner:latest-amd64)
running_id=$(docker inspect --format '{{.Image}}' $MINER)

if [ "$image_id" = "$running_id" ];
then    echo "already on the latest version"
        exit 0
fi

echo "Stopping and removing old miner"

docker stop $MINER && docker rm $MINER

echo "Deleting old miner software"

for a in `docker images quay.io/team-helium/miner | grep "quay.io/team-helium/miner" | awk '{print $3}'`; do
        image_cleanup=$(docker images | grep $a | awk '{print $2}')
        #change this to $running_image if you want to keep the last 2 images
        if [ "$image_cleanup" = "$miner_latest" ]; then
               continue
        else
                echo "Cleaning up: " $image_cleanup
                docker image rm $a

        fi
done

echo "Provisioning new miner version"

docker run -d --env REGION_OVERRIDE=$REGION --restart always --publish $GWPORT:$GWPORT/udp --publish $MINERPORT:$MINERPORT/tcp --name $MINER --mount type=bind,source=$DATADIR,target=/var/data quay.io/team-helium/miner:latest-amd64

if [ $GWPORT -ne 1680 ] || [ $MINERPORT -ne 44158 ]; then
   echo "Using nonstandard ports, adjusting miner config"
   docker exec $MINER sed -i "s/44158/$MINERPORT/; s/1680/$GWPORT/" /opt/miner/releases/0.1.0/sys.config
   docker restart $MINER
fi
