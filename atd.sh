#!/bin/sh

# 2018.Jan.13th  Lewis Li  ver0.1  New script to deploy Tomcat in a Docker with local war file.
# 2018.Jan.13th  Lewis Li  ver0.2  Add file download.
# 2018.Jan.14th  Lewis Li  ver0.3  Add 2 tomcat container in ports 8080 & 8081

WAR_FILE_NAME=yijava.war
WAR_URL="https://github.com/lcgogo/autoTomcatDocker/raw/master/"
WAR_FOLDER=${WAR_FILE_NAME:0:-4}

# Exit Code
# 0 is OK
# 1 is no change
# 2 is error

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
  if [ -e $fileName ];then
    wget -O $fileNameNew $fileURL$fileName

    fileCRC=`cksum $fileName | awk '{print $1}'`
    fileNewCRC=`cksum $fileNameNew | awk '{print $1}'`
    if [ "$fileCRC" == "$fileNewCRC" ];then
      echo [`System_date`] The downloaded $fileName is same as local. Exit now.
      exit 1
      else
        echo [`System_date`] Backup the old file and rename the new one as now.
        mv $fileName $fileNameBak
        sleep 2
        mv $fileNameNew $fileName
    fi
  else
    wget $fileURL$fileName
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

for port in 8080 8081;do
  #echo port
  tomcatRunningID=`docker ps | grep catalina.sh | grep "0.0.0.0:$port->8080" | awk '{print $1}'`
  #echo $tomcatRunningID
  if [ -z "$tomcatRunningID" ];then
    echo [`System_date`] Tomcat docker is not running at port $port. Start it now.
    tomcatRunningID=`docker run -d -p $port:8080 tomcat`
    echo [`System_date`] Sleep 10 seconds.
    sleep 10
  
    else
      echo [`System_date`] Tomcat docker is running at port $port now.
      echo [`System_date`] The CONTAINER ID is $tomcatRunningID.
  fi
  
  
  echo [`System_date`] Copy $WAR_FILE_NAME to Tomcat.
  docker cp $WAR_FILE_NAME $tomcatRunningID:/usr/local/tomcat/webapps
  echo [`System_date`] Restart Tomcat in container $tomcatRunningID.
  docker exec $tomcatRunningID /usr/local/tomcat/bin/catalina.sh start
  
  echo [`System_date`] Sleep 10 seconds.
  sleep 10
  
  curl http://localhost:$port/$WAR_FOLDER/
done
