#!/bin/bash

. versioning_helpers.sh

###
### Kafka: versioning and packaging configuration
###

# Kafka has its own version and branch settings as it has a special requirements
# in our build setup.  For example, we need to support multiple Scala versions.
KAFKA_VERSION="0.8.2.1" # Will eventually be 0.8.2.2
KAFKA_BRANCH="0.8.2"
SCALA_VERSIONS="2.9.1 2.9.2 2.10.4 2.11.5"


###
### Confluent packages: versioning and packaging configuration
###

# Version of the CP release and also the version of the various CP projects.
# Examples: `1.0`, `1.0.1-SNAPSHOT`
#
# *** IMPORTANT ***:
# - This setting must work with the must work with BRANCH settings below.
#   For example, do not set CONFLUENT_VERSION="1.2.3" when BRANCH="origin/4.x".
# - This setting must be aligned with the PACKAGES_BUCKET* and MAVEN_BUCKET
#   settings below.  The S3 buckets we use follow a naming convention that
#   must match CONFLUENT_VERSION.
#
CONFLUENT_VERSION="1.0.1-SNAPSHOT"

# Used for "Revision" field of deb packages and "Release" field of rpm packages.
#
# REVISION should be reset to `1` whenever we bump CONFLUENT_VERSION.
REVISION="1"

# Space-separated list of all the packages except for Kafka, without the
# `confluent-` prefix.  These all need to have the same version number
# currently (cf. CONFLUENT_VERSION).
#
# The packages must be listed in the order of their dependencies.  For example,
# rest-utils must be listed before kafka-rest as the latter depends on the former.
CP_PACKAGES="common rest-utils schema-registry kafka-rest camus"

# `BRANCH` is the global setting for build branches of Confluent packages incl. Camus.
#
# Be aware that projects may have different naming conventions for branches.
# If needed, make use of project-specific overrides as described below.
#
# Note: Kafka has its own configuration setting `KAFKA_BRANCH`.
#
# Examples
# --------
# BRANCH="origin/master" # for snapshots
# BRANCH="origin/1.x" # for development/maintenance branches
#
BRANCH="origin/1.x"

# You may add branch overrides for specific projects, if needed.
# Use project_name_using_underscores_BRANCH.
#
# Override examples:
# ------------------
# camus_BRANCH="origin/confluent-master" # branch
# kafka_rest_BRANCH="v1.0" # tag


###
### Git repositories
###
KAFKA_REPO="http://git-wip-us.apache.org/repos/asf/kafka.git"
CAMUS_REPO="git@github.com:confluentinc/camus.git"
COMMON_REPO="git@github.com:confluentinc/common.git"
KAFKA_PACKAGING_REPO="git@github.com:confluentinc/kafka-packaging.git"
KAFKA_REST_REPO="git@github.com:confluentinc/kafka-rest.git"
REST_UTILS_REPO="git@github.com:confluentinc/rest-utils.git"
SCHEMA_REGISTRY_REPO="git@github.com:confluentinc/schema-registry.git"


###
### Package signing
###
SIGN="yes"
SIGN_KEY=""


###
### AWS/S3 configuration
###
REGION="us-west-2" # S3 region, this is the default for Confluent's account

# Staging S3 bucket to which we deploy the new packages (deb, rpm, tar.gz, zip).
#
# Bucket names must follow the convention `staging-confluent-packages-X.Y.Z`,
# where:
# - X = Major CP release number (cf. CONFLUENT_VERSION)
# - Y = Minor CP release number (cf. CONFLUENT_VERSION)
# - Z = Patch CP release number (cf. CONFLUENT_VERSION)
#
# Example: staging-confluent-packages-1.0.0
PACKAGES_BUCKET="staging-confluent-packages-1.0.1"

# S3 bucket that contains all packages for the previous release.
# (previous release: if you want to deploy 1.0.3, then the previous release
# version is 1.0.2).  This bucket is only read from but never written to.
#
# When deploying an initial x.y.0 release (e.g. 1.0.0, 1.3.0, 2.0.0),
# you must set PACKAGES_BUCKET_OF_PREVIOUS_RELEASE="".
#
# This bucket follows the same naming convention as PACKAGES_BUCKET.
#
# Examples:
# confluent-packages-1.0.0          (production S3 bucket)
# staging-confluent-packages-1.0.0  (if it still exists)
PACKAGES_BUCKET_OF_PREVIOUS_RELEASE="confluent-packages-1.0.0"

# Staging S3 bucket to which we deploy the new maven artifacts (jars).
#
# Bucket names must follow the convention `staging-confluent-packages-maven-X.Y.Z`,
# where:
# - X = Major CP release number (cf. CONFLUENT_VERSION)
# - Y = Minor CP release number (cf. CONFLUENT_VERSION)
# - Z = Patch CP release number (cf. CONFLUENT_VERSION)
#
# Example: staging-confluent-packages-maven-1.0.0
MAVEN_BUCKET="staging-confluent-packages-maven-1.0.1"

# Production S3 bucket that contains our production Maven repository.
# This bucket is only read from but never written to.
#
# NOTE: You should never need to modify this setting!
MAVEN_BUCKET_PRODUCTION="confluent-packages-maven"

# Top-level bucket sub-directory (cf. PACKAGES_BUCKET) for archive packages
PACKAGES_BUCKET_ARCHIVE_BASE="archive"
# Top-level bucket sub-directory (cf. PACKAGES_BUCKET) for deb packages
PACKAGES_BUCKET_DEB_BASE="deb"
# Top-level bucket sub-directory (cf. PACKAGES_BUCKET) for rpm packages
PACKAGES_BUCKET_RPM_BASE="rpm"

BUCKET_POLICY_FILE_TEMPLATE="bucket-policy-public-read.json.template"
BUCKET_POLICY_FILE="bucket-policy-public-read.json"


###
### Enabling/disabling tests
###
#
# Set SKIP_TESTS to "yes" to disable tests, to "no" to enable tests.
SKIP_TESTS="no"

# You may add overrides for specific projects, if needed.
# Use project_name_using_underscores_SKIP_TESTS.
#
# Override examples:
# ------------------
# kafka_rest_SKIP_TESTS="yes"
#
camus_SKIP_TESTS="yes" # We do not run tests for Camus.


###
### Package verification rules
###
PACKAGE_MIN_FILE_SIZE_BYTES=10000

###
### Misc settings
###
OUTPUT_DIRECTORY="output" # local directory; stores generated packages
DEPLOYED_DIRECTORY="_deployed" # local directory; contains directory tree for S3 deployment uploads
TEMP_DIRECTORY="_temp" # local directory; used for extracting deb/rpm packages of a previous release from an S3 bucket


###
### Input validation of settings defined above
###

# Ensure that buckets are configured.
if [ -z "$PACKAGES_BUCKET" ]; then
  echo "ERROR: PACKAGES_BUCKET must be set"
  exit 1
fi
if [ -z "$MAVEN_BUCKET" ]; then
  echo "ERROR: MAVEN_BUCKET must be set"
  exit 1
fi
if [ -z "$MAVEN_BUCKET_PRODUCTION" ]; then
  echo "ERROR: MAVEN_BUCKET_PRODUCTION must be set"
  exit 1
fi

# Ensure that we deploy packages only to staging S3 buckets
if [[ "$PACKAGES_BUCKET" != staging-confluent-packages-* ]]; then
  echo "ERROR: PACKAGES_BUCKET must start with 'staging-confluent-packages-'"
  exit 1
fi

# Ensure that we deploy maven artifacts only to staging S3 buckets
if [[ "$MAVEN_BUCKET" != staging-confluent-packages-maven-* ]]; then
  echo "ERROR: MAVEN_BUCKET must start with 'staging-confluent-packages-maven-'"
  exit 1
fi

# Ensure that the version identifier in the S3 buckets match CONFLUENT_VERSION.
if [ `rpm_version $CONFLUENT_VERSION` != `cp_release_from_versioned_s3_bucket $PACKAGES_BUCKET` ]; then
  echo "ERROR: Version identifier in PACKAGES_BUCKET ($PACKAGES_BUCKET) is not compatible with" \
    "CONFLUENT_VERSION ($CONFLUENT_VERSION)"
  exit 1
fi
if [ `rpm_version $CONFLUENT_VERSION` != `cp_release_from_versioned_s3_bucket $MAVEN_BUCKET` ]; then
  echo "ERROR: Version identifier in MAVEN_BUCKET ($MAVEN_BUCKET) is not compatible with" \
    "CONFLUENT_VERSION ($CONFLUENT_VERSION)"
  exit 1
fi
