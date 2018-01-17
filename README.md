# autoTomcatDocker
This tool is used to create a local Jenkins environment to build Java by Maven and 2 docker containers to run Nginx and Tomcat.

1. After install docker, create a Jenkins container with BlueOcean plugin.
```
docker run \
  --rm \
  -d \
  -u root \
  -p 8080:8080 \
  -v jenkins-data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$HOME":/home \
  jenkinsci/blueocean
```

2. Configure Jenkins with the Guide if you use maven to build https://jenkins.io/doc/tutorials/build-a-java-app-with-maven/

3. Add "echo $BUILD_NUMBER > target/BUILD_NUMBER.txt" to Jenkinsfile stage('Deliver') part. New Jenkinsfile should be like below

```
pipeline {
    agent {
        docker {
            image 'maven:3-alpine'
            args '-v /root/.m2:/root/.m2'
        }
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn -B -DskipTests clean package'
            }
        }
        stage('Test') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }
        stage('Deliver') {
            steps {
                sh './jenkins/scripts/deliver.sh'
                sh 'echo $BUILD_NUMBER > target/BUILD_NUMBER.txt'
            }
        }
    }
}
```

4. Commit the change and rerun BlueOcean RUN (manual or using API? Planning). 

```
[root@izm5e3r1zr2tv4mzafpbiaz simple-java-maven-app]# git add Jenkinsfile
[root@izm5e3r1zr2tv4mzafpbiaz simple-java-maven-app]# git commit -m "test"
[master 0f1a878] test
 1 file changed, 1 insertion(+), 1 deletion(-)
```

Assume the build creates 2 output files: one is a zip file and the other is a war file at local or upload to a website. (local file is unavaiable now. Planning.)

5. Run install.sh and input the local war file full path or url and the local zip file full path or url.

6. Open a browser to access http://localhost to check the result (or use frontend auto test tools).

7. If the result is OK, package the docker images with test tag and deliver to test environment by ansible.

8. If the test cases are ok, change the docker images with stage tag and deliver to stage environment.

9. If the test cases are error, redeploy the old image in test environment.

10. If the images in stage environment are ok, use K8s to deploy in production environment.
