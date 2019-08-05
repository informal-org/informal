#!/usr/bin/bash

# Setup environment variables
AREVEL_BASE=~/code/arevel/
RELEASE_DIR=~/code/arevel/target/arevel-release

# Clean up old releases
rm -rf $AREVEL_BASE/target/arevel-release
rm $RELEASE_DIR/arevel-release.tar.gz 

# Setup directory for new relase
cd $AREVEL_BASE
mkdir target/arevel-release

# Package NPM libraries in deploy mode
cd $AREVEL_BASE/site/static
npm run deploy

# Copy statics to directory for distribution
cp -r dist/static $RELEASE_DIR/static
cp -r $AREVEL_BASE/site/templates $RELEASE_DIR/templates

# Build site binary in release mode
cd $AREVEL_BASE/site/
cargo build --release
cp $AREVEL_BASE/target/release/site $RELEASE_DIR/arevel

# Compile standard library wasm headers for release
cd $AREVEL_BASE/avs
./build.sh
cp header.wat $RELEASE_DIR
cp footer.wat $RELEASE_DIR


# Package release
cd $RELEASE_DIR/..
tar -zcvf arevel-release.tar.gz arevel-release
cp arevel-release.tar.gz arevel-release.$(date -d "today" +"%Y%m%d%H%M").tar.gz

# Deploy static files
# gsutil cp -r arevel-release/static/ gs://avst/arevel/static/

# Deploy code to google storage
gsutil cp arevel-release.tar.gz gs://arevel-209217-releases/arevel-release.tar.gz
# gsutil cp _build/prod/rel/arevel/bin/arevel.run \
#    gs://arevel-209217-releases/arevel-release
