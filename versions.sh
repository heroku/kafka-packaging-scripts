###
### Versioning and packaging configuration
### (see also configuration of branches below)
###
CONFLUENT_VERSION="1.0.1-SNAPSHOT" # Examples: `1.0`, `1.0.1-SNAPSHOT`
KAFKA_VERSION="0.8.2.1" # Will eventually be 0.8.2.2
SCALA_VERSIONS="2.9.1 2.9.2 2.10.4 2.11.5"
REVISION="1"
SIGN="yes"
SIGN_KEY=""


###
### AWS/S3 configuration
###
REGION="us-west-2" # S3 region, this is the default for Confluent's account


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
### Branch from which the packages will be built
###

# Kafka has its own branch variable as it has a special role in our build setup.
KAFKA_BRANCH="0.8.2"

# Confluent packages
#
# `BRANCH` is the global setting for build branches of Confluent packages.
#
# Note that projects may have different naming conventions for branches.
# If needed, make use of project-specific overrides as described below.
#
# Examples
# --------
# BRANCH="origin/master" # for snapshots
#
BRANCH="origin/master"
# Branch overrides for specific projects.  Use project_name_using_underscores_BRANCH.
#
# Override examples:
# ------------------
# camus_BRANCH="origin/confluent-master" # branch
# kafka_rest_BRANCH="v1.0" # tag
#
camus_BRANCH="origin/1.x"
common_BRANCH="origin/1.x"
kafka_rest_BRANCH="origin/1.x"
rest_utils_BRANCH="origin/1.x"
schema_registry_BRANCH="origin/1.x"


###
### Enabling/disabling tests
###
#
# Set SKIP_TESTS to "yes" to disable tests, to "no" to enable tests.
SKIP_TESTS="no"
# Overrides for specific projects.  Use project_name_using_underscores_SKIP_TESTS.
#
# Override examples:
# ------------------
# kafka_rest_SKIP_TESTS="yes"
#
camus_SKIP_TESTS="yes" # We do not run tests for Camus.
