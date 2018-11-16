
all: $(subst .adoc,.html, $(wildcard *.adoc))

%.html: %.adoc
	asciidoctor $^
