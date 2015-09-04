#!/bin/bash
#
# This script creates the two staging S3 buckets for (1) packages (deb, rpm, tar.gz, zip) and (2) maven artifacts.
# We also copy archive packages (tar.gz, zip) from a previous release if we're preparing the staging buckets for
# a patch release (such as CP 1.0.1).

set -e
set -x

. settings.sh
. aws.sh
. versioning_helpers.sh

declare -r CURRENT_RELEASE_BUCKET="$PACKAGES_BUCKET_OF_PREVIOUS_RELEASE"
declare -r CURRENT_RELEASE_BUCKET_URL="s3://${CURRENT_RELEASE_BUCKET}"
declare -r NEW_RELEASE_BUCKET="$PACKAGES_BUCKET"
declare -r NEW_RELEASE_BUCKET_URL="s3://${NEW_RELEASE_BUCKET}"
declare -r CURRENT_RELEASE_VERSION=`cp_release_from_versioned_s3_bucket $CURRENT_RELEASE_BUCKET`
declare -r CURRENT_MAJOR_MINOR_RELEASE=`rpm_version_major_minor $CURRENT_RELEASE_VERSION`
declare -r NEW_RELEASE_VERSION=`cp_release_from_versioned_s3_bucket $NEW_RELEASE_BUCKET`
declare -r NEW_MAJOR_MINOR_RELEASE=`rpm_version_major_minor $NEW_RELEASE_VERSION`
declare -r REPO_RELEASE_SUBDIR=`repo_release_subdir_from_versioned_s3_bucket $CURRENT_RELEASE_BUCKET`
declare -r ARCHIVE_BASE="$PACKAGES_BUCKET_ARCHIVE_BASE"
declare -r DEB_BASE="$PACKAGES_BUCKET_DEB_BASE"
declare -r RPM_BASE="$PACKAGES_BUCKET_RPM_BASE"
declare -r MAVEN_BUCKET_URL="s3://${MAVEN_BUCKET}"

# TODO: We can derive the same information by inspecting the version suffix in PACKAGES_BUCKET (or CONFLUENT_VERSION).
is_initial_release() {
  if [ -z "$CURRENT_RELEASE_BUCKET" ]; then
    return 0 # initial release (x.y.0)
  else
    return 1 # patch release (x.z.1 onwards)
  fi
}

# Prevent users from creating inconsistent S3 data in case they base the new release on the wrong current release.
# We skip this check for initial x.y.0 releases (e.g. 1.0.0, 1.3.0, 2.0.0), in which case CURRENT_RELEASE_BUCKET
# is not set/is empty.
#
# Our policy is that a new release may only be based on a release if they are from the same x.y.* release line.
#
#       Valid transitions: 1.0.1 -> 1.0.2, 2.3.4 -> 2.3.5, 1.0.0 -> 1.0.7
#       Invalid transitions: 1.*.* -> 2.*.*, 1.0.* -> 1.1.*, etc.
#
# TODO: Prevent the user from skipping intermediate patch releases (e.g. 1.0.0 -> 1.0.7)?
#
if is_initial_release; then
  echo "Verifying correct lineage of S3 buckets..."
  if [ `version_compare $CURRENT_MAJOR_MINOR_RELEASE $NEW_MAJOR_MINOR_RELEASE` != "0" ]; then
    echo "ERROR: You may only prepare a new S3 bucket for the same CP x.y.* release line "\
     " (current is $CURRENT_MAJOR_MINOR_RELEASE, you wanted $NEW_MAJOR_MINOR_RELEASE)."
    exit 30
  elif [ `version_compare $CURRENT_RELEASE_VERSION $NEW_RELEASE_VERSION` != "1" ]; then
    echo "ERROR: You may only prepare a new S3 bucket for newer CP releases "\
      "(current is $CURRENT_RELEASE_VERSION, you wanted $NEW_RELEASE_VERSION)"
    exit 31
  fi
else
  echo "Initial release, skipping verification of lineage of S3 buckets..."
fi

###
### Staging bucket for packages
###

# Create, if needed, the staging bucket for packages (deb, rpm, tar.gz, zip) of the new release
set +e
aws s3 ls ${NEW_RELEASE_BUCKET_URL} &> /dev/null
if [ $? -ne 0 ]; then
  set -e
  echo "Creating staging S3 bucket '$NEW_RELEASE_BUCKET' for packages of CP release $CONFLUENT_VERSION..."
  aws s3 mb ${NEW_RELEASE_BUCKET_URL}
  sed -e "s%BUCKET%${NEW_RELEASE_BUCKET}%" $BUCKET_POLICY_FILE_TEMPLATE > $BUCKET_POLICY_FILE
  aws s3api put-bucket-policy --bucket $NEW_RELEASE_BUCKET --policy file://${BUCKET_POLICY_FILE}
fi
set -e

# If we're deploying a patch release, we also copy any existing archive packages (tar.gz, zip) from the previous
# release.  This is an optimization step as copying from AWS to AWS is the fastest network transfer option at our
# disposal (so we avoid downloading the archives locally and the re-uploading them again to AWS).
if ! is_initial_release; then
  # We can copy the current /archive/x.y/ tree as-is because it does not contain any files such as index files, which
  # would need to be regenerated/updated to also include the files of the new release.
  echo "Copying archive packages from CP release $CURRENT_RELEASE_VERSION into new staging bucket for packages..."
  aws s3 sync "${CURRENT_RELEASE_BUCKET_URL}/${ARCHIVE_BASE}/${REPO_RELEASE_SUBDIR}" \
                  "${NEW_RELEASE_BUCKET_URL}/${ARCHIVE_BASE}/${REPO_RELEASE_SUBDIR}"
fi

###
### Staging bucket for maven artifacts
###

# Create, if needed, the staging bucket for maven artifacts (jars) of the new release
set +e
aws s3 ls ${MAVEN_BUCKET_URL} &> /dev/null
if [ $? -ne 0 ]; then
  set -e
  echo "Creating staging S3 bucket '$MAVEN_BUCKET' for maven artifacts of CP release $CONFLUENT_VERSION..."
  aws s3 mb ${MAVEN_BUCKET_URL}
  sed -e "s%BUCKET%${MAVEN_BUCKET}%" $BUCKET_POLICY_FILE_TEMPLATE > $BUCKET_POLICY_FILE
  aws s3api put-bucket-policy --bucket $MAVEN_BUCKET --policy file://${BUCKET_POLICY_FILE}
fi
set -e
