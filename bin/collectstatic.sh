#!/bin/bash
cd ..
# gsutil -m rsync -R -J -a public-read appy/static/dist/collectstatic/ gs://static.aasm.app/aa/
# gsutil -m rsync -R -J -a public-read appy/static/dist/collectstatic/ gs://static.aasm.app/aa/
gsutil cp -R -a public-read -z css -z js appy/static/dist/collectstatic/ gs://static.aasm.app/aa/
