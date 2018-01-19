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

runFile=atnd.sh
runFolder=/usr/local/atnd/
serviceFullName=atnd.service
serviceName=${serviceFullName:0:-8}

if [ ! -e $runFile ];then
  echo The $atnd.sh is not exist in the same folder. Exit without any change.
  exit 1
fi

set -x
cat /etc/redhat-release | grep 7\..*
set +x
if [ $? -ne 0 ];then
  echo Please make sure your system is CentOS 7 or RedHat 7.
  exit 1
fi

chmod 755 $runFile
mkdir -p $runFolder $runFolder/log
\cp $runFile $runFolder

cat > /usr/lib/systemd/system/$serviceFullName <<EOF
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

chmod 644 /usr/lib/systemd/system/$serviceFullName
systemctl daemon-reload
systemctl start $serviceName
systemctl enable $serviceName

sleep 2
set -x
systemctl status $serviceName -l
set +x
if [ $? -ne 0 ];then
  echo $serviceName is not active correctly. Please manual check.
  exit 2
  else
    echo $serviceName is running now.
    exit 0
fi
