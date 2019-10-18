#
#
#

all:
	@echo no default target
	false

.PHONY: build-depends
build-depends:
	sudo apt-get -y install \
	    libio-html-perl \
	    libhtml-tree-perl \

.PHONY: clean
clean:
	rm tmp/*

.PHONY: get
get:
	mkdir -p tmp
	./cpl_get tmp
