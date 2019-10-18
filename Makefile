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
	rm \
	    tmp/* \
	    extract-cplhdd.csv

.PHONY: get
get:
	mkdir -p tmp
	./cpl_get tmp

extract-cplhdd.csv: cplhdd_extract $(wildcard tmp/cplhdd*.html)
	./cplhdd_extract $@ tmp/cplhdd*.html

.PHONY: extract.diff
extract.diff: extract-cplhdd.csv
	-[ -e $<.old ] && git diff --no-index $<.old $<
	cp -p $< $<.old

.PHONY: extract
extract: extract-cplhdd.csv

.PHONY: test
test: get extract
