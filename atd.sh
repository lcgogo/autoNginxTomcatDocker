#!/bin/sh

# 2018.Jan.13th  Lewis Li  ver0.1  New script to deploy Tomcat in a Docker with local war file.

WAR_FILE_NAME=yijava.war
WAR_FOLDER=${WAR_FILE_NAME:0:-4}

curl -fsSL https://get.docker.com/ | sh

systemctl start docker

docker pull tomcat

CONTAINER_ID=`docker run -d -p 8080:8080 tomcat`

docker cp $WAR_FILE_NAME $CONTAINER_ID:/usr/local/tomcat/webapps
docker exec $CONTAINER_ID /usr/local/tomcat/bin/catalina.sh start

curl http://localhost:8080/$WAR_FOLDER/


