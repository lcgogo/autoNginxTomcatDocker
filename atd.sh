#!/bin/sh

# 2018.Jan.13th  Lewis Li  ver0.1  New script to deploy Tomcat in a Docker with local war file.

WAR_FILE_NAME=yijava.war
WAR_FOLDER=${WAR_FILE_NAME:0:-4}

systemctl start docker
if [ $? -ne 0 ];then
  echo The docker is not installed. Install docker at first.
  curl -fsSL https://get.docker.com/ | sh
  systemctl start docker
  else
    echo The docker is installed.
fi

tomcatExist=`docker image ls | grep tomcat`
if [ -z "$tomcatExist" ];then
  echo Tomcat docker image is not found. Pull it now.
  docker pull tomcat
  else
    echo Tomcat docker image is existed.
fi

tomcatRunningID=`docker ps | grep catalina.sh | awk '{print $1}'`
if [ -z "$tomcatRunningID" ];then
  echo Tomcat docker is not running. Start it now.
  tomcatRunningID=`docker run -d -p 8080:8080 tomcat`
  else
    echo Tomcat docker is running now.
    echo The CONTAINER ID is $tomcatRunningID.
    echo Copy $WAR_FILE_NAME to Tomcat.
    docker cp $WAR_FILE_NAME $tomcatRunningID:/usr/local/tomcat/webapps
    echo Restart Tomcat.
    docker exec $tomcatRunningID /usr/local/tomcat/bin/catalina.sh start
fi


echo Sleep 10 seconds.
sleep 10

curl http://localhost:8080/$WAR_FOLDER/

