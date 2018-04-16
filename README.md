# Arevel


# Setup
pip install -r requirements-vendor.txt -t dist/lib/
pip install -r requirements.txt
pip install mysqlclient

mysql.server start

./cloud_sql_proxy -instances=arevel-0:us-central1:arevel=tcp:3306