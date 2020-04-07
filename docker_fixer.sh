#!/usr/bin/env bash

CONFIG="/etc/docker/daemon.json"

if [ "$EUID" -ne 0 ]
    then
        echo "This script must be run as root!" 
        exit 1
fi

if [ -f "$CONFIG" ]
        then
                echo "Sorry, $CONFIG is exist"
                exit 1
        else 
                echo '{"default-address-pools":[{"base":"10.10.0.0/16","size":24}]}' > "$CONFIG"
fi

for ct in $(docker ps -qa)
do
    for network in $(docker network ls -q)
    do
        docker network disconnect --force $network $ct
        echo "Disconnect $network from $ct"
    done
done

for ct in $(docker ps -qa)
do
    docker network connect bridge $ct
    echo "Docker $ct connected to bridge docker0"
done

docker network prune --force
echo "Delete all Docker-networks"

systemctl restart docker.service
echo "Rebooting Docker"
echo "Docker is fixed!"
