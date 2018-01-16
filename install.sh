#!/bin/sh
# This is the install script of atnd.sh
# It will do followed steps:
# 0. Copy atnd.sh to /usr/local/atnd
# 1. Register and enable a service: atnd.service at /usr/lib/systemd/system
# 2. Add CONSTANT according to your input
#
# mvn test
# echo $BUILD_NUMBER > target/BUILD_NUMBER.txt
#
#


chmod 777 atnd.sh
mkdir -p /usr/local/atnd/ /usr/local/atnd/log
cp atnd.sh /usr/local/atnd/atnd.sh

cat > /usr/lib/systemd/system/atnd.service <<EOF
[Unit]
Description=Auto Tomcat Nginx Docker deploy service
After=syslog.target network.target

[Service]
ExecStart=/usr/local/atnd/atnd.sh
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /usr/lib/systemd/system/atnd.service
systemctl daemon-reload
systemctl start atnd
systemctl enable atnd
