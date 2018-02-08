#!/bin/sh -xe
# Version (e.g. "./build/setup.sh centos centos7")
os_type=$1
os_version=$2

 # Run builds in Container
if [ "$os_type" = "centos" ]; then

    if [ "$os_version" = "container" ]; then

        sudo docker build -t unidata/gempak -f build/docker/Dockerfile.gempak build/docker

    elif [ "$os_version" = "centos6" ]; then

        sudo docker run --rm=true -v `pwd`:/gempak:rw ${os_type}:${os_version} /bin/bash -c "bash -xe /gempak/build/build_rhel.sh ${os_type} ${os_version}"

    elif [ "$os_version" = "centos7" ]; then

        sudo docker run --privileged -d -ti -e "container=docker" -v `pwd`:/gempak:rw  ${os_type}:${os_version}   /usr/sbin/init
        DOCKER_CONTAINER_ID=$(sudo docker ps | grep ${os_version} | awk '{print $1}' | head -1 )
        sudo docker logs $DOCKER_CONTAINER_ID
        sudo docker exec -ti $DOCKER_CONTAINER_ID /bin/bash -xec "bash -xe /gempak/build/build_rhel.sh ${os_type} ${os_version}";
        sudo docker ps -a
        sudo docker stop $DOCKER_CONTAINER_ID
        sudo docker rm -v $DOCKER_CONTAINER_ID

    fi

elif [ "$os_type" = "ubuntu" ]; then

    sudo docker run --rm=true -v `pwd`:/gempak:rw ${os_type}:${os_version} /bin/bash -c "bash -xe /gempak/build/build_ubuntu.sh "

elif [ "$os_type" = "fedora" ]; then

    sudo docker run --rm=true -v `pwd`:/gempak:rw ${os_type}:${os_version} /bin/bash -c "bash -xe /gempak/build/build_rhel.sh ${os_type} ${os_version}"

fi
