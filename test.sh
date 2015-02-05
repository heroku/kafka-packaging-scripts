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
# even care if they manage to start up completely so we can sometimes avoid
# running dependency services as long as the process can run for awhile without
# it. However, some, like ZK and Kafka, are useful to keep running since they
# make tests simpler. These are split into start/stop phases so other tests can
# be executed while they are running.
#
# Note that you have to be careful of memory constraints since the VMs have
# limited RAM.

test_zk_start() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/zookeeper-server-start /etc/kafka/zookeeper.properties &> /tmp/zk.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep QuorumPeerMain | grep -v grep"
}

test_zk_stop() {
    machine=$1
    # zookeeper-server-stop finds more than one process because it only
    # searches for 'zookeeper', so we do this manually in a way that filters
    # more accurately to the right process.
    vagrant ssh $machine -- "ps ax | grep java | grep -i QuorumPeerMain | grep -v grep | awk '{print \$1}' | sudo xargs kill -SIGINT"
}

test_kafka_start() {
    machine=$1
    # This will only stay up for about 6 seconds, we need to figure out how to make this more reliable
    vagrant ssh $machine -- "sudo /usr/bin/kafka-server-start /etc/kafka/server.properties &> /tmp/kafka.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep 'kafka\.Kafka' | grep -v grep"
}

test_kafka_stop() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/kafka-server-stop"
}

test_schema_registry() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/schema-registry-start /etc/schema-registry/schema-registry.properties &> /tmp/schema-registry.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep 'schemaregistry\.rest\.Main' | grep -v grep"
    vagrant ssh $machine -- "sudo /usr/bin/schema-registry-stop"
}

test_rest() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/kafka-rest-start &> /tmp/rest.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep 'kafkarest\.Main' | grep -v grep"
    vagrant ssh $machine -- "sudo /usr/bin/kafka-rest-stop"
}

test_camus() {
    # There's no good way to test the Camus jar since it doesn't contain unit
    # tests and everything it has requires Hadoop to be running. In this case
    # we're ok with ignoring it -- it's unusual in that the package is just a
    # standalone uberjar anyway so anything that tests the build output
    # (e.g. ducttape) should be sufficient.
    echo "Skipping Camus test since Camus has nothing it can run standalone."
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
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-schema-registry-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-kafka-rest-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-camus-*.rpm

    test_zk_start rpm
    test_kafka_start rpm
    test_schema_registry rpm
    test_rest rpm
    test_camus rpm
    test_kafka_stop rpm
    test_zk_stop rpm

    vagrant ssh rpm -- sudo rpm --erase confluent-camus
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-rest
    vagrant ssh rpm -- sudo rpm --erase confluent-schema-registry
    vagrant ssh rpm -- sudo rpm --erase confluent-rest-utils
    vagrant ssh rpm -- sudo rpm --erase confluent-common
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-${SCALA_VERSION}


    #######
    # DEB #
    #######
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-kafka-${SCALA_VERSION}*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-common*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-rest-utils*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-schema-registry*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-kafka-rest*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-camus*_all.deb

    test_zk_start deb
    test_kafka_start deb
    test_schema_registry deb
    test_rest deb
    test_camus deb
    test_kafka_stop deb
    test_zk_stop deb

    vagrant ssh deb -- sudo dpkg --remove confluent-camus
    vagrant ssh deb -- sudo dpkg --remove confluent-kafka-rest
    vagrant ssh deb -- sudo dpkg --remove confluent-schema-registry
    vagrant ssh deb -- sudo dpkg --remove confluent-rest-utils
    vagrant ssh deb -- sudo dpkg --remove confluent-common
    vagrant ssh deb -- sudo dpkg --remove confluent-kafka-${SCALA_VERSION}
done
