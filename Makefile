all: main.pdf

.PHONY: clean cleanall
# output directory, don't mess with the sources
O = latex

# source markdown files
MD_SRC = $(wildcard *.md)
# generated tex files
TEX_GEN = $(addprefix $(O)/, $(patsubst %.md,%.tex, $(MD_SRC)))
# hand-written tex files
TEX_SRC = $(wildcard *.tex)
# copy to the output directory.
CPY_TEX_SRC = $(addprefix $(O)/, $(TEX_SRC))
# copy bib
CPY_BIB = $(O)/local-os.bib

main.pdf: $(TEX_GEN) $(CPY_TEX_SRC) $(CPY_BIB)

# generated tex files
$(O)/%.tex: %.md
	@mkdir -p $O
	pandoc $^ -o $@

# copy tex files
$(O)/%.tex: %.tex
	@mkdir -p $O
	cp $^ $@

# copy bib
$O/%.bib: %.bib
	@mkdir -p $O
	cp $^ $@

main.pdf: $(TEX_GEN) $(CPY_TEX_SRC)
	cd $(O) ; latexmk -xelatex main
	ln $(O)/main.pdf .
	

clean:
	cd $(O); latexmk -c

cleanall:
	rm -rf $O
	rm -rf main.pdf

