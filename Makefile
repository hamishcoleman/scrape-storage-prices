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
	    libtext-csv-perl \
	    shellcheck \

.PHONY: clean
clean:
	rm \
	    tmp/* \
	    extract-cplstorage.csv \
	    extract-msyhdd.csv \

.PHONY: get
get:
	mkdir -p tmp
	./cpl_get tmp

%_extract: $(wildcard lib/*.pm)
	touch $@

extract-%.csv: %_extract $(wildcard tmp/*.html)
	./$*_extract $@ tmp/$**.html

# FIXME
# - the extract rule should depend on only the matching html files,
#   but the $* variable is not set until after the pre-requisites have been
#   evaluated

.PHONY: extract.diff
extract.diff: extract.csv
	-[ -e $<.old ] && git diff --no-index $<.old $<
	cp -p $< $<.old

extract.csv: extract-cplstorage.csv
	cat $^ >$@

merged.csv.old:
	./merged-old_get

merged.csv: merged.csv.old extract-cplstorage.csv
	./merge $@ $^

.PHONY: check
check: check.shell

.PHONY: check.shell
check.shell:
	shellcheck cpl_get msy_get merged-old_get

.PHONY: test
test: check get merged.csv

.PHONY: deploy_branch
deploy_branch:
	mkdir deploy
	mv *.csv deploy
	mv tmp deploy
	git checkout gh-pages
	git rm tmp/*
	mv deploy/* ./
	git add tmp
	git add extract-cplstorage.csv merged.csv
	git commit -m "Auto create deployable files"
	git checkout main
