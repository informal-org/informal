#!/bin/bash
# gsutil -m rsync -R -J -a public-read appy/static/dist/collectstatic/ gs://static.aasm.app/aa/
# gsutil -m rsync -R -J -a public-read appy/static/dist/collectstatic/ gs://static.aasm.app/aa/
cd appy/static/
# Build javascript
npm run deploy
# Compile/minify/purge sass and css
gulp deploy

# Django collectstatic files and copy into collectstic dir. Requires virtualenv
cd ../..
python appy/manage.py collectstatic

# Upload to GCP for immediate distribution
gsutil cp -R -a public-read -z css -z js appy/static/dist/collectstatic/* gs://static.aasm.app/aa/