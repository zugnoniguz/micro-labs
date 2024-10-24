.PHONY: build

BUILDDIR := out/

build: $(BUILDDIR) $(BUILDDIR)main.hex

$(BUILDDIR):
	mkdir -p $@

upload: build
	avrdude -c xplainedmini -p m328p -U flash:w:$(BUILDDIR)main.hex:i

$(BUILDDIR)main.hex: main.asm
	avra $^
	mv main.hex $(BUILDDIR)
	mv main.eep.hex $(BUILDDIR)
	mv main.obj $(BUILDDIR)

clean:
	rm -rf $(BUILDDIR)
