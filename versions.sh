CONFLUENT_VERSION=0.1-SNAPSHOT
KAFKA_VERSION=0.8.2.1
KAFKA_BRANCH=0.8.2
KAFKA_REPO="http://git-wip-us.apache.org/repos/asf/kafka.git"
SCALA_VERSIONS="2.10.4"

KAFKA_PACKAGING_REPO="git@github.com:heroku/kafka-packaging.git"
COMMON_REPO="git@github.com:confluentinc/common.git"
REST_UTILS_REPO="git@github.com:confluentinc/rest-utils.git"
SCHEMA_REGISTRY_REPO="git@github.com:confluentinc/schema-registry.git"
KAFKA_REST_REPO="git@github.com:confluentinc/kafka-rest.git"
CAMUS_REPO="git@github.com:confluentinc/camus.git"

BRANCH="origin/master"
# Branch overrides for specific projects. Use
# project_name_using_underscores_BRANCH.
camus_BRANCH="origin/confluent-master"
SIGN="yes"
SIGN_KEY="Maciek Sakrejda (Heroku) <maciek@heroku.com>"
REVISION="1heroku1"
REGION="us-west-2" # S3 region, this is the default for Confluent's account
