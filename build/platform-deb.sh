#!/bin/bash

set -e
set -x

# See the kafka-deb script for more explanation. This differs from other
# packages because it has to support different Scala versions.

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/kafka-platform
# platform packaging scripts are stored in the top-level packaging.git repo
git clone /vagrant/ kafka-platform

pushd kafka-platform
git checkout -b debian-$VERSION origin/debian
make -f debian/Makefile debian-control
# Update the release info
export DEBEMAIL="Confluent Packaging <packages@confluent.io>"
rm debian/changelog # Clear out the empty placeholder
dch --create --package confluent-platform --newversion ${DEB_VERSION} "Release version $VERSION" --urgency low && \
    dch --release --distribution unstable "" && cat debian/changelog
git commit -a -m "Tag Debian release."

# The dummy source tree is included in this repository
DUMMY_SOURCE_BRANCH=origin/confluent-platform
git merge --no-edit -m "deb-$VERSION" $DUMMY_SOURCE_BRANCH

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tree=$DUMMY_SOURCE_BRANCH --git-verbose --git-builder="debuild --set-envvar=APPLY_PATCHES=$APPLY_PATCHES --set-envvar=VERSION=$VERSION --set-envvar=SCALA_VERSIONS=\"$SCALA_VERSIONS\" --set-envvar=DEB_VERSION=$DEB_VERSION --set-envvar=KAFKA_DEB_VERSION=$KAFKA_DEB_VERSION --set-envvar=LIBRDKAFKA_DEB_VERSION=$LIBRDKAFKA_DEB_VERSION --set-envvar=DESTDIR=$DESTDIR --set-envvar=PREFIX=$PREFIX --set-envvar=SYSCONFDIR=$SYSCONFDIR --set-envvar=SKIP_TESTS=$SKIP_TESTS -i -I"
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs. Signing requires sudo --login because we're
# actually executing this script with sudo to get root permissions, but it
# retains the env vars from the vagrant ssh user.
if [ "x$SIGN" == "xyes" ]; then
    sudo --login debsign `readlink -f confluent-platform_*.changes`
fi
cp confluent-platform_*.build confluent-platform_*.changes confluent-platform_*.tar.gz confluent-platform_*.dsc confluent-platform-*.deb /vagrant/output/
rm -rf /tmp/confluent
