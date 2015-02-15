#!/bin/bash

set -e
set -x

# Get the VM ready to do the build. This is specifically separated out from the
# build process so we don't have to run it every time we want to build. This
# should really only handle system updates and system-level build dependencies.

yum -y update

JDK_VERSION="jdk1.6.0_45"
JDK_SHORT_VERSION="6u45"

curl -s -o "/tmp/jdk-${JDK_SHORT_VERSION}-linux-x64-rpm.bin" "https://s3-us-west-2.amazonaws.com/confluent-packaging-tools/jdk-6u45-linux-x64-rpm.bin"
sh "/tmp/jdk-${JDK_SHORT_VERSION}-linux-x64-rpm.bin"

yum -y install git rpm-build rpm-sign createrepo

alternatives --install /usr/bin/java java "/usr/java/${JDK_VERSION}/jre/bin/java" 1000000
alternatives --install /usr/bin/javaws javaws "/usr/java/${JDK_VERSION}/jre/bin/javaws" 1000000
alternatives --install /usr/bin/javac javac "/usr/java/${JDK_VERSION}/bin/javac" 1000000
alternatives --set java "/usr/java/${JDK_VERSION}/jre/bin/java"
alternatives --set javaws "/usr/java/${JDK_VERSION}/jre/bin/javaws"
alternatives --set javac "/usr/java/${JDK_VERSION}/bin/javac"

# We need to install maven manually because the Fedora packages are generated
# targeting Java 7.
MAVEN_VERSION="3.2.5"
pushd /tmp
curl -s -o maven.tar.gz "https://s3-us-west-2.amazonaws.com/confluent-packaging-tools/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
tar -zxvf maven.tar.gz
ln -s /tmp/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/bin/mvn
popd

# These should not be leaking out anywhere with the build output so the values
# don't matter, but we need to specify them or git commands will fail. These are
# setup for root because builds run as root in order to be able to setup file
# permissions properly.
git config --global user.email "contact@confluent.io"
git config --global user.name "Confluent, Inc."
