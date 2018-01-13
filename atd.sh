#!/bin/sh

# 2018.Jan.13th  Lewis Li  ver0.1  New script to deploy Tomcat in a Docker with local war file.

WAR_FILE_NAME=yijava.war
WAR_FOLDER=${WAR_FILE_NAME:0:-4}

###############################################
# function System_date
function System_date(){
echo `date +%Y-%m-%d-%H:%M:%S`
}
###############################################

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

