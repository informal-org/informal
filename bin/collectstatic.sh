#!/bin/bash
cd ..
gsutil -m rsync -R -J -a public-read appy/static/dist/collectstatic/ gs://static.aasm.app/aa/