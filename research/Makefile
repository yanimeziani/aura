# Makefile for Aura Research Papers

.PHONY: all clean aura-manifesto

all: aura-manifesto

aura-manifesto:
	cd aura-manifesto && pdflatex main.tex && pdflatex main.tex

clean:
	rm -f aura-manifesto/*.aux aura-manifesto/*.log aura-manifesto/*.out aura-manifesto/*.pdf aura-manifesto/*.toc
