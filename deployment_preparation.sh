#!/bin/bash
#
# This scripts does three things:
#   A. (AWS) create staging S3 buckets for 1. packages and 2. maven artifacts.
#   B. (AWS) create a backup of our production S3 bucket for maven artifacts.
#   C. (local) download any historical deb/rpm packages from S3 and integrate them locally alongside the newly
#      generated packages under OUTPUT_DIRECTORY.
#
# A) This script creates the two staging S3 buckets for (1) packages (deb, rpm, tar.gz, zip) and (2) maven artifacts.
#    As an optimization to reduce deployment time, we also AWS-to-AWS copy archive packages (tar.gz, zip) from a
#    previous release into the staging bucket for packages if we're preparing the buckets for a patch release (such as
#    CP 1.0.1).
#
# B) This scripts creates a backup S3 bucket of our production S3 bucket for maven artifacts.  This is a safety measure
#    that allows us to perform rollbacks.
#
# C) Lastly, this script retrieves "historical" deb and rpm packages (= from a previous release) from S3 and stores them
#    in the local OUTPUT_DIRECTORY.
#
# Step C is required so that our packaging scripts can regenerate the various deb/rpm index files.
# At a higher level, this step is required because of our decision to provide `x.y` (major.minor version) indexed
# yum and apt repositories, where a given `x.y` repository (e.g., `1.2` for the CP 1.2.* release line) will contain
# all available `x.y.*` packages at this point.  For example, when CP 1.2.3 is released, the `1.2` repositories
# will contain the deb and rpm packages for 1.2.0, 1.2.1, 1.2.2, and 1.2.3.

set -e
set -x

MYSELF=`basename $0`
MY_DIR=`echo $(cd $(dirname $0); pwd)`

. $MY_DIR/settings.sh
. $MY_DIR/aws.sh
. $MY_DIR/versioning_helpers.sh

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
declare -r MAVEN_BUCKET_PRODUCTION_URL="s3://${MAVEN_BUCKET_PRODUCTION}"
declare -r BACKUP_TIMESTAMP=`date +"%Y%m%d-%H%M%S"`
if [ -z "$BACKUP_TIMESTAMP" ]; then
  echo "ERROR: Could not create a valid backup timestamp."
  exit 1
fi
declare -r MAVEN_BUCKET_PRODUCTION_BACKUP="${MAVEN_BUCKET_PRODUCTION}-${BACKUP_TIMESTAMP}"
declare -r MAVEN_BUCKET_PRODUCTION_BACKUP_URL="s3://${MAVEN_BUCKET_PRODUCTION_BACKUP}"

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

  # Download historical deb and rpm packages from S3 and integrate them with the local OUTPUT_DIRECTORY.
  mkdir -p $MY_DIR/$TEMP_DIRECTORY
  pushd $MY_DIR/$TEMP_DIRECTORY
  mkdir -p "deb" "rpm"
  aws s3 sync "${CURRENT_RELEASE_BUCKET_URL}/${DEB_BASE}/${CURRENT_MAJOR_MINOR_RELEASE}" deb
  find deb -type f -name "*_all.deb" -exec mv {} "$MY_DIR/$OUTPUT_DIRECTORY" \;
  aws s3 sync "${CURRENT_RELEASE_BUCKET_URL}/${RPM_BASE}/${CURRENT_MAJOR_MINOR_RELEASE}" rpm
  find rpm -maxdepth 1 -type f -name "*.rpm" -exec mv {} "$MY_DIR/$OUTPUT_DIRECTORY" \;
  rm -rf deb rpm
  popd
fi

###
### Staging bucket for maven artifacts
###

# Create a backup of our production bucket for maven artifacts.
set +e
aws s3 ls ${MAVEN_BUCKET_PRODUCTION_BACKUP_URL} &> /dev/null
if [ $? -ne 0 ]; then
  set -e
  echo "Creating backup S3 bucket '$MAVEN_BUCKET_PRODUCTION_BACKUP' of production S3 bucket "\
   "'$MAVEN_BUCKET_PRODUCTION' for maven artifacts..."
  aws s3 mb ${MAVEN_BUCKET_PRODUCTION_BACKUP_URL}
  sed -e "s%BUCKET%${MAVEN_BUCKET_PRODUCTION_BACKUP}%" $BUCKET_POLICY_FILE_TEMPLATE > $BUCKET_POLICY_FILE
  aws s3api put-bucket-policy --bucket $MAVEN_BUCKET_PRODUCTION_BACKUP --policy file://${BUCKET_POLICY_FILE}
  aws s3 sync "${MAVEN_BUCKET_PRODUCTION_URL}" "${MAVEN_BUCKET_PRODUCTION_BACKUP_URL}"
fi
set -e

# Create the staging bucket for maven artifacts (jars) of the new release
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
