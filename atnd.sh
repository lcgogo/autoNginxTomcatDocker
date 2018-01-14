#!/bin/sh

# 2018.Jan.13th  Lewis Li  ver0.1  New script to deploy Tomcat in a Docker with local war file.
# 2018.Jan.13th  Lewis Li  ver0.2  Add file download.
# 2018.Jan.14th  Lewis Li  ver0.3  Add 2 tomcat container in ports 8080 & 8081. Error need fix.
# 2018.Jan.14th  Lewis Li  ver0.4  Add nginx part.
# 2018.Jan.14th  Lewis Li  ver0.5  Add zip file download.

#############
# CONSTANT
WAR_FILE_NAME=yijava.war
WAR_URL="https://github.com/lcgogo/autoTomcatDocker/raw/master/"
WAR_FOLDER=${WAR_FILE_NAME:0:-4}

ZIP_FILE_NAME=123.zip
ZIP_URL="https://github.com/lcgogo/autoTomcatDocker/raw/master/"

# Exit Code
# 0 is OK
# 1 is no change
# 2 is error
#############

# test environment #
yum install -y unzip zip

###############################################
# function System_date
function System_date(){
  echo `date +%Y-%m-%d-%H:%M:%S`
}
###############################################

###############################################
# fucntion File_Download
#
# Return code 
# 0 updated local file success
# 1 no update because local file is same as remote

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
      echo [`System_date`] The downloaded $fileName is same as local.
      return 1
      else
        echo [`System_date`] Backup the old file and rename the new one as now.
        mv $fileName $fileNameBak
        sleep 2
        mv $fileNameNew $fileName
        return 0
    fi
  else
    wget $fileURL$fileName
    return 0
  fi
}
###############################################


File_Download $WAR_URL $WAR_FILE_NAME
warDownloadResult=$?
File_Download $ZIP_URL $ZIP_FILE_NAME
zipDownloadResult=$?

if [[ "$warDownloadResult" -eq 1 && "$zipDownloadResult" -eq 1 ]];then
  echo [`System_date`] Both remote zip file and war file are same as local. Exit now.
  exit 1
  #elif 
fi


##################
# Docker prepare #
##################
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

nginxExist=`docker image ls | grep nginx`
if [ -z "$nginxExist" ];then
  echo [`System_date`] Nginx docker image is not found. Pull it now.
  docker pull nginx
  else
    echo [`System_date`] Nginx docker image is existed.
fi

###############
# Tomcat part #
###############

#for tomcatPort in 8080 8081;do
for tomcatPort in 8080;do
  #echo tomcatPort
  tomcatRunningID=`docker ps | grep catalina.sh | grep "0.0.0.0:$tomcatPort->8080" | awk '{print $1}'`
  #echo $tomcatRunningID
  if [ -z "$tomcatRunningID" ];then
    echo [`System_date`] Tomcat docker is not running at port $tomcatPort. Start it now.
    tomcatRunningID=`docker run -d -p $tomcatPort:8080 tomcat`
    echo [`System_date`] Sleep 10 seconds.
    sleep 10
  
    else
      echo [`System_date`] Tomcat docker is running at port $tomcatPort now.
      echo [`System_date`] The CONTAINER ID is $tomcatRunningID.
  fi
  
  
  echo [`System_date`] Copy $WAR_FILE_NAME to Tomcat.
  docker cp $WAR_FILE_NAME $tomcatRunningID:/usr/local/tomcat/webapps
  echo [`System_date`] Restart Tomcat in container $tomcatRunningID.
  docker exec $tomcatRunningID /usr/local/tomcat/bin/catalina.sh start
  
  echo [`System_date`] Sleep 10 seconds.
  sleep 10
  
  curl http://localhost:$tomcatPort/$WAR_FOLDER/
done

##############
# Nginx part #
##############

mkdir -p $PWD/nginx/conf $PWD/nginx/html $PWD/nginx/logs

cat > $PWD/nginx/conf/tomcat.conf <<EOF
upstream tomcat {
    ip_hash;
    server 127.0.0.1:8080;
}
EOF

cat > $PWD/nginx/conf/defaul.conf <<'EOF'
server {
    listen       80;
    server_name  localhost;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header REMOTE-HOST $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://tomcat;
    }

    location ~.*\.(html|jpg|jpeg|png|bmp|gif|ico|mp3|mid|wma|mp4|swf|flv|rar|zip|txt|doc|ppt|xls|pdf|js|css)$ {
        root   /usr/share/nginx/html;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

}
EOF

docker run -d -p 80:80 -v $PWD/nginx/conf/:/etc/nginx/conf.d/ -v $PWD/nginx/html/:/usr/share/nginx/html/ -v $PWD/nginx/logs:/wwwlogs nginx


exit 0
