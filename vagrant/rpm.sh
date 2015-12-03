#!/bin/bash

set -e
set -x

# Get the VM ready to do the build. This is specifically separated out from the
# build process so we don't have to run it every time we want to build. This
# should really only handle system updates and system-level build dependencies.

yum -y update

# Install Oracle JDK
if ! yum list installed jdk ; then
    declare -r LOCAL_JDK_RPM="/tmp/jdk-7u79-linux-x64.rpm"
    curl -s -L --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/7u79-b15/jdk-7u79-linux-x64.rpm" -o $LOCAL_JDK_RPM
    yum -y install $LOCAL_JDK_RPM
fi

# Install build tools
yum -y install git rpm-build rpm-sign createrepo mock

if [ ! -x /usr/bin/mvn ]; then
    # We need to install maven manually because the Fedora packages are generated
    # targeting Java 7.
    MAVEN_VERSION="3.2.5"
    pushd /tmp
    curl -s -o maven.tar.gz "https://s3-us-west-2.amazonaws.com/confluent-packaging-tools/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
    tar -zxvf maven.tar.gz
    ln -s /tmp/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/bin/mvn
    popd
fi

# These should not be leaking out anywhere with the build output so the values
# don't matter, but we need to specify them or git commands will fail. These are
# setup for root because builds run as root in order to be able to setup file
# permissions properly.
git config --global user.email "contact@confluent.io"
git config --global user.name "Confluent, Inc."
