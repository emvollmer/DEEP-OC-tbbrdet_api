# Dockerfile may have following Arguments:
# tag - tag for the Base image, (e.g. 2.9.1 for tensorflow)
# branch - user repository branch to clone (default: master, another option: test)
#
# To build the image:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> --build-arg arg=value .
# or using default args:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> .
#
# [!] Note: For the Jenkins CI/CD pipeline, input args are defined inside the
# Jenkinsfile, not here!

ARG tag=20.04

# Base image, e.g. tensorflow/tensorflow:2.9.1
FROM ubuntu:${tag}

LABEL maintainer='Elena Vollmer'
LABEL version='0.0.1'
# Deepaas API for TBBRDet Model

# What user branch to clone [!]
ARG branch=master

# Install Ubuntu packages
# - gcc is needed in Pytorch images because deepaas installation might break otherwise (see docs) (it is already installed in tensorflow images)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-utils \
        gnupg \
        lsb-release \
        software-properties-common \
        ca-certificates \
        gcc \
        git \
        curl \
        nano \
        wget \
    && rm -rf /var/lib/apt/lists/*

# install cuda
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin && \
    mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600 && \
    apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub   && \
    add-apt-repository "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /" && \
    apt-get update && \
    apt-get install -y cuda-toolkit-11-6 \
    libcudnn8=8.4.0.27-1+cuda11.6 && \
    rm -rf /var/lib/apt/lists/*

# install python 3.6
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.6 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.6 1 && \
    update-alternatives --set python /usr/bin/python3.6 && \
    rm -rf /var/lib/apt/lists/*

# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone (needed if syncing with NextCloud for training; otherwise remove)
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    mkdir /srv/.rclone/ && \
    touch /srv/.rclone/rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    rm -rf /var/lib/apt/lists/*

ENV RCLONE_CONFIG=/srv/.rclone/rclone.conf

# Initialization scripts
# deep-start can install JupyterLab or VSCode if requested
RUN git clone https://github.com/deephdc/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start

# Necessary for the Jupyter Lab terminal
ENV SHELL /bin/bash

# Install user app
# [!] deployment and install scripts also install python, cuda, cudadnn etc!
# [!] Remember: DEEP API V2 only works with python>=3.6
#RUN curl -o deployment_setup.sh https://raw.githubusercontent.com/emvollmer/tbbrdet_api/master/deployment_setup.sh && \
#    chmod +x deployment_setup.sh && \
#    ./deployment_setup.sh
    
#RUN cd tbbrdet_api && \
#    chmod +x install_TBBRDet.sh && \
#    ./install_TBBRDet.sh && \
#    cd ..

#RUN mkdir -p /srv/tbbrdet_api/models/XYZ/weights && \
#    curl -L https://URL_LINK_T_NEXTCLOUD/best.pt \
#    --output /srv/tbbrdet_api/models/XYZ/weights/best.pt

# Open ports: DEEPaaS (5000), Monitoring (6006), Jupyter (8888)
EXPOSE 5000 6006 8888

# Launch deepaas
CMD ["deepaas-run", "--listen-ip", "0.0.0.0", "--listen-port", "5000"]
