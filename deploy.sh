#!/bin/bash
echo "Compiling npm packages for production."
export NODE_ENV=production
npm run build
echo "Building python packages."
workon arevel
pip install -t dist/lib -r requirements-vendor.txt --force --upgrade
echo "Collecting static files to ship to CDN"
python manage.py collectstatic
gcloud app deploy
