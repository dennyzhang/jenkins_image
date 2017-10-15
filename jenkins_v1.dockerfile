########## How To Use Docker Image ###############
##
##  Image Name: denny/jenkins:v1
##  Install docker utility
##  Download docker image: denny/jenkins:v1
##  Boot docker container: docker run -t -d -h jenkins --name my-jenkins --privileged -p 18080:18080 -p 18000:80 -p 9000:9000 denny/jenkins:v1 /bin/bash
##
##  Build Image From Dockerfile. docker build -f jenkins_v1.dockerfile -t denny/jenkins:v1 --rm=true .
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

FROM ubuntu:14.04
ARG jenkins_port="18080"
ARG jenkins_version="2.19"
ARG jenkins_username="chefadmin"
ARG jenkins_passwd="ChangeMe123"

# Basic setup
RUN apt-get -y update && \
    apt-get -yqq install wget curl vim lsof && \
    apt-get install -y nmap unzip && \
    apt-get install -y git build-essential && \
    apt-get install -y python-dev libevent-dev python-pip && \
    apt-get install -y libxml2-dev libxslt1-dev zlib1g-dev libssl-dev libreadline6-dev libyaml-dev && \
    # TODO: use fixed version
    pip install elasticsearch && \
    pip install flask && \

# Install Ruby 2.2
   apt-get -yqq install software-properties-common python-software-properties && \
   apt-get -yqq install python-software-properties && \
   apt-add-repository -y ppa:brightbox/ruby-ng && \
   apt-get -yqq update && \
   apt-get -yqq install ruby2.2 ruby2.2-dev && \
   rm -rf /usr/bin/ruby && \
   ln -s /usr/bin/ruby2.2 /usr/bin/ruby && \
   rm -rf /usr/local/bin/ruby /usr/local/bin/gem /usr/local/bin/bundle && \
   gem install bundle -v "0.0.1" && \
   gem install rubocop -v "0.44.1"  && \
   gem install foodcritic -v "8.0.0" && \

# Install apache2
    apt-get install -yqq apache2 && \

# Install Jenkins with specific version
    apt-get install -yqq daemon psmisc && \
    apt-get install -yqq java-common openjdk-7-jre-headless default-jre-headless && \
    curl -o /tmp/jenkins_${jenkins_version}_all.deb http://mirror.xmission.com/jenkins/debian/jenkins_${jenkins_version}_all.deb && \
    # avoid sysv-rc error
    sed -i 's/exit 101/exit 0/g' /usr/sbin/policy-rc.d && \
    dpkg -i /tmp/jenkins_${jenkins_version}_all.deb && \
    # Change it back
    sed -i 's/exit 0/exit 101/g' /usr/sbin/policy-rc.d && \

# Jenkins parameter skip setup wizard, this also leave Jenkins insecure-by-default
   echo "JAVA_ARGS=\"$JAVA_ARGS -Dhudson.diyChunking=false -Djenkins.install.runSetupWizard=false\"" >> /etc/default/jenkins && \
# Reconfigure Jenkins port
   sed -i "s/HTTP_PORT=.*/HTTP_PORT=$jenkins_port/g" /etc/default/jenkins && \

# start services
   service apache2 restart && \
   service jenkins restart && sleep 10 && \

   # Install Matrix Authorization Strategy Plugin
   curl -o /tmp/jenkins-cli.jar http://localhost:$jenkins_port/jnlpJars/jenkins-cli.jar && \
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://updates.jenkins-ci.org/latest/icon-shim.hpi && \
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://updates.jenkins-ci.org/latest/matrix-auth.hpi && \
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://updates.jenkins-ci.org/latest/simple-theme-plugin.hpi && \
   # Install naginator Jenkins plugin
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://mirrors.jenkins-ci.org/plugins/bouncycastle-api/2.16.0/bouncycastle-api.hpi && \
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://updates.jenkins-ci.org/download/plugins/structs/1.5/structs.hpi && \
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://mirrors.jenkins-ci.org/plugins/junit/1.18/junit.hpi && \
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://mirrors.jenkins-ci.org/plugins/script-security/1.22/script-security.hpi && \
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://mirrors.jenkins-ci.org/plugins/matrix-project/1.7.1/matrix-project.hpi && \
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://mirrors.jenkins-ci.org/plugins/naginator/1.17.2/naginator.hpi && \
   # Install ThinBackup plugin
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ install-plugin http://mirrors.jenkins-ci.org/plugins/thinBackup/1.7.4/thinBackup.hpi && \

   service jenkins restart && sleep 5 && \

##################################################
# Jenkins Customization For Security

   # Create Jenkins admin user
   # reset admin password
   mkdir -p /var/lib/jenkins/users/chefadmin && \
   # TODO
   wget -O /var/lib/jenkins/users/chefadmin/config.xml https://raw.githubusercontent.com/DennyZhang/devops_docker_image/tag_v2/jenkins/resources/chefadmin_conf_xml && \
   chown -R jenkins:jenkins /var/lib/jenkins/users/ && \

   # Anonymous: Overall: Read; Job: Build/Cancel/Create/Delete/Read/Workspace
   # Update Jenkins global setting: enable security by default. Anonymous users can trigger jobs
   wget -O /var/lib/jenkins/config.xml https://raw.githubusercontent.com/DennyZhang/devops_docker_image/tag_v2/jenkins/resources/jenkins_conf_xml && \
   chown -R jenkins:jenkins /var/lib/jenkins/config.xml && \

# Configure jenkins ssh
    mkdir -p /var/lib/jenkins/.ssh && \

    # jenkins ssh config
    > /var/lib/jenkins/.ssh/config && \
    echo "Host *" >> /var/lib/jenkins/.ssh/config && \
    echo "  User git" >> /var/lib/jenkins/.ssh/config && \
    echo "  StrictHostKeyChecking no" >> /var/lib/jenkins/.ssh/config && \
    echo "" >> /var/lib/jenkins/.ssh/config && \
    echo "Host github.com" >> /var/lib/jenkins/.ssh/config && \
    echo "  User git" >> /var/lib/jenkins/.ssh/config && \
    echo "  IdentityFile /var/lib/jenkins/.ssh/github_id_rsa" >> /var/lib/jenkins/.ssh/config && \
    echo "  StrictHostKeyChecking no" >> /var/lib/jenkins/.ssh/config && \

    chown -R jenkins:jenkins /var/lib/jenkins/.ssh && \

# Sonar Env
    echo "export SONARQUBE_HOME=/var/lib/jenkins/tool/sonarqube-4.5.6" >> /etc/profile.d/sonar.sh && \
    echo "export SONAR_RUNNER_HOME=/var/lib/jenkins/tool/sonar-scanner-2.5" >> /etc/profile.d/sonar.sh && \
    echo "export PATH=\$PATH:\$SONARQUBE_HOME/bin/linux-x86-64:\$SONAR_RUNNER_HOME/bin" >> /etc/profile.d/sonar.sh && \
    chmod o+x /etc/profile.d/sonar.sh && \

# Jenkins ThinBackup
    mkdir -p /var/lib/jenkins/backup && chown jenkins:jenkins /var/lib/jenkins/backup && \

# change locale
    locale-gen --lang en_US.UTF-8 && \
    > /etc/profile.d/locale.sh && \
    echo "export LANG=\"en_US.UTF-8\"" >> /etc/profile.d/locale.sh && \
    echo "export LC_ALL=\"en_US.UTF-8\"" >> /etc/profile.d/locale.sh && \
    echo ". /etc/profile.d/locale.sh" >> /var/lib/jenkins/.bashrc && \
    chown jenkins:jenkins /var/lib/jenkins/.bashrc && \

# start jenkins
   service jenkins restart && sleep 5 && \

# login Jenkins
   java -jar /tmp/jenkins-cli.jar -s http://localhost:$jenkins_port/ login --username "$jenkins_username" --password "$jenkins_passwd" && \

########################################################################################
# Verify status
    dpkg -l jenkins | grep "$jenkins_version" && \
    service jenkins status | grep "is running with" && \
    sudo -u jenkins lsof -i tcp:$jenkins_port && \
    java -jar /tmp/jenkins-cli.jar -s http://localhost:18080/ list-jobs && \
    lsof -i tcp:80 && \
    ruby --version | grep "2\.2\.5" && \
    gem list bundle | grep "0\.0\.1" && \
    rubocop --version | grep "0\.44\.1" && \
    foodcritic --version | grep "8\.0\.0" && \

# Stop services
   service jenkins stop && \
   service apache2 stop && \

# clean files to make image smaller
   rm -rf /var/run/jenkins/jenkins.pid && \
   rm -rf /tmp/*
   
CMD ["/bin/bash"]
########################################################################################
