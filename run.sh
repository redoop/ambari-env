#!/bin/bash

current=`pwd`

mkdir -p ${current}/common/data/nexus-data

chmod -R 777 ${current}/common

docker compose -f ${current}/docker-compose.yaml up -d
