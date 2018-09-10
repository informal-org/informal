#!/bin/bash

# gcloud config configurations activate default
echo "Compiling npm packages for production."
export NODE_ENV=production
npm run build
echo "Building python packages."
workon arevel
# --force --upgrade
pip install -t dist/lib -r requirements.txt
echo "Collecting static files to ship to CDN"
python manage.py collectstatic
export CLOUDSDK_PYTHON="/usr/bin/python"
gcloud app deploy

gsutil acl ch -u AllUsers:R gs://arevel-209217.appspot.com
gsutil rsync -R dist/static/ gs://arevel-209217.appspot.com/static/
gsutil -m acl ch -r -u AllUsers:R gs://arevel-209217.appspot.com/static/