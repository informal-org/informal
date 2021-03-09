#!/bin/sh
cd ~/code/arevel/assets

echo "Building frontend assets"
npm install
./node_modules/webpack/bin/webpack.js --mode production

echo "Mix digest"
cd ..
mix phx.digest

echo "Installing mix dependencies"
# Build in a docker container matching prod env
mix clean --deps
docker run --rm -it -v $(pwd):/app arevel-builder

echo "Publishing release"
# Deploy code to google storage
gsutil cp _build/prod/rel/arevel/bin/arevel.run \
    gs://arevel-209217-releases/arevel-release

echo "Restarting instaces"
# Restart instances to pick up changes.

# Doesn't seem to do anything??
gcloud compute instance-groups managed rolling-action start-update arevel-group \
    --version template=arevel-template --zone us-central1-b \
    -type proactive

gcloud compute instance-groups managed rolling-action replace arevel-group --zone us-central1-b
# Be sure to verify that the deploy went through.