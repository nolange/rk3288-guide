MARKDOWN := $(wildcard *.md)

all:

html: $(MARKDOWN:.md=.html)

$(MARKDOWN:.md=.html): %.html : %.md
	pandoc -s --toc -o "$@" "$<"

normalize:
	TEMPFILE=$$(mktemp); trap "rm -rf $TEMPFILE" 0; for file in $(MARKDOWN); do \
	  pandoc -t markdown -o $$TEMPFILE $$file && cp $$TEMPFILE $$file; \
	done

.PHONY: normalize all
