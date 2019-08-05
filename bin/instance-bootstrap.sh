#!/bin/bash
set -ex

export HOME=/app
export RELEASE_DIR=$HOME/arevel-release/

mkdir -p ${HOME}
cd ${HOME}

# The instance startup script is frozen per group, making changes difficult
# This script bootstraps an instance and then loads a dynamic installation script which does the actual setup
RELEASE_URL=$(curl \
    -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/release-url" \
    -H "Metadata-Flavor: Google")

gsutil cp ${RELEASE_URL} arevel-release.tar.gz
tar -xvzf arevel-release.tar.gz
chmod +x arevel-release/instance-startup.sh
source arevel-release/instance-startup.sh