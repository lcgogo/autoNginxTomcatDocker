#!/bin/sh
###########################
# History
# Author: Lewis Li  Lcgogo123@163.com  +8613911983435
#
# 2018.Jan.13th  Lewis Li  ver0.1  New script to deploy Tomcat in a Docker with local war file.
# 2018.Jan.13th  Lewis Li  ver0.2  Add file download.
# 2018.Jan.14th  Lewis Li  ver0.3  Add 2 tomcat container in ports 8080 & 8081. Error need fix.
# 2018.Jan.14th  Lewis Li  ver0.4  Add nginx part and rename this script to atnd.sh which means auto_tomcat_nginx_docker.
# 2018.Jan.14th  Lewis Li  ver0.5  Add zip file download.
# 2018.Jan.14th  Lewis Li  ver0.6  Add tomcat ip to tomcat.conf
# 2018.Jan.14th  Lewis Li  ver1.0  Add http code check and release version 1.0
# 2018.Jan.19th  Lewis Li  ver1.1  Move CONSTANT to a seperated file atnd.conf
###########################

############
# Exit Code
# 0 is OK
# 1 is no change
# 2 is error
#############

#############
# CONSTANT
# Example:
# WAR_FILE_NAME=demo.war
# WAR_URL="http://lcgogo-java-demo.oss-cn-beijing.aliyuncs.com/java-demo/target/"
#
# ZIP_FILE_NAME=123.zip
# ZIP_URL="https://github.com/lcgogo/autoTomcatDocker/raw/master/"
export `cat $PWD/atnd.conf`
WAR_URL=${WAR_URL:1:-1}
WAR_FOLDER=${WAR_FILE_NAME:0:-4}
ZIP_URL=${ZIP_URL:1:-1}
#############

####################
# test environment #
####################
if [ -z `rpm -qa | grep unzip` ];then
  yum install -y unzip zip
fi

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
    sleep 3
    fileCRC=`cksum $fileName | awk '{print $1}'`
    fileNewCRC=`cksum $fileNameNew | awk '{print $1}'`
    if [ "$fileCRC" == "$fileNewCRC" ];then
      echo [`System_date`] The downloaded $fileName is same as local.
      echo [`System_date`] Remove $fileNameNew now.
      rm -f $fileNameNew
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

############
# Download #
############
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
  tomcatRunningID=`docker ps | grep catalina.sh | grep "0.0.0.0:$tomcatPort->8080" | awk '{print $1}'`
  #echo $tomcatRunningID
  if [ -z "$tomcatRunningID" ];then
    echo [`System_date`] Tomcat container is not running at port $tomcatPort. Start it now.
    tomcatRunningID=`docker run -d -p $tomcatPort:8080 tomcat`
    echo [`System_date`] Sleep 10 seconds.
    sleep 10
    else
      echo [`System_date`] Tomcat container is running at port $tomcatPort now.
      echo [`System_date`] The CONTAINER ID is $tomcatRunningID.
  fi
  
  echo [`System_date`] Copy $WAR_FILE_NAME to Tomcat.
  docker cp $WAR_FILE_NAME $tomcatRunningID:/usr/local/tomcat/webapps
  echo [`System_date`] Restart Tomcat in container $tomcatRunningID.
  docker exec $tomcatRunningID /usr/local/tomcat/bin/catalina.sh start
  echo [`System_date`] Sleep 10 seconds.
  sleep 10
  
  # Tomcat http code check
  tomcatHttpCode=`curl -o /dev/null -s -w %{http_code} "http://localhost:$tomcatPort/$WAR_FOLDER/"`
  if [ $tomcatHttpCode = 200 ];then
    echo [`System_date`] Tomcat web is ok.
    else
      echo [`System_date`] Tomcat web is error with http code $tomcatHttpCode. Please check http://localhost:$tomcatPort/$WAR_FOLDER/
      exit 2
  fi
done

##############
# Nginx part #
##############

mkdir -p $PWD/nginx/conf $PWD/nginx/html $PWD/nginx/logs
unzip -o $ZIP_FILE_NAME -d $PWD/nginx/html

# Create nginx conf file
tomcatDockerIP=`docker inspect --format '{{.NetworkSettings.IPAddress}}' $tomcatRunningID`
cat > $PWD/nginx/conf/tomcat.conf <<EOF
upstream tomcat {
    ip_hash;
    server $tomcatDockerIP:$tomcatPort;
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

# Stop nginx if any
nginxRunningID=`docker ps | grep nginx | grep "0.0.0.0:80->80" | awk '{print $1}'`
if [ -z "$nginxRunningID" ];then
  echo [`System_date`] Nginx container is not running at port 80. Start it now.
  else
    echo [`System_date`] Nginx container is running, stop it now.
    docker stop $nginxRunningID
fi
echo [`System_date`] Sleep 5 seconds.
sleep 5

# Re-run nginx 
echo [`System_date`] Start nginx container.
nginxRunningID=`docker run -d -p 80:80 -v $PWD/nginx/conf/:/etc/nginx/conf.d/ -v $PWD/nginx/html/:/usr/share/nginx/html/ -v $PWD/nginx/logs:/wwwlogs nginx`
echo [`System_date`] Nginx container is running now. 
echo [`System_date`] Sleep 10 seconds.
sleep 10

# Http check
nginxHttpCode=`curl -o /dev/null -s -w %{http_code} "http://localhost"`
tomcatWARHttpCode=`curl -o /dev/null -s -w %{http_code} "http://localhost/$WAR_FOLDER"`
if [[ $nginxHttpCode = 200 && $tomcatWARHttpCode = 302 ]];then
  echo [`System_date`] Nginx web is ok.
  publicIP=`wget -t 3 -T 15 -qO- http://ipv4.icanhazip.com`
  echo -e [`System_date`] "\033[32;49;1m Completed! \033[39;49;0m" You can access http://localhost/$WAR_FOLDER in a brower to check. 
  echo [`System_date`] If you have a public IP, you can access http://$publicIP/$WAR_FOLDER in brower to double check.
  exit 0
  else
    echo [`System_date`] Nginx web is error with http code $nginxHttpCode. Please check http://localhost
    echo [`System_date`] Tomcat web is error with http code $tomcatWARHttpCode. Please check http://localhost/$WAR_FOLDER
    exit 2
fi
