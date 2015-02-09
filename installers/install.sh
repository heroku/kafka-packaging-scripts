#!/bin/bash

set -x
set -e

KAFKA_FILE=`ls confluent-kafka-*${EXT} | grep -P 'confluent-kafka-\d.*'`
PACKAGES="common rest-utils schema-registry kafka-rest camus"
DEB=`ls *.deb || true`
if [ -n "$DEB" ]; then
    KAFKA_PACKAGE=`echo $KAFKA_FILE | awk -F _ '{ print $1}'`
    EXT=".deb"
    COMMAND="sudo dpkg --install"
    COMMAND_EXT="_*${EXT}"
    if [ "$1" == "--uninstall" ]; then
        COMMAND="sudo dpkg --remove"
    fi
else
    KAFKA_PACKAGE=`echo $KAFKA_FILE | awk -F - '{ printf "%s-%s-%s",$1,$2,$3}'`
    EXT=".rpm"
    COMMAND="sudo rpm --install"
    COMMAND_EXT="*${EXT}"
    if [ "$1" == "--uninstall" ]; then
        COMMAND="sudo rpm --erase"
    fi
fi

if [ "$1" == "--uninstall" ]; then
    COMMAND_EXT=""
    PACKAGES=`echo $PACKAGES | awk '{for (i=NF; i>0; i--) printf("%s ",$i);print ""}'`
fi

eval "${COMMAND} ${KAFKA_PACKAGE}${COMMAND_EXT}"
for PACKAGE in $PACKAGES; do
    eval "${COMMAND} confluent-${PACKAGE}${COMMAND_EXT}"
done
