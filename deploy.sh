#!/bin/bash
export NODE_ENV=production
npm run build
python manage.py collectstatic
gcloud app deploy
