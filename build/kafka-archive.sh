#!/bin/bash

set -e
set -x

# Get a fresh copy of the repository. Unlike most of our other packaging
# scripts, this one requires three repositories since the packaging scripts are
# not kept with the open source code and because we also need to integrate
# the proactive support code.
BUILDROOT=/tmp/confluent
mkdir -p $BUILDROOT
cd $BUILDROOT

###
### Proactive Support
###
### Note: By convention we must build from the branch of the same name as the Kafka version
###       (here: $VERSION) we are integrating with.
for PS_PKG in $PS_PACKAGES; do
  rm -rf $BUILDROOT/$PS_PKG
  git clone /vagrant/repos/$PS_PKG.git
  pushd $BUILDROOT/$PS_PKG
  git checkout origin/$VERSION
  # Sanitize checkout directory
  git reset --hard HEAD
  git status --ignored --porcelain | cut -d ' ' -f 2 | xargs rm -rf
  popd
done

###
### Kafka
###
rm -rf $BUILDROOT/kafka-packaging
git clone /vagrant/repos/kafka-packaging.git
pushd kafka-packaging
git remote add upstream /vagrant/repos/kafka.git
git fetch --tags upstream

git checkout -b archive-$VERSION origin/archive
git merge upstream/$BRANCH
for SCALA_VERSION in $SCALA_VERSIONS; do
    SCALA_VERSION=$SCALA_VERSION make distclean
    SCALA_VERSION=$SCALA_VERSION make archive
    cp *.zip *.tar.gz /vagrant/output/
done
popd
rm -rf $BUILDROOT
