Confluent Packaging
-------------------

This repository contains scripts to build all the binary packages for
Confluent's distribution. It:

* Builds in clean VMs to ensure reproducible builds.
* Handles dependencies, i.e. makes sure that kafka-rest's build process has
  access to a compiled version of rest-utils, even if rest-utils isn't available
  publicly (e.g. via Central).
* Ties together all the standalone tgz/zip archives into one large distribution.
* Does a basic installation sanity check on the resulting packages.
