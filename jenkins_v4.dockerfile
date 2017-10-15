########## How To Use Docker Image ###############
##
##  Image Name: denny/jenkins:v4
##  Install docker utility
##  Download docker image: denny/jenkins:v4
##  Boot docker container: docker run -t -d -h jenkins --name my-jenkins --privileged -p 18080:18080 -p 18000:80 -p 9000:9000 denny/jenkins:v4 /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
##
##  Build Image From Dockerfile. docker build -f jenkins_v4.dockerfile -t denny/jenkins:v4 --rm=true .
##################################################

FROM denny/jenkins:v3
ARG jenkins_port="18080"

HEALTHCHECK --interval=5m --timeout=3s \
            CMD curl -f http://localhost/:18080 || exit 1
CMD ["/bin/bash"]
########################################################################################
