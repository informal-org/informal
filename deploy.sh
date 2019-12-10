#!/bin/bash
docker build -t aasm:latest .
docker tag aasm:latest us.gcr.io/appassembly/aasm:latest
docker push us.gcr.io/appassembly/aasm:latest
export deploydate=`date +"%Y-%m-%dT%H_%M"`
eval "docker tag aasm:latest us.gcr.io/appassembly/aasm:$deploydate"
eval "docker push us.gcr.io/appassembly/aasm:$deploydate"
# kubectl rollout restart deployment/aasm-deployment
