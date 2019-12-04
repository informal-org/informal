#!/bin/bash

docker build -t arevel:beta .
echo "Running AppAssembly rust server on http://localhost:8000"
docker run -p 8000:8000 --env-file=.docker_env --network=host arevel:beta