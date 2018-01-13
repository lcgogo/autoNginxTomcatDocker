#!/bin/sh

# 2018.Jan.13th  Lewis Li  ver0.1  New script to deploy Tomcat in a Docker with local war file.
# 2018.Jan.13th  Lewis Li  ver0.2  Add file download.

WAR_FILE_NAME=yijava.war
WAR_URL="https://github.com/lcgogo/autoTomcatDocker/raw/master/"
WAR_FOLDER=${WAR_FILE_NAME:0:-4}

###############################################
# function System_date
function System_date(){
echo `date +%Y-%m-%d-%H:%M:%S`
}
###############################################

###############################################
# fucntion File_Download
function File_Download(){
  fileURL=$1
  fileName=$2
  fileNameTime=$fileName.`date +%Y%m%d%H%M%S`
  fileNameNew=$fileNameTime.new
  fileNameBak=$fileNameTime.bak
  
  wget -O $fileNameNew $fileURL$fileName

  fileCRC=`cksum $fileName | awk '{print $1}'`
  fileNewCRC=`cksum $fileNameNew | awk '{print $1}'`
  if [ "$fileCRC" == "$fileNewCRC" ];then
    echo [`System_date`] The downloaded $fileName is same as local. Exit now.
    exit 0
    else
      echo [`System_date`] Backup the old file and rename the new one as now.
      mv $fileName $fileNameBak
      sleep 2
      mv $fileNameNew $fileName
  fi
}
###############################################

File_Download $WAR_URL $WAR_FILE_NAME

systemctl start docker
if [ $? -ne 0 ];then
  echo [`System_date`] The docker is not installed. Install docker at first.
  curl -fsSL https://get.docker.com/ | sh
  systemctl start docker
  else
    echo [`System_date`] The docker is installed.
fi

tomcatExist=`docker image ls | grep tomcat`
if [ -z "$tomcatExist" ];then
  echo [`System_date`] Tomcat docker image is not found. Pull it now.
  docker pull tomcat
  else
    echo [`System_date`] Tomcat docker image is existed.
fi

tomcatRunningID=`docker ps | grep catalina.sh | awk '{print $1}'`
if [ -z "$tomcatRunningID" ];then
  echo [`System_date`] Tomcat docker is not running. Start it now.
  tomcatRunningID=`docker run -d -p 8080:8080 tomcat`
  echo [`System_date`] Sleep 10 seconds.
  sleep 10

  else
    echo [`System_date`] Tomcat docker is running now.
    echo [`System_date`] The CONTAINER ID is $tomcatRunningID.
fi


echo [`System_date`] Copy $WAR_FILE_NAME to Tomcat.
docker cp $WAR_FILE_NAME $tomcatRunningID:/usr/local/tomcat/webapps
echo [`System_date`] Restart Tomcat.
docker exec $tomcatRunningID /usr/local/tomcat/bin/catalina.sh start

echo [`System_date`] Sleep 10 seconds.
sleep 10

curl http://localhost:8080/$WAR_FOLDER/

