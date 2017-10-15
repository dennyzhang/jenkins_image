########## How To Use Docker Image ###############
##
##  Image Name: denny/jenkins:1.0
##  Git link: https://github.com/DennyZhang/devops_docker_image/blob/tag_v5/jenkins/Dockerfile_1_0
##  Docker hub link:
##  Build docker image: docker build --no-cache -f Dockerfile_1_0 -t denny/jenkins:1.0 --rm=true .
##  Start jenkins: docker run -p 8080:8080 -p 50000:50000 denny/jenkins:1.0
##  Description: Manage via Jenkins GUI
##################################################
# Base Docker image: https://hub.docker.com/_/jenkins/

FROM jenkins:2.46.3

LABEL maintainer "Denny<contact@dennyzhang.com>"

# Install thinbackup plugin
user root

# Configure Jenkins java options
# timezone: Asia/Shanghai, America/New_York, America/Los_Angeles
# https://www.epochconverter.com/timezones
ENV JENKINS_TIMEZONE "UTC"

# Run groovy
COPY timezone.groovy /usr/share/jenkins/ref/init.groovy.d/timezone.groovy

# Disable ssh host key check
ADD ssh_config /etc/ssh/ssh_config
# Serverspec Check
ADD run_serverspec.sh /usr/sbin/run_serverspec.sh
ADD gitconfig /var/jenkins_home/.gitconfig

# Install jenkins plugins
RUN /usr/local/bin/install-plugins.sh structs:1.8 && \
    ###############################################################
    # Pipeline
    /usr/local/bin/install-plugins.sh bouncycastle-api:2.16.1 && \
    /usr/local/bin/install-plugins.sh pipeline-model-definition:1.1.6 && \
    /usr/local/bin/install-plugins.sh pipeline-graph-analysis:1.4 && \
    /usr/local/bin/install-plugins.sh pipeline-rest-api:2.8 && \
    /usr/local/bin/install-plugins.sh pipeline-stage-view:2.8 && \
    /usr/local/bin/install-plugins.sh pipeline-model-declarative-agent:1.1.1 && \
    /usr/local/bin/install-plugins.sh maven-plugin:2.16 && \
    /usr/local/bin/install-plugins.sh pipeline-stage-tags-metadata:1.1.6 && \
    /usr/local/bin/install-plugins.sh handlebars:1.1.1 && \
    /usr/local/bin/install-plugins.sh pipeline-stage-step:2.2 && \
    /usr/local/bin/install-plugins.sh pipeline-model-extensions:1.1.6 && \
    /usr/local/bin/install-plugins.sh pipeline-milestone-step:1.3.1 && \
    /usr/local/bin/install-plugins.sh workflow-cps-global-lib:2.8 && \
    /usr/local/bin/install-plugins.sh workflow-support:2.14 && \
    /usr/local/bin/install-plugins.sh pipeline-model-api:1.1.6 && \
    /usr/local/bin/install-plugins.sh pipeline-input-step:2.7 && \
    /usr/local/bin/install-plugins.sh pipeline-build-step:2.5 && \
    /usr/local/bin/install-plugins.sh workflow-step-api:2.11 && \
    /usr/local/bin/install-plugins.sh docker-commons:1.7 && \
    /usr/local/bin/install-plugins.sh workflow-durable-task-step:2.12 && \
    /usr/local/bin/install-plugins.sh durable-task:1.14 && \
    /usr/local/bin/install-plugins.sh workflow-basic-steps:2.5 && \
    /usr/local/bin/install-plugins.sh workflow-cps:2.36 && \
    /usr/local/bin/install-plugins.sh workflow-api:2.17 && \
    /usr/local/bin/install-plugins.sh workflow-aggregator:2.5 && \
    ###############################################################
    # https://www.dennyzhang.com/jenkins_benefits
    /usr/local/bin/install-plugins.sh slack:2.2 && \
    /usr/local/bin/install-plugins.sh dashboard-view:2.9.11 && \
    /usr/local/bin/install-plugins.sh timestamper:1.8.8 && \
    /usr/local/bin/install-plugins.sh git:3.3.0 && \
    /usr/local/bin/install-plugins.sh thinBackup:1.9 && \
    /usr/local/bin/install-plugins.sh jobConfigHistory:2.16 && \
    /usr/local/bin/install-plugins.sh build-timeout:1.18 && \
    /usr/local/bin/install-plugins.sh naginator:1.17.2 && \
    /usr/local/bin/install-plugins.sh credentials:2.1.14 && \
    /usr/local/bin/install-plugins.sh plain-credentials:1.4 && \
    /usr/local/bin/install-plugins.sh display-url-api:2.0 && \
    /usr/local/bin/install-plugins.sh junit:1.20 && \
    /usr/local/bin/install-plugins.sh workflow-multibranch:2.15 && \
    /usr/local/bin/install-plugins.sh docker-workflow:1.11 && \
    /usr/local/bin/install-plugins.sh workflow-job:2.11 && \
    /usr/local/bin/install-plugins.sh workflow-scm-step:2.5 && \

# Install serverspec
    apt-get -y update && apt-get install -y --no-install-recommends ruby rake && \
    echo "gem: --no-rdoc --no-ri" >> /etc/gemrc && \
    gem install serverspec -v 2.39.1 && chmod 755 /usr/sbin/run_serverspec.sh && \

# Install basic packages
    apt-get install -y netcat && \

# Install python
    apt-get install -y --no-install-recommends python-pip && \
    pip install GitPython && \
    chown jenkins:jenkins /var/jenkins_home/.gitconfig && \
    # Install basic packages
    apt-get install -y --no-install-recommends vim

user jenkins

WORKDIR /var/jenkins_home

# Verify docker image
RUN ruby --version && rake --version && gem list server && gem --version && \
    ruby --version | grep "2.1.5" && gem --version | grep "2.2.2" && \
    rake --version | grep "10.3.2" && gem list serverspec | grep "2.39.1" && \
    java -version && java -version 2>&1 | grep 1.8.0 && \
    # verify plugin version
    echo "Check workflow-multibranch" && cksum /usr/share/jenkins/ref/plugins/workflow-multibranch.jpi | grep 2966129578 && \
    echo "Check docker-workflow" && cksum /usr/share/jenkins/ref/plugins/docker-workflow.jpi | grep 3372667563 && \
    echo "Check workflow-job" && cksum /usr/share/jenkins/ref/plugins/workflow-job.jpi | grep 4045198933 && \
    echo "Check workflow-scm-step" && cksum /usr/share/jenkins/ref/plugins/workflow-scm-step.jpi | grep 2369925214 && \
    which vim

HEALTHCHECK --interval=5m --timeout=3s \
            CMD curl -I http://localhost:8080 | grep "HTTP/1.1 403 Forbidden" || exit 1
