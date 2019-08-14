#!/bin/bash

set -ex

RELEASE_URL=$(curl \
    -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/release-url" \
    -H "Metadata-Flavor: Google")

sudo gsutil cp ${RELEASE_URL} arevel-release.tar.gz
tar -xvzf arevel-release.tar.gz
sudo systemctl restart arevel