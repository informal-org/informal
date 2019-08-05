#!/bin/bash
set -ex
export HOME=/app
export RELEASE_DIR=/app/arevel-release/

# Link project directories - create www & arevelcom dirs
sudo mkdir -p /var/www/arevelcom
sudo chown arevelapp /var/www/arevelcom
cd /var/www/arevelcom
ln -s /app/arevel-release/static/ static
ln -s /app/arevel-release/templates/ templates



#wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 \
#    -O cloud_sql_proxy
#chmod +x cloud_sql_proxy
#mkdir /tmp/cloudsql

# Performance tuning from https://github.com/dsander/phoenix-connection-benchmark/blob/master/files/setup_chat.sh
# https://gist.github.com/kgriffs/4027835
cat <<EOF >> /etc/sysctl.conf
fs.file-max=22000500
fs.nr_open=30000500
net.ipv4.tcp_mem='10000000 10000000 10000000'
net.ipv4.tcp_rmem='1024 4096 16384'
net.ipv4.tcp_wmem='1024 4096 16384'
net.core.rmem_max=16384
net.core.wmem_max=16384
net.ipv4.tcp_moderate_rcvbuf=0
net.core.somaxconn=32768
net.core.netdev_max_backlog=32768
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Disable TCP slow start on idle connections
net.ipv4.tcp_slow_start_after_idle = 0

# Discourage Linux from swapping idle server processes to disk (default = 60)
vm.swappiness = 10
# Be less aggressive about reclaiming cached directory and inode objects
# in order to improve filesystem performance.
vm.vfs_cache_pressure = 50

net.ipv4.tcp_keepalive_time = 30

# Protection from SYN flood attack.
net.ipv4.tcp_syncookies = 1

net.ipv4.tcp_dsack = 1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_low_latency=1

# Increase TCP queue length
net.ipv4.neigh.default.proxy_qlen = 96
net.ipv4.neigh.default.unres_qlen = 6

# TCP BBR
net.ipv4.tcp_congestion_control=bbr

# TCP fastopen
net.ipv4.tcp_fastopen = 3

EOF

cat <<EOF >> /etc/security/limits.conf
root      hard    nofile      30000000
root      soft    nofile      30000000
EOF

# Reload
sudo /sbin/sysctl -p

PROJECT_ID=$(curl \
    -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" \
    -H "Metadata-Flavor: Google")
#./cloud_sql_proxy -projects=${PROJECT_ID} -dir=/tmp/cloudsql &

chmod 755 $RELEASE_DIR/arevel

# Systemd setup
sudo cat <<EOF >> /etc/systemd/system/arevel.service
[Unit]
Description="Arevel web app"
After=network.target

[Service]
User=arevelapp
Group=arevelapp
Environment=PORT=9080,env=prod
ExecStart=/app/arevel-release/arevel
Restart=always

[Install]
WantedBy=multi-user.target
EOF


sudo systemctl status arevel
echo "Starting"
sleep 3
sudo systemctl start arevel

echo "Arevel server started"

#PORT=9080 ./arevel



# gcloud compute instances create arevel-instance \
#     --image-family debian-9 \
#     --image-project debian-cloud \
#     --machine-type n1-standard-4 \
#     --boot-disk-type pd-ssd \
#     --boot-disk-size 10 \
#     --scopes "userinfo-email,cloud-platform" \
#     --metadata-from-file startup-script=bin/instance-startup.sh \
#     --metadata release-url=gs://arevel-209217-releases/arevel-release \
#     --zone us-central1-b \
#     --tags http-server
