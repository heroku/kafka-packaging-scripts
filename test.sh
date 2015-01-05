#!/bin/bash

set -e
set -x

. versions.sh

# Note that this should really only be run with *a single version of packages in
# output/*. This is because it's a pain to generate the actual package names
# from the versions because of platform-specific version contortions. Instead,
# we use globs to pick out what *should* be unique files as long as we only have
# one version in output/.
for SCALA_VERSION in $SCALA_VERSIONS; do
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/kafka-${SCALA_VERSION}-*.noarch.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/confluent-common-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/rest-utils-*.rpm
    vagrant ssh rpm -- sudo rpm --install /vagrant/output/kafka-rest-*.rpm

    # FIXME this should check the installed contents in addition to verifying the packages will install

    vagrant ssh rpm -- sudo rpm --erase kafka-rest
    vagrant ssh rpm -- sudo rpm --erase rest-utils
    vagrant ssh rpm -- sudo rpm --erase confluent-common
    vagrant ssh rpm -- sudo rpm --erase kafka-${SCALA_VERSION}


    vagrant ssh deb -- sudo dpkg --install /vagrant/output/kafka-${SCALA_VERSION}*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/confluent-common*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/rest-utils*_all.deb
    vagrant ssh deb -- sudo dpkg --install /vagrant/output/kafka-rest*_all.deb

    # FIXME this should check the installed contents in addition to verifying the packages will install

    vagrant ssh deb -- sudo dpkg --remove kafka-rest
    vagrant ssh deb -- sudo dpkg --remove rest-utils
    vagrant ssh deb -- sudo dpkg --remove confluent-common
    vagrant ssh deb -- sudo dpkg --remove kafka-${SCALA_VERSION}
done
