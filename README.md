# Arevel


# Setup
pip install -r requirements-vendor.txt -t dist/lib/
pip install -r requirements.txt
pip install mysqlclient

mysql.server start

./cloud_sql_proxy -instances=arevel-209217:us-central1:arevelsql=tcp:3306

SETTINGS_MODE='proxyprod' python manage.py migrate


# Locally
CREATE DATABASE mydatabase CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;



Cron deploy
gcloud app deploy cron.yaml

