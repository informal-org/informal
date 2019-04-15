#!/bin/sh
set -ex
export HOME=/app
mkdir -p ${HOME}
cd ${HOME}
RELEASE_URL=$(curl \
    -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/release-url" \
    -H "Metadata-Flavor: Google")
gsutil cp ${RELEASE_URL} arevel-release
chmod 755 arevel-release
wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 \
    -O cloud_sql_proxy
chmod +x cloud_sql_proxy
mkdir /tmp/cloudsql
PROJECT_ID=$(curl \
    -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" \
    -H "Metadata-Flavor: Google")
./cloud_sql_proxy -projects=${PROJECT_ID} -dir=/tmp/cloudsql &
PORT=9080 ./arevel-release start
