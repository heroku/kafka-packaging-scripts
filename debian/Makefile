# This makefile assumes you have specified SCALA_VERSION. Since the
# package is for dependencies only and contains no contents, this script can be
# kept pretty simple.

all: install

install:

clean:

distclean: clean
	git reset --hard HEAD
	git status --ignored --porcelain | cut -d ' ' -f 2 | xargs rm -rf

test:

.PHONY: clean install debian-control


# This generates the debian control file. You should only be running this from
# the top-level directory using make -f debian/Makefile, never while in the
# debian/ directory.
debian-control:
	cp debian/control.in debian/control
	for SVERSION in $(SCALA_VERSIONS); do \
		cat debian/control.binary.in | sed s@##SCALAVERSION##@$$SVERSION@g >> debian/control; \
	done
	git add debian/control
	git commit -m "Add control file."
