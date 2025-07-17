#
# Copyright (C) 2025 Hamish Coleman
# SPDX-License-Identifier: GPL-2.0-only
#
#

all:
	@echo no default target
	false

.PHONY: build-depends
build-depends:
	sudo apt-get -q -y install \
	    chromium \
	    chromium-driver \
	    flake8 \
	    libhtml-tree-perl \
	    libio-html-perl \
	    libtext-csv-perl \
	    python3-pandas \
	    python3-selenium \
	    shellcheck \
	    xvfb \

.PHONY: clean
clean:
	rm \
	    tmp/* \
	    extract-cplstorage.csv \
	    extract-msyhdd.csv \
	    extract-scoptec.csv \

.PHONY: get
get: get.cpl get.scorptec

.PHONY: get.cpl
get.cpl: chromium_get.py cpl.urls
	mkdir -p tmp
	./chromium_get.py \
		--fix-new-selenium \
		--pause 15 --prefix tmp/cplstorage --urls cpl.urls

.PHONY: get.scorptec
get.scorptec: chromium_get.py scorptec.urls
	mkdir -p tmp
	./chromium_get.py \
		--fix-new-selenium \
		--newsession \
		--pause 15 --prefix tmp/scorptec --urls scorptec.urls

%_extract: $(wildcard lib/*.pm)
	touch $@

extract-%.csv: %_extract %_ignore.txt $(wildcard tmp/*.html)
	./$*_extract $@ tmp/$**.html

# FIXME
# - the extract rule should depend on only the matching html files,
#   but the $* variable is not set until after the pre-requisites have been
#   evaluated

.PHONY: extract.diff
extract.diff: extract.csv
	-[ -e $<.old ] && git diff --no-index $<.old $<
	cp -p $< $<.old

extract.csv: extract-cplstorage.csv extract-scorptec.csv
	cat $^ >$@

merged.csv.old:
	./merged-old_get

merged.csv: merged.csv.old extract-cplstorage.csv extract-scorptec.csv
	./merge $@ $^

.PHONY: check
check: check.shell check.python

.PHONY: check.shell
check.shell:
	shellcheck msy_get merged-old_get

.PHONY: check.python
check.python:
	flake8 chromium_get.py

.PHONY: test
test: check get merged.csv

.PHONY: deploy_branch
deploy_branch:
	mkdir -p deploy
	mv *.csv deploy
	mv tmp deploy
	git checkout gh-pages
	git rm tmp/*
	cp -a deploy/* ./
	git add tmp
	git add extract-cplstorage.csv extract-scorptec.csv merged.csv
	git commit -m "Auto create deployable files"
	git checkout main
	mv deploy/* ./
	rmdir deploy
