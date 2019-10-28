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
	./msy_get tmp

%_extract: $(wildcard lib/*.pm)
	touch $@

extract-%.csv: %_extract $(wildcard tmp/*.html)
	./$*_extract $@ tmp/$**.html

# FIXME
# - the extract rule should depend on only the matching html files,
#   but the $* variable is not set until after the pre-requisites have been
#   evaluated

.PHONY: extract.diff
extract.diff: extract-cplhdd.csv
	-[ -e $<.old ] && git diff --no-index $<.old $<
	cp -p $< $<.old

.PHONY: extract
extract: extract.csv

extract.csv: extract-cplhdd.csv extract-msyhdd.csv
	cat $^ >$@

.PHONY: test
test: get extract
