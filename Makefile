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

main.pdf: $(TEX_GEN) $(CPY_TEX_SRC)

# generated tex files
$(O)/%.tex: %.md
	@mkdir -p $O
	pandoc $^ -o $@

# copy tex files
$(O)/%.tex: %.tex
	@mkdir -p $O
	cp $^ $@

main.pdf: $(TEX_GEN) $(CPY_TEX_SRC)
	cd $(O) ; latexmk -xelatex main

clean:
	cd $(O); latexmk -c

cleanall:
	rm -rf $O

