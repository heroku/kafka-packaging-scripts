#!/bin/bash

set -e
set -x

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/camus
git clone /vagrant/repos/camus.git
pushd camus

git checkout -b debian-$VERSION origin/debian

# Update the release info
export DEBEMAIL="Heroku Kafka Packaging <dod-kcz@heroku.com>"
dch --newversion ${VERSION/-/\~}-${REVISION} "Release version $VERSION" --urgency low && dch --release --distribution unstable ""
git commit -a -m "Tag Debian release."

git merge --no-edit $BRANCH

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tree=$BRANCH --git-verbose --git-builder="debuild --set-envvar=APPLY_PATCHES=$APPLY_PATCHES --set-envvar=VERSION=$VERSION --set-envvar=DESTDIR=$DESTDIR --set-envvar=PREFIX=$PREFIX --set-envvar=SYSCONFDIR=$SYSCONFDIR --set-envvar=SKIP_TESTS=$SKIP_TESTS -i -I"
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs. Signing requires sudo --login because we're
# actually executing this script with sudo to get root permissions, but it
# retains the env vars from the vagrant ssh user.
if [ "x$SIGN" == "xyes" ]; then
    sudo --login debsign `readlink -f confluent-camus_*.changes`
fi
cp confluent-camus_*.build confluent-camus_*.changes confluent-camus_*.tar.gz confluent-camus_*.dsc  confluent-camus_*.deb /vagrant/output/
rm -rf /tmp/confluent
