#!/bin/sh
# This is the install script of atnd.sh
# It will do followed steps:
# 0. Copy atnd.sh to /usr/local/atnd
# 1. Register and enable a service: atnd.service at /usr/lib/systemd/system
# 2. Add CONSTANT to atnd.conf according to your input
#
# mvn test
# echo $BUILD_NUMBER > target/BUILD_NUMBER.txt
#
#

echo This script is used to install atnd.sh as a system service.

runFile=atnd.sh
runFolder=/usr/local/atnd/
configFile=atnd.conf
configFullPath=$runFolder$configFile
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

######################################
# function Constant_Input
#
# Return code
# 0 success
# 1 need reinput
# 2 need confirm
function Constant_Input(){
  if [ ! -e $configFullPath ];then
    echo Please input the location of war file:
    echo \(For example: http://example.com/demo.war or /var/local/atnd/demo.war\)
    read warUrl
    WAR_FILE_NAME=`echo $warUrl | awk -F "/" '{print $NF}'`
    WAR_URL=`echo ${warUrl:0:-${#WAR_FILE_NAME}}`
    
    echo Please input the location of zip file:
    echo \(For example: http://example.com/demo.zip or /var/local/atnd/demo.zip\)
    read zipUrl
    ZIP_FILE_NAME=`echo $zipUrl | awk -F "/" '{print $NF}'`
    ZIP_URL=`echo ${zipUrl:0:-${#ZIP_FILE_NAME}}`
    
    touch $configFullPath
    echo WAR_FILE_NAME=$WAR_FILE_NAME > $configFullPath
    echo WAR_URL=\"$WAR_URL\" >> $configFullPath
    echo ZIP_FILE_NAME=$ZIP_FILE_NAME >> $configFullPath
    echo ZIP_URL=\"$ZIP_URL\" >> $configFullPath
  fi
    
  echo You input is below, please confirm again
  echo "#############"
  cat $configFullPath
  echo "#############"
  echo -en "Please input Y/N: "
  read choice
  case $choice in
    Y|y) echo Accept and continue.  
         echo Your config is saved at $configFullPath.
         echo You can run this script again to re-config.
         return 0
    ;;
    N|n) echo Please input the file location again.
         return 1
    ;;
    *) echo Invalid input. Please input Y or N. You input is $choice. 
       echo Exit now without any changes. You can run this script again if needed.
       return 2
    ;;
  esac
}
###############################

##################
# CONSTANT INPUT #
##################
Constant_Input
constantInputResult=$?

while [[ $constantInputResult -eq 1 || $constantInputResult -eq 2 ]]
do
  Constant_Input
  constantInputResult=$?
  if [ $constantInputResult -eq 1 ];then
    rm -f $configFullPath
  fi
  #echo constantInputResult is $constantInputResult
done

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
