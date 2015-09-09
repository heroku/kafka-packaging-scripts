#!/bin/bash

set -e
set -x

MYSELF=`basename $0`
MY_DIR=`echo $(cd $(dirname $0); pwd)`

. $MY_DIR/settings.sh
. $MY_DIR/aws.sh
. $MY_DIR/versioning_helpers.sh

# We must export this env variable, which is defined in settings.sh, for the subsequent steps to work.
export PACKAGES_BUCKET

OUTPUT="${MY_DIR}/${OUTPUT_DIRECTORY}"
DEPLOYED="${MY_DIR}/${DEPLOYED_DIRECTORY}"
REPO_RELEASE_SUBDIR=`rpm_version_major_minor $CONFLUENT_VERSION`

# Clean up deployment files from prior attempts
rm -rf "${DEPLOYED}"

# Note that all files are organized first by packaging system, then by
# release. Organizing by packaging system at the top level will make it easier
# to move things around if we ever decide to change how we distribute
# packages. The organization by release is important for the packaging systems
# where people may want to pin to specific releases easily.

############
# Archives #
############
# for direct user download, including packaged up deb/rpm
mkdir -p "${DEPLOYED}/archive/${REPO_RELEASE_SUBDIR}/"
for SCALA_VERSION in $SCALA_VERSIONS; do
    # `cp -p` preserves last modified time, which minimizes duplicate uploads for files already existing in S3.
    cp -p "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}.tar.gz" \
          "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}.zip" \
          "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}-deb.tar.gz" \
          "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}-rpm.tar.gz" \
          "${DEPLOYED}/archive/${REPO_RELEASE_SUBDIR}/"
done
# Generate signatures for verification
pushd ${DEPLOYED}/archive/${REPO_RELEASE_SUBDIR}
FILES=`ls ./*`
for file in $FILES; do
    shasum -a 1 $file > ${file}.sha1.txt
    shasum -a 256 $file > ${file}.sha256.txt
done
popd


#######
# RPM #
#######
mkdir -p "${DEPLOYED}/rpm/${REPO_RELEASE_SUBDIR}/"
# `cp -p` preserves last modified time, which minimizes duplicate uploads for files already existing in S3.
eval cp -p "${OUTPUT}/*.rpm" "${DEPLOYED}/rpm/${REPO_RELEASE_SUBDIR}/"
rm -f "${DEPLOYED}/rpm/${REPO_RELEASE_SUBDIR}/README.rpm"

# These get copied into place, then we generate/update the index files.
#
# Sometimes createrepo fails for no apparent reason but works fine when we run it again.
# Error message: "Could not find valid repo at: /vagrant/_deployed/rpm/1.0/"
# See https://lists.fedorahosted.org/pipermail/copr-commits/2013-November/000256.html
vagrant ssh rpm -- createrepo --update "/vagrant/_deployed/rpm/${REPO_RELEASE_SUBDIR}/" || \
  vagrant ssh rpm -- createrepo --update "/vagrant/_deployed/rpm/${REPO_RELEASE_SUBDIR}/"


# GPG keys -- we want to provide 1 per signed repository so that they are
# associated with that repository instead of a single global key. We should only
# have one, but this is useful if the key is ever compromised. Note that we
# generate one for the deb repo even though we're not uploading the rest of it
# via this path.
mkdir -p "${DEPLOYED}/deb/${REPO_RELEASE_SUBDIR}/"
if [ "$SIGN" == "yes" ]; then
    gpg --export --armor --output "${DEPLOYED}/rpm/${REPO_RELEASE_SUBDIR}/archive.key" $SIGN_KEY
    gpg --export --armor --output "${DEPLOYED}/deb/${REPO_RELEASE_SUBDIR}/archive.key" $SIGN_KEY
fi

# Now we can actually run the upload process for all the files we've arranged
# for archives and RPMs. Debian upload to S3 is managed separately.
aws s3 sync "${DEPLOYED}/" "s3://${PACKAGES_BUCKET}${PACKAGES_BUCKET_PREFIX}/"


##########
# Debian #
##########
# Because aptly manages an S3-based repository better than we would
# manage the uploads we just let it do everything.

sed -e "s%PWD%${MY_DIR}%" -e "s%BUCKET%${PACKAGES_BUCKET}%" -e "s%PREFIX%${PACKAGES_BUCKET_PREFIX}%" -e "s%VERSION%${REPO_RELEASE_SUBDIR}%" -e "s%REGION%${REGION}%" aptly.conf.template > aptly.conf
REPO="confluent-${REPO_RELEASE_SUBDIR}"
REPO_DISTRIBUTION="stable"
APTLY_OPTS="-config=aptly.conf"
APTLY_REPO_OPTS="-distribution=${REPO_DISTRIBUTION} -component=main -architectures=all"

# Remove any prior aptly pool etc. so that we don't accidentally include "other" packages,
# which may have slipped into the pool because of e.g. previous manual testing.
rm -rf "./.aptly"
aptly "${APTLY_OPTS}" repo list | grep $REPO || aptly "${APTLY_OPTS}" repo create ${APTLY_REPO_OPTS} $REPO
aptly "${APTLY_OPTS}" repo add "$REPO" "${OUTPUT}"

SNAPSHOT_NAME="confluent-${CONFLUENT_VERSION}-${REVISION}"
# If needed, unpublish the repo/distribution.
# This must be done before we can remove an associated existing snapshot (if any).
set +e
aptly "${APTLY_OPTS}" publish list -raw=false | grep -F "s3:${PACKAGES_BUCKET}:./${REPO_DISTRIBUTION}" | grep -q "$SNAPSHOT_NAME"
if [ $? -eq 0 ]; then
  set -e
  aptly "${APTLY_OPTS}" publish drop "$REPO_DISTRIBUTION" "s3:${PACKAGES_BUCKET}:."
fi
set -e

# If needed, remove any existing snapshot of the same name.
set +e
aptly -config=aptly.conf snapshot show "$SNAPSHOT_NAME"
if [ $? -eq 0 ]; then
  set -e
  aptly -config aptly.conf snapshot drop "$SNAPSHOT_NAME"
fi
set -e

aptly "${APTLY_OPTS}" snapshot create "$SNAPSHOT_NAME" from repo "$REPO"
if [ "$SIGN" == "yes" ]; then
  if [ -n "$SIGN_KEY" ]; then
    APTLY_SIGN_OPTS="-gpg-key $SIGN_KEY"
  fi
else
  APTLY_SIGN_OPTS="--skip-signing=true"
fi
aptly "${APTLY_OPTS}" publish snapshot $APTLY_SIGN_OPTS ${APTLY_REPO_OPTS} "$SNAPSHOT_NAME" "s3:${PACKAGES_BUCKET}:"
