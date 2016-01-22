#!/bin/bash

set -e
set -x

# Get a fresh copy of the repository. Unlike most of our other packaging
# scripts, this one requires two repositories since the packaging scripts are
# not kept with the open source code.
mkdir -p /tmp/confluent
cd /tmp/confluent

# Debian requires that we generate all the binary packages from one source
# package and Kafka needs one package per Scala version, so this build script
# looks a bit different than others. The control file specifies the versions of
# packages we will generate so we need to generate one including the versions we
# need.

rm -rf /tmp/confluent/kafka-packaging
git clone /vagrant/repos/kafka-packaging.git
pushd kafka-packaging
git remote add upstream /vagrant/repos/kafka.git
git fetch --tags upstream

git checkout -b debian-$VERSION origin/debian-heroku-0-8-2
make -f debian/Makefile debian-control

# generate patch series
make -f debian/Makefile patch-series
# Update the release info
export DEBEMAIL="Heroku Kafka Packaging <dod-kcz@heroku.com>"
dch --newversion "${VERSION/-/\~}-${REVISION}-heroku2" "Release version $VERSION" --urgency low && dch --release --distribution unstable ""
git commit -a -m "Tag Debian release."

git merge --no-edit -m "deb-$VERSION" upstream/$BRANCH

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tree=upstream/$BRANCH --git-verbose --git-builder="debuild --set-envvar=APPLY_PATCHES=$APPLY_PATCHES --set-envvar=VERSION=$VERSION --set-envvar=DESTDIR=$DESTDIR --set-envvar=PREFIX=$PREFIX --set-envvar=SYSCONFDIR=$SYSCONFDIR --set-envvar=INCLUDE_WINDOWS_BIN=$INCLUDE_WINDOWS_BIN -i -I"
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs. Signing requires sudo --login because we're
# actually executing this script with sudo to get root permissions, but it
# retains the env vars from the vagrant ssh user.
if [ "x$SIGN" == "xyes" ]; then
    sudo --login debsign `readlink -f confluent-kafka_*.changes`
fi
cp confluent-kafka_*.build confluent-kafka_*.changes confluent-kafka_*.tar.gz confluent-kafka_*.dsc confluent-kafka-*.deb /vagrant/output/
rm -rf /tmp/confluent
