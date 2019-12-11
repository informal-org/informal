#!/bin/bash
cd ..
docker build -t appy:latest .
docker tag appy:latest us.gcr.io/appassembly/appy:latest
docker push us.gcr.io/appassembly/appy:latest
export deploydate=`date +"%Y-%m-%dT%H_%M"`
eval "docker tag appy:latest us.gcr.io/appassembly/appy:$deploydate"
eval "docker push us.gcr.io/appassembly/appy:$deploydate"
kubectl rollout restart deployment/appy-deployment