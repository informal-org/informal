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
gcloud compute instance-groups managed rolling-action start-update arevel-group

# Be sure to verify that the deploy went through.