#!/bin/sh
set -ex

# The instance startup script is frozen per group, making changes difficult
# This script bootstraps an instance and then loads a dynamic installation script which does the actual setup
RELEASE_URL=$(curl \
    -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/release-url" \
    -H "Metadata-Flavor: Google")

gsutil cp gs:// arevel-release.tar.gz
