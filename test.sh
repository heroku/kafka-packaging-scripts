#!/bin/bash

set -e
set -x

. settings.sh

KAFKA_DATA_DIR=/var/lib/kafka
ZOOKEEPER_DATA_DIR=/var/lib/zookeeper

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
    # `zookeeper-server-stop` finds more than one process because it only
    # searches for 'zookeeper', so to prevent collateral damage we do this
    # manually in a way that filters more accurately to the right process.
    #
    # Also, there is apparently a problem when using `vagrant ssh` to launch
    # a background process like we do in `test_zk_start` (FWIW we also tried
    # command variants with e.g. nohup, I/O redirection, to fix the root cause
    # but without success):  If you do, then sending a SIGINT is not enough to
    # terminate the ZK process.
    # SIGINT /is/ enough if you manually start ZK (with the same
    # `sudo /usr/bin/zookeeper-server-start ...` command line) and then `kill -SIGINT`
    # the ZK pid via `vagrant ssh`.  However, it does not work if the ZK process was
    # started in the background from the host machine via `vagrant ssh`.
    # This could be caused by interaction between vagrant, ssh, (no) terminal,
    # or something else.
    # For the time being we simply use the workaround to terminate the ZK process
    # via SIGTERM.  This also means that we cannot use `zookeeper-server-stop`
    # in this setup because that script kills via SIGINT.
    #
    # TODO: Figure out why SIGINT is not enough to kill the ZK process when we have started ZK via `vagrant ssh`.
    vagrant ssh $machine -- "ps ax | grep java | grep -i QuorumPeerMain | grep -v grep | awk '{print \$1}' | sudo xargs kill -SIGTERM"
}

test_kafka_start() {
    machine=$1
    # This will only stay up for about 6 seconds, we need to figure out how to make this more reliable
    vagrant ssh $machine -- "sudo /usr/bin/kafka-server-start /etc/kafka/server.properties &> /tmp/kafka.log &"
    sleep 5
    if [ "$PS_ENABLED" = "yes" ]; then
        vagrant ssh $machine -- "ps ax | grep -i 'io\.confluent\.support\.metrics\.SupportedKafka' | grep java | grep -v grep"
    else
        vagrant ssh $machine -- "ps ax | grep 'kafka\.Kafka' | grep java | grep -v grep"
    fi
}

test_kafka_stop() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/kafka-server-stop"
    # Prevent a race condition where the broker may not be fully shutdown yet
    # but the ZK process already is.  If that should happen, then the broker
    # will be stuck in a ZK reconnection loop and can only be terminated by a
    # SIGKILL.
    sleep 25
}

# This test assumes the broker has already started
test_ps() {
    machine=$1
    # Metrics will be collected at shutdown
    test_kafka_stop $machine
    # Restart broker so CLI script can collect metrics
    test_kafka_start $machine
    # Collect metrics
    vagrant ssh $machine -- "sudo /usr/bin/support-metrics-bundle --zookeeper localhost:2181 &"
    # Check metrics are there
    vagrant ssh $machine -- "sudo ls -l /usr/bin/support-metrics-*.zip "
    
}

test_schema_registry() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/schema-registry-start /etc/schema-registry/schema-registry.properties &> /tmp/schema-registry.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep 'schemaregistry\.rest\.SchemaRegistryMain' | grep -v grep"
    vagrant ssh $machine -- "sudo /usr/bin/schema-registry-stop"
}

test_rest() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/kafka-rest-start &> /tmp/rest.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep 'kafkarest\.KafkaRestMain' | grep -v grep"
    vagrant ssh $machine -- "sudo /usr/bin/kafka-rest-stop"
}

test_kafka_connect_hdfs() {
    machine=$1
    # TODO
}

test_kafka_connect_jdbc() {
    machine=$1
    # TODO
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

    # pre-test sanitization
    vagrant ssh rpm -- sudo rpm --erase confluent-camus || true
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-connect-jdbc || true
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-connect-hdfs || true
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-rest || true
    vagrant ssh rpm -- sudo rpm --erase confluent-schema-registry || true
    vagrant ssh rpm -- sudo rpm --erase confluent-rest-utils || true
    vagrant ssh rpm -- sudo rpm --erase confluent-common || true
    for LOCAL_SCALA_VERSION in $SCALA_VERSIONS; do
        vagrant ssh rpm -- sudo rpm --erase confluent-kafka-${LOCAL_SCALA_VERSION} || true
    done
    vagrant ssh rpm -- sudo rm -rf $KAFKA_DATA_DIR
    vagrant ssh rpm -- sudo rm -rf $ZOOKEEPER_DATA_DIR

    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-kafka-${SCALA_VERSION}-*.noarch.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-common-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-rest-utils-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-schema-registry-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-kafka-rest-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-kafka-connect-hdfs-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-kafka-connect-jdbc-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-camus-*.rpm

    test_zk_start rpm
    test_kafka_start rpm
    test_schema_registry rpm
    test_rest rpm
    test_kafka_connect_hdfs rpm
    test_kafka_connect_jdbc rpm
    test_camus rpm
    if [ "$PS_ENABLED" = "yes" ]; then
        test_ps rpm
    fi
    test_kafka_stop rpm
    test_zk_stop rpm

    # post-test sanitization
    vagrant ssh rpm -- sudo rpm --erase confluent-camus
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-connect-jdbc
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-connect-hdfs
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-rest
    vagrant ssh rpm -- sudo rpm --erase confluent-schema-registry
    vagrant ssh rpm -- sudo rpm --erase confluent-rest-utils
    vagrant ssh rpm -- sudo rpm --erase confluent-common
    vagrant ssh rpm -- sudo rpm --erase confluent-kafka-${SCALA_VERSION}

    #######
    # DEB #
    #######

    # pre-test sanitization
    vagrant ssh deb -- sudo dpkg --purge confluent-camus || true
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-connect-jdbc || true
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-connect-hdfs || true
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-rest || true
    vagrant ssh deb -- sudo dpkg --purge confluent-schema-registry || true
    vagrant ssh deb -- sudo dpkg --purge confluent-rest-utils || true
    vagrant ssh deb -- sudo dpkg --purge confluent-common || true
    for LOCAL_SCALA_VERSION in $SCALA_VERSIONS; do
        vagrant ssh deb -- sudo dpkg --remove confluent-kafka-${LOCAL_SCALA_VERSION} || true
    done
    vagrant ssh deb -- sudo rm -rf $KAFKA_DATA_DIR
    vagrant ssh deb -- sudo rm -rf $ZOOKEEPER_DATA_DIR

    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-kafka-${SCALA_VERSION}*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-common*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-rest-utils*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-schema-registry*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-kafka-rest*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-kafka-connect-hdfs*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-kafka-connect-jdbc*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-camus*_all.deb

    test_zk_start deb
    test_kafka_start deb
    test_schema_registry deb
    test_rest deb
    test_kafka_connect_hdfs deb
    test_kafka_connect_jdbc deb
    test_camus deb
    if [ "$PS_ENABLED" = "yes" ]; then
        test_ps deb
    fi
    test_kafka_stop deb
    test_zk_stop deb

    # post-test sanitization
    vagrant ssh deb -- sudo dpkg --purge confluent-camus
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-connect-jdbc
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-connect-hdfs
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-rest
    vagrant ssh deb -- sudo dpkg --purge confluent-schema-registry
    vagrant ssh deb -- sudo dpkg --purge confluent-rest-utils
    vagrant ssh deb -- sudo dpkg --purge confluent-common
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-${SCALA_VERSION}
done
