#!/bin/bash
docker build -t aasm:beta .
echo "Running AppAssembly rust server on http://localhost:8000"
docker run -p 9080:9080 --env-file=.docker_env --network=host aasm:beta
