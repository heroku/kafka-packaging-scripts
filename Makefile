# This makefile expects that you have the environment variables VERSION,
# SCALA_VERSION, KAFKA_VERSION defined. Since this package doesn't actually
# install anything, this can be kept relatively simple otherwise (no DESTDIR,
# PREFIX, etc.).

export VERSION
export SCALA_VERSION
export KAFKA_VERSION

all: install

apply-patches: $(wildcard patches/*)
	git reset --hard HEAD
	cat patches/series | xargs -IPATCH bash -c 'patch -p1 < patches/PATCH'

install: apply-patches

clean:

distclean: clean
	git reset --hard HEAD
	git status --ignored --porcelain | cut -d ' ' -f 2 | xargs rm -rf

test:

.PHONY: clean install



export RPM_VERSION=$(shell echo $(VERSION) | sed -e 's/-alpha[0-9]*//' -e 's/-beta[0-9]*//' -e 's/-rc[0-9]*//')
export KAFKA_RPM_VERSION=$(shell echo $(KAFKA_VERSION) | sed -e 's/-alpha[0-9]*//' -e 's/-beta[0-9]*//' -e 's/-rc[0-9]*//')
# Get any -alpha, -beta, -rc piece that we need to put into the Release part of
# the version since RPM versions don't support non-numeric
# characters. Ultimately, for something like 0.8.2-beta, we want to end up with
# Version=0.8.2 Release=0.X.beta
# where X is the RPM release # of 0.8.2-beta (the prefix 0. forces this to be
# considered earlier than any 0.8.2 final releases since those will start with
# Version=0.8.2 Release=1)
export RPM_RELEASE_POSTFIX=$(subst -,,$(subst $(RPM_VERSION),,$(VERSION)))
ifneq ($(RPM_RELEASE_POSTFIX),)
	export RPM_RELEASE_POSTFIX_UNDERSCORE=_$(RPM_RELEASE_POSTFIX)
endif

rpm: RPM_BUILDING/SOURCES/confluent-platform-$(SCALA_VERSION)-$(RPM_VERSION).tar.gz
	echo "Building the rpm"
	rpmbuild --define="_topdir `pwd`/RPM_BUILDING" -tb $<
	find RPM_BUILDING/{,S}RPMS/ -type f | xargs -n1 -iXXX mv XXX .
	echo
	echo "================================================="
	echo "The rpms have been created and can be found here:"
	@ls -laF confluent-platform*rpm
	echo "================================================="

RPM_BUILDING/SOURCES/confluent-platform-$(SCALA_VERSION)-$(RPM_VERSION).tar.gz: rpm-build-area install confluent-platform.spec.in RELEASE_$(SCALA_VERSION)_$(RPM_VERSION)$(RPM_RELEASE_POSTFIX_UNDERSCORE)
	rm -rf confluent-platform-$(SCALA_VERSION)-$(RPM_VERSION)
	mkdir confluent-platform-$(SCALA_VERSION)-$(RPM_VERSION)
	./create_spec.sh confluent-platform.spec.in confluent-platform-$(SCALA_VERSION)-$(RPM_VERSION)/confluent-platform.spec
	rm -f $@ && tar -czf $@ confluent-platform-$(SCALA_VERSION)-$(RPM_VERSION)
	rm -rf confluent-platform-$(SCALA_VERSION)-$(RPM_VERSION)

rpm-build-area: RPM_BUILDING/BUILD RPM_BUILDING/RPMS RPM_BUILDING/SOURCES RPM_BUILDING/SPECS RPM_BUILDING/SRPMS

RPM_BUILDING/%:
	mkdir -p $@

RELEASE_%:
	echo 0 > $@
