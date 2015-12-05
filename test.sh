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

# This test assumes that:
# 1. The broker has already started.
# 2. The proactive support package(s) are installed.
test_proactive_support() {
    machine=$1
    SUPPORT_METRICS_BUNDLE_FILE="/tmp/test_support-metrics-bundle.zip"
    rm -f $SUPPORT_METRICS_BUNDLE_FILE
    # Stop the broker because metrics will be collected (at least) at shutdown,
    # and the default report interval is 24 hours (we don't want to wait that long...)
    test_kafka_stop $machine
    # Restart the broker so the `support-metrics-bundle` script can retrieve the
    # collected metrics from the support metrics topic.
    test_kafka_start $machine
    vagrant ssh $machine -- "/usr/bin/support-metrics-bundle --zookeeper localhost:2181 --file $SUPPORT_METRICS_BUNDLE_FILE"
    vagrant ssh $machine -- "test -s $SUPPORT_METRICS_BUNDLE_FILE"
}

test_schema_registry() {
    machine=$1
    vagrant ssh $machine -- "sudo /usr/bin/schema-registry-start /etc/schema-registry/schema-registry.properties &> /tmp/schema-registry.log &"
    sleep 5
    vagrant ssh $machine -- "ps aux | grep 'schemaregistry\.rest\.SchemaRegistryMain' | grep -v grep"
    vagrant ssh $machine -- "sudo /usr/bin/schema-registry-stop"
}

# TODO: Add a more meaningful test.  We currently verify only the existence of key kafka-serde-tools files.
#
# This test requires that schema registry is installed because as of CP 2.0.0
# kafka-serde-tools are bundled with the schema registry package.
test_kafka_serde_tools() {
    machine=$1
    vagrant ssh $machine -- "test -s /usr/share/java/kafka-serde-tools/kafka-avro-serializer-${CONFLUENT_VERSION}.jar"
    vagrant ssh $machine -- "test -s /usr/share/java/kafka-serde-tools/kafka-connect-avro-converter-${CONFLUENT_VERSION}.jar"
    vagrant ssh $machine -- "test -s /usr/share/java/kafka-serde-tools/kafka-json-serializer-${CONFLUENT_VERSION}.jar"
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
    # Start one HDFS connector. There isn't currently a nice sample config that
    # would work for this, so we have to create one ourselves.
    vagrant ssh $machine -- "echo -e 'name=hdfs-sink\nconnector.class=io.confluent.connect.hdfs.HdfsSinkConnector\ntasks.max=1\ntopics=test-topic\nhdfs.url=hdfs://localhost:9000\nhadoop.conf.dir=/mnt\nhadoop.home=/opt/hadoop-cdh\nflush.size=100\nrotate.interval.ms=1000\n' > /tmp/hdfs-sink.properties"
    vagrant ssh $machine -- "connect-standalone /etc/schema-registry/connect-avro-standalone.properties /tmp/hdfs-sink.properties 1>/tmp/connect-hdfs.log 2>&1 &"
    # Check that the REST server in Kafka Connect actually started. If not
    # packaged properly such that the HDFS connector includes Jetty/Jersey, it
    # will conflict with the version in Kafka Connect and cause connect to crash.
    sleep 5
    vagrant ssh $machine -- "grep 'REST server listening' /tmp/connect-hdfs.log"
    # Also check that we saw the connector instantiated. This is
    vagrant ssh $machine -- "grep 'Created connector hdfs-sink' /tmp/connect-hdfs.log"
    # Clean up. The process will be doing nothing, but still running
    vagrant ssh $machine -- "ps ax | grep java | grep -i standalone | grep -v grep | awk '{print \$1}' | xargs kill"
}

test_kafka_connect_jdbc() {
    machine=$1
    # Start a connector that uses simple SQLite settings.
    vagrant ssh $machine -- "connect-standalone /etc/schema-registry/connect-avro-standalone.properties /etc/kafka-connect-jdbc/sqlite-test.properties > /tmp/connect-jdbc.log"
    # In this case, we expect it to start up the connector, manage to make the
    # "connection" to the database (which it would create if it didn't exist),
    # but then fail because there aren't actually any tables in the database.
    sleep 5
    vagrant ssh $machine -- "grep 'Number of groups must be positive.' /tmp/connect-jdbc.log"
    # No cleanup necessary, the process exits due to connection errors. Validate it isn't running anymore.
    ! vagrant ssh $machine -- "ps ax | grep java | grep -i standalone | grep -v grep"
}

test_camus() {
    # There's no good way to test the Camus jar since it doesn't contain unit
    # tests and everything it has requires Hadoop to be running. In this case
    # we're ok with ignoring it -- it's unusual in that the package is just a
    # standalone uberjar anyway so anything that tests the build output
    # (e.g. ducttape) should be sufficient.
    echo "Skipping Camus test since Camus has nothing it can run standalone."
}


# Test librdkafka devel by compiling a tiny program and run it.
test_librdkafka_dev() {
    machine=$1

    # C API
    echo "#include <librdkafka/rdkafka.h>
int main (void) {
   return rd_kafka_version() ? 0 : 1;
}
" | vagrant ssh $machine -- "cat > /tmp/test_compile_librdkafka.c"

    vagrant ssh $machine -- "gcc /tmp/test_compile_librdkafka.c -o /tmp/test_compile_librdkafka -lrdkafka -lrt"

    vagrant ssh $machine -- "/tmp/test_compile_librdkafka  && rm -f /tmp/test_compile_librdkafka"

    # C++ API
    echo "#include <librdkafka/rdkafkacpp.h>
int main (void) {
   return RdKafka::version() ? 0 : 1;
}
" | vagrant ssh $machine -- "cat > /tmp/test_compile_librdkafka.cpp"

    vagrant ssh $machine -- "g++ /tmp/test_compile_librdkafka.cpp -o /tmp/test_compile_librdkafka_cpp -lrdkafka++ -lrdkafka -lrt"

    vagrant ssh $machine -- "/tmp/test_compile_librdkafka_cpp  && rm -f /tmp/test_compile_librdkafka_cpp"
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
    vagrant ssh rpm -- sudo yum -y remove cyrus-sasl || true
    vagrant ssh rpm -- sudo rpm --erase librdkafka-devel || true
    vagrant ssh rpm -- sudo rpm --erase librdkafka1 || true

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
    vagrant ssh rpm -- sudo yum -y install cyrus-sasl
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/librdkafka1-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/librdkafka-devel-*.rpm

    test_zk_start rpm
    test_kafka_start rpm
    test_schema_registry rpm
    test_kafka_serde_tools rpm
    test_rest rpm
    test_kafka_connect_hdfs rpm
    test_kafka_connect_jdbc rpm
    test_librdkafka_dev rpm
    test_camus rpm
    if [ "$PS_ENABLED" = "yes" ]; then
        test_proactive_support rpm
    fi
    test_kafka_stop rpm
    test_zk_stop rpm

    # post-test sanitization
    vagrant ssh rpm -- sudo rpm --erase librdkafka-devel
    vagrant ssh rpm -- sudo rpm --erase librdkafka1
    vagrant ssh rpm -- sudo yum -y remove cyrus-sasl
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
    vagrant ssh deb -- sudo dpkg --purge librdkafka-dev librdkafka-dbg librdkafka1 || true

    for LOCAL_SCALA_VERSION in $SCALA_VERSIONS; do
        #        vagrant ssh deb -- sudo dpkg --remove confluent-kafka-${LOCAL_SCALA_VERSION} || true
        echo hi
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
    # libsasl2-2 is used by a lot of other programs so we will not try to remove it, just install.
    vagrant ssh deb -- sudo apt-get install -y libsasl2-2 || true
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/librdkafka1*.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/librdkafka-dev*.deb

    test_zk_start deb
    test_kafka_start deb
    test_schema_registry deb
    test_kafka_serde_tools deb
    test_rest deb
    test_kafka_connect_hdfs deb
    test_kafka_connect_jdbc deb
    test_librdkafka_dev deb
    test_camus deb
    if [ "$PS_ENABLED" = "yes" ]; then
        test_proactive_support deb
    fi
    test_kafka_stop deb
    test_zk_stop deb

    # post-test sanitization
    vagrant ssh deb -- sudo dpkg --purge librdkafka-dev librdkafka1-dbg librdkafka1
    vagrant ssh deb -- sudo dpkg --purge confluent-camus
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-connect-jdbc
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-connect-hdfs
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-rest
    vagrant ssh deb -- sudo dpkg --purge confluent-schema-registry
    vagrant ssh deb -- sudo dpkg --purge confluent-rest-utils
    vagrant ssh deb -- sudo dpkg --purge confluent-common
    vagrant ssh deb -- sudo dpkg --purge confluent-kafka-${SCALA_VERSION}
done
