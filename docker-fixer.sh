#!/usr/bin/env bash

CONFIG="/etc/docker/daemon.json"
BACKUP="/root/support/docker"

function state {
    if [[ "$?" -eq 0 ]]
        then
            echo "[ok]"
        else
            echo "[fail]"
            exit 1
    fi
}

function backup {
    echo -n "Creating list of existing networks ... "
    docker network ls > "$BACKUP"/networks.list
    state

    echo -n "Creating list of running containers ... "
    docker ps > "$BACKUP"/running-containers.list
    state

    for CT in $(docker ps -qa)
    do
        echo -n "Creating inpection information for $CT ... "
        docker inspect "$CT" > "$BACKUP"/container-"$CT".list
        state
    done
}

if [[ "$EUID" -ne 0 ]]
    then
        echo "This script must be run as root!" 
        exit 1
fi

if [[ -f "$CONFIG" ]]
    then
        echo "Sorry, but file $CONFIG is exists!"
        exit 1
    else
        echo -n "Creating configuration file $CONFIG ... "
        echo '{"default-address-pools":[{"base":"10.1.0.0/16","size":24}]}' > "$CONFIG"
        state
fi

if [[ -d "$BACKUP" ]]
    then
        backup
    else
       echo -n "Creating backup directory $BACKUP ... "
       mkdir -p "$BACKUP"
       state
       backup
fi

for CT in $(docker ps -qa --no-trunc)
do
    NETWORK_ID="$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' $CT)"
    echo -n "Disconnecting network $NETWORK_ID from $CT ... "
    docker network disconnect --force "$NETWORK_ID" "$CT" > /dev/null
    state
done

echo -n "Deleting unuseful networks ... "
docker network prune --force > /dev/null
state

for CT in $(docker ps -qa)
do
    NETWORK_ID="$CT"
    echo -n "Creating network $NETWORK_ID for $CT ... "
    docker network create "$NETWORK_ID" > /dev/null
    state

    echo -n "Connecting netowrk $NETWORK_ID to $CT ... "
    docker network connect "$NETWORK_ID" "$CT" > /dev/null
    state
done

echo -n "Restarting Docker ... "
systemctl restart docker.service
state

for CT in $(docker ps -qa)
do
    echo -n "Restaring $CT ... "
    docker restart "$CT" > /dev/null
    state
done

echo "Docker is fixed!"
