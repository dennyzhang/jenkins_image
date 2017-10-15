########## How To Use Docker Image ###############
##
##  Image Name: denny/jenkins:v3
##  Install docker utility
##  Download docker image: denny/jenkins:v3
##  Boot docker container: docker run -t -d -h jenkins --name my-jenkins --privileged -p 18080:18080 -p 18000:80 -p 9000:9000 denny/jenkins:v3 /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
##
##  Build Image From Dockerfile. docker build -f jenkins_v3.dockerfile -t denny/jenkins:v3 --rm=true .
##
##   18080(Jenkins), 18000(Apache), 9000(sonar)
##
##     ruby --version
##     gem --version
##     gem sources -l
##     head `which gem` | grep ruby
##     head `which bundler` | grep ruby
##     which docker
##     which kitchen
##     which chef-solo
##     source /etc/profile
##     service jenkins start
##      curl -v http://localhost:18080
##
##     service apache2 start
##      curl -v http://localhost:80/
##
##     source /etc/profile
##     sudo $SONARQUBE_HOME/bin/linux-x86-64/sonar.sh start
##       ps -ef | grep sonar
##       curl -v http://localhost:9000
##       ls -lth /var/lib/jenkins/tool
##
##     Built-in jenkins user: chefadmin/ChangeMe123
##################################################

FROM denny/jenkins:v2
ARG jenkins_port="18080"
ARG jenkins_version="2.19"

# Install jenkins jobs
RUN apt-get -y update && \
    apt-get -yqq install git && \

    apt-get install -y bc && \
    # install sshd
    apt-get install -y openssh-server && \
    mkdir -p /root/.ssh/ && \

    cd /tmp && git clone https://github.com/DennyZhang/devops_jenkins.git && \
    cp -r /tmp/devops_jenkins/* /var/lib/jenkins/jobs/ && \
    chown jenkins:jenkins -R /var/lib/jenkins/jobs/ && \

   # Jenkins user
   echo "%jenkins ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/jenkins && \
   chmod 440 /etc/sudoers.d/jenkins && \

   # Create Jenkins demo user
   mkdir -p /var/lib/jenkins/users/demo && \
   wget -O /var/lib/jenkins/users/demo/config.xml https://raw.githubusercontent.com/DennyZhang/devops_docker_image/tag_v2/jenkins/resources/demo_conf_xml && \
   chown -R jenkins:jenkins /var/lib/jenkins/users/demo && \

   # Update Jenkins global setting
   wget -O /var/lib/jenkins/config.xml https://raw.githubusercontent.com/DennyZhang/devops_docker_image/tag_v2/jenkins/resources/jenkins_conf_xml && \

# TODO: use ThinBackup to perform backup and restore: create view

# TODO: fix all possible failures

# Use supervisor to start apache and jenkins in foreground
    apt-get install --no-install-recommends -y supervisor && \
    # TODO: change to better way
    echo '#!/bin/bash -e' > /root/start_apache_foreground.sh && \
    echo "cd /etc/apache2/ && apachectl -d /etc/apache2 -e info -DFOREGROUND" >> /root/start_apache_foreground.sh && \
    chmod o+x /root/start_apache_foreground.sh && \

    # supervisor manage apache2
    echo "[program:apache2]" > /etc/supervisor/conf.d/apache2.conf && \
    echo "command=/root/start_apache_foreground.sh" >> /etc/supervisor/conf.d/apache2.conf && \
    echo "command=/root/start_apache_foreground.sh" >> /etc/supervisor/conf.d/apache2.conf && \
    echo "stdout_logfile=/var/log/apache2.log" >> /etc/supervisor/conf.d/apache2.conf && \
    echo "redirect_stderr=true" >> /etc/supervisor/conf.d/apache2.conf && \

    echo '#!/bin/bash -e' > /root/start_jenkins_foreground.sh && \
    echo "/bin/su -l jenkins --shell=/bin/bash -c '/usr/bin/daemon --name=jenkins --inherit --env=JENKINS_HOME=/var/lib/jenkins --output=/var/log/jenkins/jenkins.log --pidfile=/var/run/jenkins/jenkins.pid -- /usr/bin/java  -Dhudson.diyChunking=false -Djenkins.install.runSetupWizard=false -jar /usr/share/jenkins/jenkins.war --webroot=/var/cache/jenkins/war --httpPort=18080'" >> /root/start_jenkins_foreground.sh && \
    chmod o+x /root/start_jenkins_foreground.sh && \

    # supervisor manage jenkins
    echo "[program:jenkins]" > /etc/supervisor/conf.d/jenkins.conf && \
    echo "command=/root/start_jenkins_foreground.sh" >> /etc/supervisor/conf.d/jenkins.conf && \
    echo "stdout_logfile=/var/log/jenkins.log" >> /etc/supervisor/conf.d/jenkins.conf && \
    echo "redirect_stderr=true" >> /etc/supervisor/conf.d/jenkins.conf && \

    # start service
    service supervisor start && sleep 5 && \

########################################################################################
# Verify status
    dpkg -l jenkins | grep "$jenkins_version" && \
    sudo -u jenkins lsof -i tcp:$jenkins_port && \
    lsof -i tcp:80 && \
    ruby --version | grep "2\.2\.5" && \
    gem list bundle | grep "0\.0\.1" && \
    rubocop --version | grep "0\.44\.1" && \
    foodcritic --version | grep "8\.0\.0" && \
    shellcheck --version | grep "0\.4" && \
    test -f /var/lib/jenkins/jobs/CommonServerCheck/config.xml && \

# Stop services
   service jenkins stop || true && \
   service apache2 stop || true && \
   service supervisor stop || true && \

# clean files to make image smaller
   rm -rf /var/run/jenkins/jenkins.pid && \
   rm -rf /tmp/*
   
CMD ["/bin/bash"]
########################################################################################
