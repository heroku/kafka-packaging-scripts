#!/bin/bash

set -e
set -x

# Repo name
NAME=librdkafka

# To maintain compatibility with the official Debian librdkafka package
# we use the same name (but a different vendor version string) and thus
# skip the confluent- prefix on this packlage.
PKG_BASENAME=librdkafka   # will have '1' and '-dev' appended

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

# Extract librdkafka's branch name without origin/
RDKAFKA_BRANCH=${BRANCH##*/}

VERSION=${VERSION//-/\~}

# Format version as: <librdkafka_version>~1<vendor><vendor_version>
VERSION="${RDKAFKA_BRANCH}~1confluent${VERSION}"

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/${NAME}
git clone /vagrant/repos/${NAME}.git
pushd ${NAME}

DEB_BRANCH=debian-${VERSION//\~/_}

git checkout -b $DEB_BRANCH origin/debian

# Update the release info
export DEBEMAIL="Heroku Kafka Packaging <dod-kcz@heroku.com>"
dch --newversion ${VERSION/-/\~}-${REVISION} "Release version $VERSION" --urgency low && dch --release --distribution unstable ""
git commit -a -m "Tag Debian release."

git merge --no-edit $BRANCH

# Enable this if orig.tar.gz tarballs are needed
if true ; then
    make archive
    mkdir -p ../tarballs || true
    mv librdkafka-${VERSION}.tar.gz ../tarballs/librdkafka_${VERSION}.orig.tar.gz
    mv librdkafka-${VERSION}.zip ../tarballs/librdkafka_${VERSION}.orig.zip
fi


# Install Build-Depends:
sudo apt-get install -y zlib1g-dev libssl-dev libsasl2-dev

git-buildpackage -us -uc --git-debian-branch=$DEB_BRANCH --git-upstream-tree=$BRANCH --git-verbose --git-builder="debuild --set-envvar=APPLY_PATCHES=$APPLY_PATCHES --set-envvar=VERSION=$VERSION --set-envvar=DESTDIR=$DESTDIR --set-envvar=PREFIX=$PREFIX --set-envvar=SYSCONFDIR=$SYSCONFDIR --set-envvar=SKIP_TESTS=$SKIP_TESTS -i -I"

popd

pushd build-area

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs. Signing requires sudo --login because we're
# actually executing this script with sudo to get root permissions, but it
# retains the env vars from the vagrant ssh user.
if [ "x$SIGN" == "xyes" ]; then
    sudo --login debsign `readlink -f ${PKG_BASENAME}_*.changes`
fi
cp ${PKG_BASENAME}*.build ${PKG_BASENAME}*.changes ${PKG_BASENAME}*.tar.gz ${PKG_BASENAME}*.dsc  ${PKG_BASENAME}*.deb /vagrant/output/

popd

rm -rf /tmp/confluent
