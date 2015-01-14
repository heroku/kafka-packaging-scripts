#!/bin/bash

set -e
set -x

. versions.sh

on_exit() {
    LAST_RESULT=$?
    if [[ $LAST_RESULT != 0 ]]; then
        echo "******************************************************"
        echo "* TESTING FAILED"
        echo "******************************************************"
        echo
        echo "Something went wrong with the tests. The VM may be in"
        echo "an bad state with running processes and packages"
        echo "still installed. You'll need to clean up manually."
    fi
}
trap on_exit 0

# These tests are intentionally minimal. We're not looking to test any
# functionality, just that the services we installed will actually run. We don't
# even care if they manage to start up completely so, for example, testing Kafka
# doesn't require ZooKeeper to be up since the process will still start and can
# then be shut down cleanly.

test_zk() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/zookeeper-server-start.sh /etc/kafka/zookeeper.properties.example &> /tmp/zk.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep QuorumPeerMain | grep -v grep"
    # zookeeper-server-stop.sh finds more than one process because it only
    # searches for 'zookeeper', so we do this manually in a way that filters
    # more accurately to the right process.
    vagrant ssh $machine -- "ps ax | grep java | grep -i QuorumPeerMain | grep -v grep | awk '{print \$1}' | sudo xargs kill -SIGINT"
}

test_kafka() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/kafka-server-start.sh /etc/kafka/server.properties.example &> /tmp/kafka.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep 'kafka\.Kafka' | grep -v grep"
    vagrant ssh $machine -- "sudo /usr/bin/kafka-server-stop.sh"
}

test_rest() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/kafka-rest-start &> /tmp/rest.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep 'kafkarest\.Main' | grep -v grep"
    vagrant ssh $machine -- "sudo /usr/bin/kafka-rest-stop"
}

# Note that this should really only be run with *a single version of packages in
# output/*. This is because it's a pain to generate the actual package names
# from the versions because of platform-specific version contortions. Instead,
# we use globs to pick out what *should* be unique files as long as we only have
# one version in output/.
for SCALA_VERSION in $SCALA_VERSIONS; do
    #######
    # RPM #
    #######
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-kafka-${SCALA_VERSION}-*.noarch.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-common-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-rest-utils-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-kafka-rest-*.rpm

    test_zk rpm
    test_kafka rpm
    test_rest rpm

    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-rest
    vagrant ssh rpm -- sudo rpm --erase confluent-rest-utils
    vagrant ssh rpm -- sudo rpm --erase confluent-common
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-${SCALA_VERSION}


    #######
    # DEB #
    #######
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-kafka-${SCALA_VERSION}*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-common*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-rest-utils*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-kafka-rest*_all.deb

    test_zk deb
    test_kafka deb
    test_rest deb

    vagrant ssh deb -- sudo dpkg --remove confluent-kafka-rest
    vagrant ssh deb -- sudo dpkg --remove confluent-rest-utils
    vagrant ssh deb -- sudo dpkg --remove confluent-common
    vagrant ssh deb -- sudo dpkg --remove confluent-kafka-${SCALA_VERSION}
done
