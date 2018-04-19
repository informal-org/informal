#!/bin/bash
echo "Compiling npm packages for production."
export NODE_ENV=production
npm run build
echo "Building python packages."
workon arevel
pip install -t dist/lib -r requirements.txt --force --upgrade
echo "Collecting static files to ship to CDN"
python manage.py collectstatic
export CLOUDSDK_PYTHON="/usr/bin/python"
gcloud app deploy

gsutil acl ch -u AllUsers:R gs://arevel-0.appspot.com
gsutil rsync -R dist/static/ gs://arevel-0.appspot.com/static/