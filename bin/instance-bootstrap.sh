#!/bin/sh
set -ex

# The instance startup script is frozen per group, making changes difficult
# This script bootstraps an instance and then loads a dynamic installation script which does the actual setup
