#!/bin/bash

set -e
set -x

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/schema-registry
git clone /vagrant/repos/schema-registry.git
pushd schema-registry

git checkout -b debian-$VERSION origin/debian

# Update the release info
export DEBEMAIL="Confluent Packaging <packages@confluent.io>"
dch --newversion ${VERSION/-/\~}-${REVISION} "Release version $VERSION" --urgency low && dch --release --distribution unstable ""
git commit -a -m "Tag Debian release."

git merge --no-edit $BRANCH

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tree=$BRANCH --git-verbose
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs. Signing requires sudo --login because we're
# actually executing this script with sudo to get root permissions, but it
# retains the env vars from the vagrant ssh user.
if [ "x$SIGN" == "xyes" ]; then
    sudo --login debsign `readlink -f confluent-schema-registry_*.changes`
fi
cp confluent-schema-registry_*.build confluent-schema-registry_*.changes confluent-schema-registry_*.tar.gz confluent-schema-registry_*.dsc  confluent-schema-registry_*.deb /vagrant/output/
rm -rf /tmp/confluent
