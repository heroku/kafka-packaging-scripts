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
if [ "$PS_ENABLED" = "yes" ]; then
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
fi

###
### Kafka
###

# Debian requires that we generate all the binary packages from one source
# package and Kafka needs one package per Scala version, so this build script
# looks a bit different than others. The control file specifies the versions of
# packages we will generate so we need to generate one including the versions we
# need.

rm -rf $BUILDROOT/kafka-packaging
git clone /vagrant/repos/kafka-packaging.git
pushd kafka-packaging
git remote add upstream /vagrant/repos/kafka.git
git fetch --tags upstream

git checkout -b debian-$VERSION origin/debian
make -f debian/Makefile debian-control
# We use this custom make target to create the desired [debian/]patches/series
# file depending on whether Proactive Support integration is enabled or not.
make -f debian/Makefile patch-series
# Update the release info
export DEBEMAIL="Confluent Packaging <packages@confluent.io>"
dch --newversion ${VERSION/-/\~}-${REVISION} "Release version $VERSION" --urgency low && dch --release --distribution unstable ""
git commit -a -m "Tag Debian release."

git merge --no-edit -m "deb-$VERSION" upstream/$BRANCH

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tree=upstream/$BRANCH --git-verbose --git-builder="debuild --set-envvar=APPLY_PATCHES=$APPLY_PATCHES --set-envvar=VERSION=$VERSION --set-envvar=DESTDIR=$DESTDIR --set-envvar=PREFIX=$PREFIX --set-envvar=SYSCONFDIR=$SYSCONFDIR --set-envvar=INCLUDE_WINDOWS_BIN=$INCLUDE_WINDOWS_BIN --set-envvar=PS_ENABLED=$PS_ENABLED --set-envvar=PS_PACKAGES=\"$PS_PACKAGES\" --set-envvar=PS_CLIENT_PACKAGE=$PS_CLIENT_PACKAGE --set-envvar=CONFLUENT_VERSION=$CONFLUENT_VERSION --set-envvar=SKIP_TESTS=$SKIP_TESTS -i -I"
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs. Signing requires sudo --login because we're
# actually executing this script with sudo to get root permissions, but it
# retains the env vars from the vagrant ssh user.
if [ "x$SIGN" == "xyes" ]; then
    sudo --login debsign `readlink -f confluent-kafka_*.changes`
fi
cp confluent-kafka_*.build confluent-kafka_*.changes confluent-kafka_*.tar.gz confluent-kafka_*.dsc confluent-kafka-*.deb /vagrant/output/
rm -rf $BUILDROOT
