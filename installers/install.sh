#!/bin/bash

set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

KAFKA_FILE=`ls ${DIR}/confluent-kafka-* | grep -E 'confluent-kafka-[0-9].*'`
PACKAGES="common rest-utils schema-registry kafka-rest camus kafka-connect-hdfs kafka-connect-jdbc librdkafka"
DEB=`ls ${DIR}/*.deb || true`

if [ -n "$DEB" ]; then
    KAFKA_PACKAGE=`echo $KAFKA_FILE | xargs basename | awk -F _ '{ print $1}'`
    EXT=".deb"
    COMMAND="sudo dpkg --install"
    COMMAND_EXT="_*${EXT}"
    if [ "$1" == "--uninstall" ]; then
        COMMAND="sudo dpkg --remove"
    fi
else
    KAFKA_PACKAGE=`echo $KAFKA_FILE | xargs basename | awk -F - '{ printf "%s-%s-%s",$1,$2,$3}'`
    EXT=".rpm"
    COMMAND="sudo rpm --install"
    COMMAND_EXT="*${EXT}"
    if [ "$1" == "--uninstall" ]; then
        COMMAND="sudo rpm --erase"
    fi
fi

MESSAGE="Installing"
PATH_PREFIX="${DIR}/"
if [ "$1" == "--uninstall" ]; then
    MESSAGE="Removing"
    PATH_PREFIX=""
    COMMAND_EXT=""
    PACKAGES=`echo $PACKAGES | awk '{for (i=NF; i>0; i--) printf("%s ",$i);print ""}'`
fi

echo "$MESSAGE Confluent Platform"

echo "$MESSAGE kafka"
eval "${COMMAND} ${PATH_PREFIX}${KAFKA_PACKAGE}${COMMAND_EXT}"
for PACKAGE in $PACKAGES; do
    echo "$MESSAGE $PACKAGE"
    # TODO: librdkafka (and possibly further C-based packages) requires special treatment.
    if [ "$PACKAGE" = "librdkafka" ]; then
      eval "${COMMAND} ${PATH_PREFIX}librdkafka1${COMMAND_EXT}"
    else
      eval "${COMMAND} ${PATH_PREFIX}confluent-${PACKAGE}${COMMAND_EXT}"
    fi
done
